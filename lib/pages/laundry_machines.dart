import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/machine_card.dart';
import 'payment_page.dart';
import 'report_machine_page.dart';
import 'point_service.dart';
import '../widgets/premium_dialog.dart';

class LaundryMachinesPage extends StatefulWidget {
  final String laundryId;
  final String laundryName;

  const LaundryMachinesPage({
    super.key,
    required this.laundryId,
    required this.laundryName,
  });

  @override
  State<LaundryMachinesPage> createState() => _LaundryMachinesPageState();
}

class _LaundryMachinesPageState extends State<LaundryMachinesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Safe method to get field value
  T? _getField<T>(DocumentSnapshot doc, String fieldName) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey(fieldName)) {
        return data[fieldName] as T?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get remaining time string
  String _getRemainingTime(Timestamp? countdownEndTime) {
    if (countdownEndTime == null) return '';
    
    final DateTime endTime = countdownEndTime.toDate();
    final Duration remaining = endTime.difference(DateTime.now());
    
    if (remaining.isNegative) return '00:00';
    
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Show Time Picker
  Future<TimeOfDay?> _showTimePicker(BuildContext context, String machineName) async {
    final now = DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)));
    
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'Select reservation time for $machineName',
      cancelText: 'Cancel',
      confirmText: 'Next',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
             dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
  }

  // Reserve Machine Flow
  Future<void> _reserveMachine(
    BuildContext context, 
    String machineId, 
    String collection, 
    String machineName
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    // Check Premium Status
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final isPremium = userDoc.data()?['isPremium'] ?? false;

    if (!isPremium) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => PremiumDialog(featureName: 'Reserve Machines'),
      );
      return; 
    }

    final selectedTime = await _showTimePicker(context, machineName);
    if (selectedTime == null) return;

  final now = DateTime.now();
  DateTime reservationTime = DateTime(
    now.year,
    now.month,
    now.day,
    selectedTime.hour,
    selectedTime.minute,
  );

  if (reservationTime.isBefore(now)) {
    reservationTime = reservationTime.add(const Duration(days: 1));
  }

  // Voucher Logic
  QuerySnapshot? voucherSnapshot;
  try {
    print("Fetching vouchers for user: ${user.uid}");
    voucherSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vouchers')
        .get();
    print("Found ${voucherSnapshot.docs.length} vouchers");
  } catch (e) {
    print("Error fetching vouchers: $e");
  }

  DocumentSnapshot? selectedVoucher;
  double discountAmount = 0.0;
  List<String> expiredVoucherIds = [];

  if (voucherSnapshot != null) {
    for (var doc in voucherSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime? expireAt;
      
      // Robust Timestamp parsing
      try {
        if (data['expireAt'] is Timestamp) {
          expireAt = (data['expireAt'] as Timestamp).toDate();
        } else if (data['expireAt'] is String) {
          expireAt = DateTime.tryParse(data['expireAt']);
        }
      } catch (e) {
        print("Error parsing date for ${doc.id}: $e");
      }

      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      
      print("Voucher ${doc.id}: Amount=$amount, ExpireAt=$expireAt");

      // Treat null expiration as expired/invalid
      if (expireAt == null || expireAt.isBefore(now)) {
        print("Voucher ${doc.id} is considered expired/invalid.");
        expiredVoucherIds.add(doc.id);
      } else {
        // Simple logic: pick the first valid voucher or the best one
        // Here we pick the one with highest amount
        if (amount > discountAmount) {
          discountAmount = amount;
          selectedVoucher = doc;
          print("Selected new best voucher: ${doc.id} with amount $amount");
        }
      }
    }
  }

  // Cleanup expired vouchers
  for (var id in expiredVoucherIds) {
    print("Deleting expired/invalid voucher: $id");
    _firestore.collection('users').doc(user.uid).collection('vouchers').doc(id).delete();
  }

  print("Final Discount: $discountAmount");


  // Calculate Final Price
  double basePrice = 6.00;
  double finalPrice = basePrice - discountAmount;
  if (finalPrice < 0) finalPrice = 0;

  if (!mounted) return;

  // Show Voucher Info if applied
  if (discountAmount > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voucher Applied: -RM${discountAmount.toStringAsFixed(2)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  final paymentSuccess = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentPage(
        machineName: machineName,
        laundryName: widget.laundryName,
        reservationTime: reservationTime,
        amount: finalPrice,
      ),
    ),
  );

  if (paymentSuccess == true) {
    // Fetch ownerUid from laundry
    String ownerUid = '';
    try {
      final laundryDoc = await _firestore.collection('laundries').doc(widget.laundryId).get();
      final fetchedOwnerId = laundryDoc.data()?['ownerId'];
      
      // Fallback: If fetchedOwnerId is null OR empty string, use widget.laundryId
      if (fetchedOwnerId != null && fetchedOwnerId.toString().trim().isNotEmpty) {
          ownerUid = fetchedOwnerId.toString().trim();
      } else {
          ownerUid = widget.laundryId;
      }
      
      print('DEBUG: Fetched ownerUid: $ownerUid for LaundryID: ${widget.laundryId}');
    } catch (e) {
      print("Error fetching ownerUid: $e");
      ownerUid = widget.laundryId;
      print('DEBUG: Fallback to ownerUid: $ownerUid');
    }

    await _createReservation(
      user.uid,
      machineId,
      collection,
      machineName,
      reservationTime,
      ownerUid,
    );
    
    // Delete used voucher
    if (selectedVoucher != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('vouchers')
          .doc(selectedVoucher.id)
          .delete();
    }

    // Add points for reservation
    try {
      final pointService = PointService();
      await pointService.addPointsForReservation(
        DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID
        machineName,
      );
      print("Points added successfully");
    } catch (e) {
      print("Error adding points: $e");
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reservation confirmed for $machineName at ${selectedTime.format(context)} (+10 Points)'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  // Create Reservation Record
  Future<void> _createReservation(
    String userId,
    String machineId,
    String collection,
    String machineName,
    DateTime reservationTime,
    String ownerUid,
  ) async {
    try {
      final statusChangeTime = reservationTime.subtract(const Duration(minutes: 40));

      await _firestore.collection('reserved_machines').add({
        'userId': userId,
        'machineId': machineId,
        'collection': collection,
        'machineName': machineName,
        'laundryId': widget.laundryId,
        'laundryName': widget.laundryName,
        'ownerUid': ownerUid, // Saved for Owner Dashboard
        'reservationTime': Timestamp.fromDate(reservationTime),
        'statusChangeTime': Timestamp.fromDate(statusChangeTime),
        'createdAt': FieldValue.serverTimestamp(),
        'paymentStatus': 'paid',
        'paymentAmount': 5.00,
        'paymentMethod': 'TnG/DuitNow',
        'status': 'pending',
        'endTime': Timestamp.fromDate(reservationTime.add(Duration(minutes: 45))), // Default 45 mins
      });

      _setupStatusChangeTimer(machineId, collection, statusChangeTime, reservationTime);

    } catch (e) {
      print('Error creating reservation: $e');
      rethrow;
    }
  }

  // Setup Timer
  void _setupStatusChangeTimer(
    String machineId, 
    String collection, 
    DateTime statusChangeTime,
    DateTime reservationTime,
  ) {
    final now = DateTime.now();
    final durationUntilStatusChange = statusChangeTime.difference(now);
    
    // Calculate End Time (Start + 45 mins)
    final endTime = reservationTime.add(const Duration(minutes: 45));

    if (durationUntilStatusChange > Duration.zero) {
      Timer(durationUntilStatusChange, () async {
        await _updateMachineStatus(machineId, collection, 'reserved', endTime: endTime);
        
        final durationUntilReservationEnd = reservationTime.difference(DateTime.now());
        if (durationUntilReservationEnd > Duration.zero) {
          Timer(durationUntilReservationEnd, () async {
            await _updateMachineStatus(machineId, collection, 'available');
            await _markReservationAsCompleted(machineId, collection);
          });
        }
      });
    } else {
      _updateMachineStatus(machineId, collection, 'reserved', endTime: endTime);
    }
  }

  // Update Status
  Future<void> _updateMachineStatus(String machineId, String collection, String status, {DateTime? endTime}) async {
    try {
      final Map<String, dynamic> data = {
        'status': status,
        'lastUpdateTime': FieldValue.serverTimestamp(),
      };
      
      if (endTime != null) {
        data['endTime'] = Timestamp.fromDate(endTime);
      } else if (status == 'available') {
        data['endTime'] = null; // Clear endTime if available
      }

      await _firestore.collection(collection).doc(machineId).update(data);
    } catch (e) {
      print('Error updating machine status: $e');
    }
  }

  // Mark Completed
  Future<void> _markReservationAsCompleted(String machineId, String collection) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('reserved_machines')
          .where('userId', isEqualTo: user.uid)
          .where('machineId', isEqualTo: machineId)
          .where('collection', isEqualTo: collection)
          .where('status', whereIn: ['pending', 'active'])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error marking reservation as completed: $e');
    }
  }

  // Add to Favorites
  Future<void> _addToFavouriteMachine(String machineId, String collection, String machineName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check for duplicate
      final existing = await _firestore.collection('favourite_machines')
        .where('userId', isEqualTo: user.uid)
        .where('machineId', isEqualTo: machineId)
        .limit(1)
        .get();

      if(existing.docs.isNotEmpty) {
         if(!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in favorites'), backgroundColor: Colors.orange),
        );
        return;
      }

      await _firestore.collection('favourite_machines').add({
        'userId': user.uid,
        'machineId': machineId,
        'collection': collection,
        'machineName': machineName,
        'laundryId': widget.laundryId,
        'laundryName': widget.laundryName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favorites'), backgroundColor: AppTheme.primaryColor),
      );
    } catch (e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Add Laundry to Favorites
  Future<void> _addToFavouriteLaundry() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
       // Check duplicate
       final existing = await _firestore.collection('favourite_laundries')
        .where('userId', isEqualTo: user.uid)
        .where('laundryId', isEqualTo: widget.laundryId)
        .limit(1)
        .get();
        
       if (existing.docs.isNotEmpty) return; // Already liked

      await _firestore.collection('favourite_laundries').add({
        'userId': user.uid,
        'laundryId': widget.laundryId,
        'laundryName': widget.laundryName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${widget.laundryName} to favorites'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
       if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Check if Laundry is Favourited
  Future<bool> _isLaundryFavourited() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _firestore
          .collection('favourite_laundries')
          .where('userId', isEqualTo: user.uid)
          .where('laundryId', isEqualTo: widget.laundryId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Build Machine List
  Widget _buildMachineList(String collection, bool isDryer) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collection)
          .where("laundryId", isEqualTo: widget.laundryId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDryer ? Icons.local_fire_department_outlined : Icons.local_laundry_service_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "No ${isDryer ? 'Dryers' : 'Washers'} Available",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        
        // Sort: Available first, then by Name
        docs.sort((a, b) {
           final statusA = _getField<String>(a, 'status') ?? 'available';
           final statusB = _getField<String>(b, 'status') ?? 'available';
           
           if (statusA == 'available' && statusB != 'available') return -1;
           if (statusA != 'available' && statusB == 'available') return 1;
           
           final nameA = _getField<String>(a, 'name') ?? '';
           final nameB = _getField<String>(b, 'name') ?? '';
           return nameA.compareTo(nameB);
        });

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final m = docs[index];
            final machineId = m.id;
            final status = _getField<String>(m, 'status') ?? 'available';
            final bool countdownActive = _getField<bool>(m, 'countdownActive') ?? false;
            final Timestamp? countdownEndTime = _getField<Timestamp>(m, 'countdownEndTime');
            final machineName = _getField<String>(m, 'name') ?? 'Unknown Machine';
            
            return StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => DateTime.now()),
              builder: (context, timerSnap) {
                return MachineCard(
                  machineName: machineName,
                  status: status,
                  isDryer: isDryer,
                  remainingTime: countdownActive ? _getRemainingTime(countdownEndTime) : null,
                  onBook: () => _reserveMachine(context, machineId, collection, machineName),
                  onReport: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportMachinePage(
                          machineId: machineId,
                          machineName: machineName,
                          collection: collection,
                          laundryId: widget.laundryId,
                          laundryName: widget.laundryName,
                        ),
                      ),
                    );
                  },
                  onFavorite: () => _addToFavouriteMachine(machineId, collection, machineName),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.laundryName),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: "Washers", icon: Icon(Icons.local_laundry_service)),
              Tab(text: "Dryers", icon: Icon(Icons.local_fire_department)),
            ],
          ),
          actions: [
            FutureBuilder<bool>(
              future: _isLaundryFavourited(),
              builder: (context, snapshot) {
                final isFavourited = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    isFavourited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavourited ? Colors.pinkAccent : Colors.white,
                  ),
                  onPressed: isFavourited ? null : _addToFavouriteLaundry,
                );
              },
            ),
          ],
        ),
        body: Container(
          color: AppTheme.backgroundColor,
          child: TabBarView(
            children: [
              _buildMachineList("washingMachines", false),
              _buildMachineList("dryerMachines", true),
            ],
          ),
        ),
      ),
    );
  }
}