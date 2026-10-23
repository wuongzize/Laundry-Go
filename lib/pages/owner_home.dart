import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../theme/app_theme.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/owner_machine_card.dart';
import 'premium_owner.dart';
import 'promotion.dart';
import 'analysis_dashboard.dart';
import 'owner_reports_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, Timer> _activeTimers = {};
  int _vibrationDetectionCount = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVibrationListeners();
    _checkExistingCountdowns();
    _loadVibrationDetectionCount();
  }

  @override
  void dispose() {
    _activeTimers.forEach((key, timer) => timer.cancel());
    _activeTimers.clear();
    super.dispose();
  }

  // Helper: Get today's start
  DateTime getTodayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 0, 0, 0);
  }

  // Logic: Load Vibration Count
  void _loadVibrationDetectionCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final todayStart = getTodayStart();
      final snapshot = await _firestore
          .collection('vibration_detections')
          .where('ownerUid', isEqualTo: user.uid)
          // .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
          // .where('test', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _vibrationDetectionCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('Failed to load vibration detection count: $e');
    }
  }

  // Logic: Initialize Vibration Listeners
  void _initializeVibrationListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _firestore
          .collection('vibration_detections')
          .where('ownerUid', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _handleVibrationDetection(change.doc);
          }
        }
      });
    } catch (e) {
      print('Failed to initialize listener: $e');
    }
  }

  // Logic: Handle Vibration Detection
  void _handleVibrationDetection(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final String machineId = data['machineId'] ?? '';
      final String collection = data['collection'] ?? 'washingMachines';
      final bool isTest = data['test'] ?? false;

      if (machineId.isEmpty) return;

      final machineExists = await _checkMachineExists(machineId, collection);
      if (!machineExists) return;

      _loadVibrationDetectionCount();
      
      if (!isTest) {
        final machineDoc = await _firestore.collection(collection).doc(machineId).get();
        final machineName = machineDoc['name'] ?? 'Unknown Machine';
        final bool isAlreadyInCountdown = machineDoc['countdownActive'] ?? false;
        
        if (!isAlreadyInCountdown) {
          await _recordMachineUsage(machineId, collection, machineName);
        }
        
        _startCountdownTimer(machineId, collection);
      }
    } catch (e) {
      print('Error processing vibration detection: $e');
    }
  }

  // Logic: Check Machine Exists
  Future<bool> _checkMachineExists(String machineId, String collection) async {
    try {
      final doc = await _firestore.collection(collection).doc(machineId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Logic: Record Usage
  Future<void> _recordMachineUsage(String machineId, String collection, String machineName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('machine_usage').add({
        'machineId': machineId,
        'collection': collection,
        'machineName': machineName,
        'ownerUid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toString().substring(0, 10),
        'type': 'vibration_detection',
      });
    } catch (e) {
      print('Failed to record machine usage: $e');
    }
  }

  // Logic: Check Existing Countdowns
  void _checkExistingCountdowns() {
    if (_isInitialized) return;
    
    _checkCollectionCountdowns('washingMachines');
    _checkCollectionCountdowns('dryerMachines');
    _isInitialized = true;
  }

  void _checkCollectionCountdowns(String collection) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _firestore
        .collection(collection)
        .where('ownerUid', isEqualTo: user.uid)
        .where('countdownActive', isEqualTo: true)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String machineId = doc.id;
        final Timestamp? countdownEndTime = data['countdownEndTime'];

        if (countdownEndTime != null) {
          final DateTime endTime = countdownEndTime.toDate();
          final Duration remaining = endTime.difference(DateTime.now());
          
          if (remaining > Duration.zero) {
            _setupCountdownChecker(machineId, collection, endTime);
          } else {
            _completeCountdown(machineId, collection);
          }
        }
      }
    });
  }

  // Logic: Start/Stop Countdown
  void _startCountdownTimer(String machineId, String collection) async {
    const Duration countdownDuration = Duration(minutes: 30);
    final DateTime endTime = DateTime.now().add(countdownDuration);

    try {
      final docSnapshot = await _firestore.collection(collection).doc(machineId).get();
      if (!docSnapshot.exists) return;

      final bool isAlreadyInCountdown = docSnapshot['countdownActive'] ?? false;
      if (isAlreadyInCountdown) return;

      await _firestore.collection(collection).doc(machineId).update({
        'status': 'busy',
        'countdownEndTime': Timestamp.fromDate(endTime),
        'countdownActive': true,
        'lastUpdateTime': FieldValue.serverTimestamp(),
      });

      _setupCountdownChecker(machineId, collection, endTime);
    } catch (error) {
      print('Failed to update Firebase state: $error');
    }
  }

  void _setupCountdownChecker(String machineId, String collection, DateTime endTime) {
    final Duration remaining = endTime.difference(DateTime.now());
    
    _cancelCountdownTimer(machineId);
    
    if (remaining > Duration.zero) {
      final timer = Timer(remaining, () {
        _checkAndCompleteCountdown(machineId, collection);
      });
      _activeTimers[machineId] = timer;
    } else {
      _completeCountdown(machineId, collection);
    }
  }

  void _checkAndCompleteCountdown(String machineId, String collection) async {
    try {
      final doc = await _firestore.collection(collection).doc(machineId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool countdownActive = data['countdownActive'] ?? false;
        final Timestamp? countdownEndTime = data['countdownEndTime'];
        
        if (countdownActive && countdownEndTime != null) {
          final DateTime endTime = countdownEndTime.toDate();
          if (DateTime.now().isAfter(endTime)) {
            _completeCountdown(machineId, collection);
          }
        }
      }
    } catch (e) {
      print('Failed to check countdown status: $e');
    }
  }

  void _completeCountdown(String machineId, String collection) {
    _firestore.collection(collection).doc(machineId).update({
      'status': 'available',
      'countdownActive': false,
      'countdownEndTime': FieldValue.delete(),
    });
    _cancelCountdownTimer(machineId);
  }

  void _cancelCountdownTimer(String machineId) {
    if (_activeTimers.containsKey(machineId)) {
      _activeTimers[machineId]!.cancel();
      _activeTimers.remove(machineId);
    }
  }

  // Logic: Manual Control
  void _manualStartCountdown(String machineId, String collection, String machineName) {
    _firestore.collection(collection).doc(machineId).get().then((doc) {
      final bool isAlreadyInCountdown = doc['countdownActive'] ?? false;
      if (!isAlreadyInCountdown) {
        _recordMachineUsage(machineId, collection, machineName);
      }
    });
    
    _startCountdownTimer(machineId, collection);
  }

  void _manualStopCountdown(String machineId, String collection, String machineName) {
    _firestore.collection(collection).doc(machineId).update({
      'status': 'available',
      'countdownActive': false,
      'countdownEndTime': FieldValue.delete(),
    });
    _cancelCountdownTimer(machineId);
  }

  // Logic: Add Machine
  Future<void> _addMachineDialog(BuildContext context, String type) async {
    final nameController = TextEditingController();
    String status = 'available';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Machine Name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                DropdownMenuItem(value: 'available', child: Text('Available')),
                DropdownMenuItem(value: 'busy', child: Text('Busy')),
                DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                DropdownMenuItem(value: 'offline', child: Text('Offline')),
              ],
              onChanged: (v) => status = v!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              String collection = type == "Washing Machine" ? 'washingMachines' : 'dryerMachines';

              await _firestore.collection(collection).add({
                'name': name,
                'status': status,
                'ownerUid': user.uid,
                'laundryId': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
                'countdownActive': false,
              });

              if(mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Logic: Get Stream
  Stream<Map<String, int>> getTodayUsageCount(String ownerUid) {
    DateTime todayStart = getTodayStart();
    return _firestore
        .collection("machine_usage")
        .where("ownerUid", isEqualTo: ownerUid)
        // .where("timestamp", isGreaterThan: Timestamp.fromDate(todayStart)) // Commented out to avoid Index requirement
        .snapshots()
        .map((snapshot) {
          Map<String, int> usageCount = {};
          for (var doc in snapshot.docs) {
            final Timestamp? timestamp = doc['timestamp'];
            if (timestamp != null && timestamp.toDate().isAfter(todayStart)) {
              String machineId = doc["machineId"];
              usageCount[machineId] = (usageCount[machineId] ?? 0) + 1;
            }
          }
          return usageCount;
        });
  }

  String _getRemainingTime(Timestamp? countdownEndTime) {
    if (countdownEndTime == null) return '';
    final DateTime endTime = countdownEndTime.toDate();
    final Duration remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return '00:00';
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Build: Status Card
  Widget _buildStatusHeader(String ownerUid) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("reserved_machines")
            .where("ownerUid", isEqualTo: ownerUid)
            .snapshots(),
        builder: (context, snapshot) {
          int todayReservationCount = 0;
          
          print('DEBUG: checking reservations for dashboard OwnerUID: $ownerUid');
          if (snapshot.hasData) {
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = todayStart.add(const Duration(days: 1));
            
            final docs = snapshot.data!.docs;
            print('DEBUG: Found ${docs.length} reservations for this owner.');

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['createdAt'] is Timestamp) {
                final createdAt = (data['createdAt'] as Timestamp).toDate();
                print('DEBUG: Doc ${doc.id} CreatedAt: $createdAt');
                if (createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) {
                  todayReservationCount++;
                  print('DEBUG: -> COUNTED');
                } else {
                  print('DEBUG: -> SKIPPED (Not today)');
                }
              } else {
                  print('DEBUG: -> SKIPPED (No createdAt timestamp)');
              }
            }
          } else {
             print('DEBUG: No data in snapshot');
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DashboardCard(
                    title: 'Today Reservation',
                    icon: Icons.calendar_today,
                    color: Colors.blue,
                    onTap: () {},
                    child: Text(
                      '$todayReservationCount',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DashboardCard(
                    title: 'Active Machines',
                    icon: Icons.local_laundry_service,
                    color: Colors.green,
                    onTap: () {},
                    child: Text(
                      '${_activeTimers.length}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // Build: Machine List
  Widget _buildMachineList(String ownerUid, String collection, Map<String, int> usageCount, bool isDryer) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(collection).where('ownerUid', isEqualTo: ownerUid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.red)));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No ${isDryer ? 'dryers' : 'washers'} added yet.",
              style: TextStyle(color: Colors.grey[400]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final machineId = doc.id;
            final todayUsed = usageCount[machineId] ?? 0;
            String status = data['status'] ?? 'available';
            final bool countdownActive = data['countdownActive'] ?? false;
            final Timestamp? countdownEndTime = data['countdownEndTime'];

            return StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => DateTime.now()),
              builder: (context, timerSnap) {
                return OwnerMachineCard(
                  machineName: data['name'], 
                  status: status, 
                  todayUsed: todayUsed,
                  isDryer: isDryer,
                  remainingTime: countdownActive ? _getRemainingTime(countdownEndTime) : null,
                  onStatusChanged: (newStatus) {
                    _firestore.collection(collection).doc(machineId).update({'status': newStatus});
                  },
                  onManualStart: () => _manualStartCountdown(machineId, collection, data['name']),
                  onManualStop: () => _manualStopCountdown(machineId, collection, data['name']),
                  onDelete: () {
                     showDialog(
                      context: context, 
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Machine"),
                        content: const Text("Are you sure? This cannot be undone."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                          TextButton(
                            onPressed: () {
                              _firestore.collection(collection).doc(machineId).delete();
                              Navigator.pop(ctx);
                            }, 
                            child: const Text("Delete", style: TextStyle(color: Colors.red))
                          ),
                        ],
                      )
                    );
                  },
                );
              }
            );
          },
        );
      },
    );
  }

  // Build: Side Menu
  Drawer _buildSideMenu(BuildContext context, String ownerUid) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                    SizedBox(width: 12),
                    Text("Owner\nPanel", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
             _menuItem(Icons.dashboard_rounded, "Dashboard", () => Navigator.pop(context), isActive: true),
             _menuItem(Icons.analytics_rounded, "Analysis Dashboard", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisDashboardPage()));
             }),

            _menuItem(Icons.report_problem_rounded, "Machine Reports", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerReportsPage()));
            }),
             _menuItem(Icons.campaign_rounded, "Promote", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PromotePage(ownerUid: ownerUid)));
             }),
            const Spacer(),
            const Divider(),
            _menuItem(Icons.logout_rounded, "Logout", () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            }, color: Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  ListTile _menuItem(IconData icon, String text, Function() onTap, {bool isActive = false, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? (isActive ? AppTheme.primaryColor : Colors.grey[700])),
      title: Text(
        text, 
        style: TextStyle(
          color: color ?? (isActive ? AppTheme.primaryColor : Colors.grey[900]),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        )
      ),
      selected: isActive,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("User not logged in")));
    final uid = user.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text("Owner Dashboard"),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('machine_reports')
                  .where('ownerUid', isEqualTo: uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  unreadCount = snapshot.data!.docs.length;
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        // Navigate to OwnerReportsPage
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerReportsPage()));
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState!.openDrawer(),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: "Washers", icon: Icon(Icons.local_laundry_service)),
              Tab(text: "Dryers", icon: Icon(Icons.local_fire_department)),
            ],
          ),
        ),
        drawer: _buildSideMenu(context, uid),
        body: StreamBuilder<Map<String, int>>(
          stream: getTodayUsageCount(uid),
          builder: (context, usageSnapshot) {
            if (usageSnapshot.hasError) return Center(child: Text("Error: ${usageSnapshot.error}", style: const TextStyle(color: Colors.red)));
            final usageCount = usageSnapshot.data ?? {};
            return Column(
              children: [
                _buildStatusHeader(uid),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMachineList(uid, 'washingMachines', usageCount, false),
                      _buildMachineList(uid, 'dryerMachines', usageCount, true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryColor,
          icon: const Icon(Icons.add),
          label: const Text("Add Machine"),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Select Machine Type", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.local_laundry_service, color: Colors.blue, size: 32),
                      title: const Text("Washing Machine"),
                      onTap: () {
                        Navigator.pop(context);
                        _addMachineDialog(context, "Washing Machine");
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                      title: const Text("Dryer Machine"),
                      onTap: () {
                        Navigator.pop(context);
                         _addMachineDialog(context, "Dryer Machine");
                      },
                    ),
                  ],
                ),
              )
            );
          },
        ),
      ),
    );
  }
}