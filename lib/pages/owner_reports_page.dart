// file name: owner_reports_page.dart (完全修复版本)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'report_model.dart';

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'pending';

  // 获取店主的报告
  // 修改 _getOwnerReports 方法
Stream<List<MachineReport>> _getOwnerReports() {
  final ownerUid = _auth.currentUser!.uid;
  
  return _firestore
      .collection('machine_reports')
      .snapshots()  // 移除 orderBy，避免复合查询
      .asyncMap((snapshot) async {
    final reports = <MachineReport>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final laundryId = data['laundryId'] ?? '';
      
      // 检查洗衣店是否属于当前店主
      if (laundryId.isNotEmpty) {
        try {
          final laundryDoc = await _firestore.collection('laundries').doc(laundryId).get();
          if (laundryDoc.exists && laundryDoc.data()?['ownerUid'] == ownerUid) {
            final report = MachineReport.fromFirestore(doc);
            if (_selectedFilter == 'all' || report.status == _selectedFilter) {
              reports.add(report);
            }
          }
        } catch (e) {
          print('Error checking laundry ownership: $e');
        }
      }
    }
    
    // 在内存中按创建时间排序
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return reports;
  });
}

  // 更新报告状态
  Future<void> _updateReportStatus(String reportId, String status, {String? notes}) async {
    try {
      await _firestore.collection('machine_reports').doc(reportId).update({
        'status': status,
        'resolvedAt': (status == 'resolved' || status == 'rejected') 
            ? FieldValue.serverTimestamp() 
            : null,
        'resolvedBy': (status == 'resolved' || status == 'rejected')
            ? _auth.currentUser!.uid
            : null,
        'resolutionNotes': notes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report marked as ${MachineReport.getStatusText(status)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                _buildDetailItem('Reported By', '${report.userName} (${report.userEmail})'),
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
                        _buildDetailItem('Resolved On', DateFormat('yyyy-MM-dd HH:mm').format(report.resolvedAt!)),
                        if (report.resolutionNotes != null && report.resolutionNotes!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resolution Notes:',
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

  // 显示状态更新对话框
  void _showStatusUpdateDialog(BuildContext context, MachineReport report) {
    final TextEditingController notesController = TextEditingController();
    String selectedStatus = report.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Report Status'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select new status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['pending', 'in_progress', 'resolved', 'rejected'].map((status) {
                    return ChoiceChip(
                      label: Text(MachineReport.getStatusText(status)),
                      selected: selectedStatus == status,
                      onSelected: (_) {
                        setState(() {
                          selectedStatus = status;
                        });
                      },
                      selectedColor: MachineReport.getStatusColor(status),
                      labelStyle: TextStyle(
                        color: selectedStatus == status ? Colors.white : Colors.black,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 备注输入
                TextFormField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any notes about this update...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateReportStatus(report.id, selectedStatus, notes: notesController.text.trim());
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Reports'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          // 过滤按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Reports'),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Text('Pending'),
              ),
              const PopupMenuItem(
                value: 'in_progress',
                child: Text('In Progress'),
              ),
              const PopupMenuItem(
                value: 'resolved',
                child: Text('Resolved'),
              ),
              const PopupMenuItem(
                value: 'rejected',
                child: Text('Rejected'),
              ),
            ],
          ),
        ],
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
                  const SizedBox(width: 10),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),

          // 报告列表
          Expanded(
            child: StreamBuilder<List<MachineReport>>(
              stream: _getOwnerReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_turned_in,
                    title: 'No Reports Found',
                    message: _getNoReportsMessage(),
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

  // 获取无报告时的消息
  String _getNoReportsMessage() {
    if (_selectedFilter == 'all') {
      return 'No machine reports yet';
    } else {
      return 'No $_selectedFilter reports';
    }
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
              child: Text(
                MachineReport.getStatusText(report.status),
                style: TextStyle(
                  color: MachineReport.getStatusColor(report.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'view') {
              _showReportDetails(context, report);
            } else if (value == 'update') {
              _showStatusUpdateDialog(context, report);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'update',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Update Status'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showReportDetails(context, report),
      ),
    );
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