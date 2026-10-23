// file name: report_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MachineReport {
  final String id;
  final String machineId;
  final String machineName;
  final String collection;
  final String laundryId;
  final String laundryName;
  final String userId;
  final String userName;
  final String userEmail;
  final String issueType;
  final String description;
  final List<String> imageUrls;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  MachineReport({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.collection,
    required this.laundryId,
    required this.laundryName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.issueType,
    required this.description,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });

  // 将对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'machineName': machineName,
      'collection': collection,
      'laundryId': laundryId,
      'laundryName': laundryName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'issueType': issueType,
      'description': description,
      'imageUrls': imageUrls,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'resolutionNotes': resolutionNotes,
    };
  }

  // 从Firestore文档创建对象
  factory MachineReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MachineReport(
      id: doc.id,
      machineId: data['machineId'] ?? '',
      machineName: data['machineName'] ?? '',
      collection: data['collection'] ?? 'washingMachines',
      laundryId: data['laundryId'] ?? '',
      laundryName: data['laundryName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      issueType: data['issueType'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      resolvedAt: data['resolvedAt'] != null ? (data['resolvedAt'] as Timestamp).toDate() : null,
      resolvedBy: data['resolvedBy'],
      resolutionNotes: data['resolutionNotes'],
    );
  }

  // 获取状态颜色
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 获取状态文本
  static String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  // 获取问题类型图标
  static IconData getIssueTypeIcon(String issueType) {
    switch (issueType) {
      case 'not_working':
        return Icons.error;
      case 'leaking':
        return Icons.water_damage;
      case 'no_power':
        return Icons.power_off;
      case 'stuck':
        return Icons.block;
      case 'noisy':
        return Icons.volume_up;
      case 'dirty':
        return Icons.cleaning_services;
      default:
        return Icons.report_problem;
    }
  }

  // 获取问题类型文本
  static String getIssueTypeText(String issueType) {
    switch (issueType) {
      case 'not_working':
        return 'Not Working';
      case 'leaking':
        return 'Leaking Water';
      case 'no_power':
        return 'No Power';
      case 'stuck':
        return 'Stuck Door';
      case 'noisy':
        return 'Too Noisy';
      case 'dirty':
        return 'Very Dirty';
      default:
        return 'Other Issue';
    }
  }
}