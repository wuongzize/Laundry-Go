// file name: reward_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Reward {
  final String id;
  final String name;
  final String description;
  final int pointCost;
  final String type; // 'cash' or 'free_use'
  final double? cashValue; // 如果是现金券，现金价值
  final String? machineType; // 如果是免费使用券，机器类型：'washing'或'dryer'
  final bool isActive;
  final int stock; // 库存数量
  final DateTime createdAt;

  Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointCost,
    required this.type,
    this.cashValue,
    this.machineType,
    required this.isActive,
    required this.stock,
    required this.createdAt,
  });

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'pointCost': pointCost,
      'type': type,
      'cashValue': cashValue,
      'machineType': machineType,
      'isActive': isActive,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 从Firestore创建
  factory Reward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reward(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      pointCost: data['pointCost'] ?? 0,
      type: data['type'] ?? 'cash',
      cashValue: data['cashValue']?.toDouble(),
      machineType: data['machineType'],
      isActive: data['isActive'] ?? true,
      stock: data['stock'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // 获取显示文本
  String get displayValue {
    if (type == 'cash') {
      return 'RM${cashValue?.toStringAsFixed(2)} OFF';
    } else if (type == 'free_use') {
      return 'Free ${machineType == 'washing' ? 'Washing' : 'Drying'}';
    }
    return name;
  }

  // 获取图标
  String get icon {
    if (type == 'cash') {
      return '💰';
    } else if (type == 'free_use') {
      return machineType == 'washing' ? '🧺' : '🔥';
    }
    return '🎁';
  }
}

class UserReward {
  final String id;
  final String userId;
  final String rewardId;
  final String rewardName;
  final int pointCost;
  final String rewardType;
  final double? cashValue;
  final String? machineType;
  final String status; // 'active', 'used', 'expired'
  final String? voucherCode;
  final DateTime createdAt;
  final DateTime? usedAt;
  final DateTime? expiresAt;

  UserReward({
    required this.id,
    required this.userId,
    required this.rewardId,
    required this.rewardName,
    required this.pointCost,
    required this.rewardType,
    this.cashValue,
    this.machineType,
    required this.status,
    this.voucherCode,
    required this.createdAt,
    this.usedAt,
    this.expiresAt,
  });

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'rewardId': rewardId,
      'rewardName': rewardName,
      'pointCost': pointCost,
      'rewardType': rewardType,
      'cashValue': cashValue,
      'machineType': machineType,
      'status': status,
      'voucherCode': voucherCode,
      'createdAt': FieldValue.serverTimestamp(),
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  // 从Firestore创建
  factory UserReward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserReward(
      id: doc.id,
      userId: data['userId'] ?? '',
      rewardId: data['rewardId'] ?? '',
      rewardName: data['rewardName'] ?? '',
      pointCost: data['pointCost'] ?? 0,
      rewardType: data['rewardType'] ?? 'cash',
      cashValue: data['cashValue']?.toDouble(),
      machineType: data['machineType'],
      status: data['status'] ?? 'active',
      voucherCode: data['voucherCode'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: data['usedAt'] != null ? (data['usedAt'] as Timestamp).toDate() : null,
      expiresAt: data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
    );
  }

  // 获取显示值
  String get displayValue {
    if (rewardType == 'cash') {
      return 'RM${cashValue?.toStringAsFixed(2)} OFF';
    } else if (rewardType == 'free_use') {
      return 'Free ${machineType == 'washing' ? 'Washing' : 'Drying'}';
    }
    return rewardName;
  }

  // 获取状态颜色
  static Color getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'used':
        return Colors.blue;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  // 获取状态文本
  static String getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Available';
      case 'used':
        return 'Used';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }
}