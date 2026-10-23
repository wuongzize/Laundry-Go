import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class FavouriteMachinesPage extends StatelessWidget {
  const FavouriteMachinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourite Machines'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favourite_machines')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final favourites = snapshot.data!.docs;

          if (favourites.isEmpty) {
            return const Center(child: Text('No favourite machines yet'));
          }

          return ListView.builder(
            itemCount: favourites.length,
            itemBuilder: (context, index) {
              final fav = favourites[index];
              final machineName = fav['machineName'];
              final laundryName = fav['laundryName'];
              final collection = fav['collection'];

                  final machineId = fav['machineId'];
              
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection(collection).doc(machineId).snapshots(),
                builder: (context, machineSnap) {
                  String status = 'Unknown';
                  DateTime? endTime;
                  
                  if (machineSnap.hasData && machineSnap.data!.exists) {
                    final machineData = machineSnap.data!.data() as Map<String, dynamic>;
                    status = machineData['status'] ?? 'Available';
                    if (machineData['endTime'] != null) {
                      endTime = (machineData['endTime'] as Timestamp).toDate();
                    }
                  } else if (machineSnap.data == null || !machineSnap.data!.exists) {
                     status = 'Removed';
                  }

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'available':
                      statusColor = Colors.green;
                      break;
                    case 'reserved':
                      statusColor = Colors.orange;
                      break;
                    case 'in usage':
                    case 'in_use':
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Icon(
                        collection == 'washingMachines' 
                          ? Icons.local_laundry_service 
                          : Icons.local_fire_department,
                        size: 40,
                        color: Colors.amber,
                      ),
                      title: Text(machineName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Laundry: $laundryName'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (endTime != null && (status.toLowerCase() == 'reserved' || status.toLowerCase() == 'in_use' || status.toLowerCase() == 'in usage')) ...[
                                const SizedBox(width: 8),
                                _CountdownTimer(endTime: endTime),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.star, color: Colors.amber),
                        onPressed: () {
                          fav.reference.delete();
                        },
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}



class _CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  const _CountdownTimer({required this.endTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateTimeLeft();
      }
    });
    _calculateTimeLeft();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final difference = widget.endTime.difference(now);

    if (difference.isNegative) {
      setState(() {
        _timeLeft = '00:00';
      });
      _timer?.cancel();
    } else {
      final minutes = difference.inMinutes;
      final seconds = difference.inSeconds % 60;
      setState(() {
        _timeLeft = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
       decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            _timeLeft,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}