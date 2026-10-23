import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check valid reservations and generate alerts
  Future<void> checkReservations(String userId) async {
    print('DEBUG: checkReservations called for $userId');
    try {
      final now = DateTime.now();
      
      // Get active or pending reservations
      final snapshot = await _firestore
          .collection('reserved_machines')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'active']) 
          .get();

      print('DEBUG: Found ${snapshot.docs.length} active/pending reservations.');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final reservationId = doc.id;
        final machineName = data['machineName'] ?? 'Machine';
        final reservationTime = (data['reservationTime'] as Timestamp?)?.toDate();
        final endTime = (data['endTime'] as Timestamp?)?.toDate();
        final status = data['status'];

        print('DEBUG: Checking ResID: $reservationId, Status: $status, ResTime: $reservationTime, EndTime: $endTime, Now: $now');

        if (reservationTime != null) {
          // Check Start Notification
          bool shouldNotifyStart = now.isAfter(reservationTime) || now.isAtSameMomentAs(reservationTime);
          print('DEBUG: Should notify start? $shouldNotifyStart (Diff: ${now.difference(reservationTime).inSeconds}s)');
          
          if (shouldNotifyStart) {
             await _createNotificationIfNotExists(
               userId: userId,
               reservationId: reservationId,
               type: 'start_alert',
               title: 'Time to Wash!',
               body: 'Your reservation for $machineName has started. Please proceed to the machine via QR Scanner.',
             );
          }
        }

        if (endTime != null) {
           // Check End Notification
           bool shouldNotifyEnd = now.isAfter(endTime) || now.isAtSameMomentAs(endTime);
           print('DEBUG: Should notify end? $shouldNotifyEnd (Diff: ${now.difference(endTime).inSeconds}s)');

           if (shouldNotifyEnd) {
             await _createNotificationIfNotExists(
               userId: userId,
               reservationId: reservationId,
               type: 'end_alert',
               title: 'Laundry Complete!',
               body: 'Your laundry at $machineName is done. Please collect your clothes.',
             );
           }
        }
      }
    } catch (e) {
      print('Error checking reservations: $e');
    }
  }

  Future<void> _createNotificationIfNotExists({
    required String userId,
    required String reservationId,
    required String type,
    required String title,
    required String body,
  }) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('reservationId', isEqualTo: reservationId)
        .where('type', isEqualTo: type)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'reservationId': reservationId,
        'type': type,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Notification Created: $title');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}
