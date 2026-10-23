// file name: point_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPoint {
  final String id;
  final String userId;
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final DateTime updatedAt;

  UserPoint({
    required this.id,
    required this.userId,
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    required this.updatedAt,
  });

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'totalEarned': totalEarned,
      'totalSpent': totalSpent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // 从Firestore创建
  factory UserPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPoint(
      id: doc.id,
      userId: data['userId'] ?? '',
      balance: data['balance'] ?? 0,
      totalEarned: data['totalEarned'] ?? 0,
      totalSpent: data['totalSpent'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

class PointTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type; // 'earn' or 'spend'
  final String description;
  final String? referenceId; // 关联的预约ID或兑换ID
  final DateTime createdAt;

  PointTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    this.referenceId,
    required this.createdAt,
  });

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type,
      'description': description,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 从Firestore创建
  factory PointTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PointTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: data['amount'] ?? 0,
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      referenceId: data['referenceId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}