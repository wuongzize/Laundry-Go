// file name: user_reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'report_model.dart';
import '../theme/app_theme.dart';

class UserReportsPage extends StatefulWidget {
  const UserReportsPage({super.key});

  @override
  State<UserReportsPage> createState() => _UserReportsPageState();
}

class _UserReportsPageState extends State<UserReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'all';

  // 获取用户的报告
  Stream<List<MachineReport>> _getUserReports() {
  final userId = _auth.currentUser?.uid;
  if (userId == null) {
    return Stream.value([]);
  }

  return _firestore
      .collection('machine_reports')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    // 在内存中排序，而不是在查询中排序
    final reports = snapshot.docs
        .map((doc) => MachineReport.fromFirestore(doc))
        .toList();
    
    // 按创建时间排序
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // 过滤状态
    return reports.where((report) => 
        _selectedFilter == 'all' || report.status == _selectedFilter)
        .toList();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 过滤标签
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 10),
                  _buildFilterChip('In Progress', 'in_progress'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Resolved', 'resolved'),
                ],
              ),
            ),
          ),

          // 报告列表
          Expanded(
            child: StreamBuilder<List<MachineReport>>(
              stream: _getUserReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.report_problem, size: 80, color: Colors.grey),
                        const SizedBox(height: 20),
                        const Text(
                          'No Reports Yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedFilter == 'all' 
                            ? 'You haven\'t submitted any reports'
                            : 'No $_selectedFilter reports',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Go to Laundries'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建过滤标签
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: MachineReport.getStatusColor(value),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  // 构建报告卡片
  Widget _buildReportCard(MachineReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          MachineReport.getIssueTypeIcon(report.issueType),
          size: 40,
          color: MachineReport.getStatusColor(report.status),
        ),
        title: Text(
          report.machineName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text('Laundry: ${report.laundryName}'),
            Text('Issue: ${MachineReport.getIssueTypeText(report.issueType)}'),
            Text('Reported: ${DateFormat('MMM d, HH:mm').format(report.createdAt)}'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MachineReport.getStatusColor(report.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(report.status),
                    size: 14,
                    color: MachineReport.getStatusColor(report.status),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    MachineReport.getStatusText(report.status),
                    style: TextStyle(
                      color: MachineReport.getStatusColor(report.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // 显示解决信息
            if (report.resolvedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolved: ${DateFormat('MMM d, HH:mm').format(report.resolvedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    if (report.resolutionNotes != null && report.resolutionNotes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Notes: ${report.resolutionNotes}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        onTap: () => _showReportDetails(context, report),
      ),
    );
  }

  // 显示详细报告对话框
  void _showReportDetails(BuildContext context, MachineReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem('Machine', report.machineName),
                _buildDetailItem('Laundry', report.laundryName),
                _buildDetailItem('Issue Type', MachineReport.getIssueTypeText(report.issueType)),
                _buildDetailItem('Status', MachineReport.getStatusText(report.status)),
                _buildDetailItem('Reported On', DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt)),
                
                if (report.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          report.description,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                // 解决信息
                if (report.resolvedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resolution Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        _buildDetailItem('Resolved On', DateFormat('yyyy-MM-dd HH:mm').format(report.resolvedAt!)),
                        if (report.resolutionNotes != null && report.resolutionNotes!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notes from Owner:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(report.resolutionNotes!),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // 获取状态图标
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.build;
      case 'resolved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}