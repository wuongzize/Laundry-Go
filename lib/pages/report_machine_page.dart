// file name: report_machine_page.dart (替换原有内容)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class ReportMachinePage extends StatefulWidget {
  final String machineId;
  final String machineName;
  final String collection;
  final String laundryId;
  final String laundryName;

  const ReportMachinePage({
    super.key,
    required this.machineId,
    required this.machineName,
    required this.collection,
    required this.laundryId,
    required this.laundryName,
  });

  @override
  State<ReportMachinePage> createState() => _ReportMachinePageState();
}

class _ReportMachinePageState extends State<ReportMachinePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedIssueType = 'not_working';
  bool _isSubmitting = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 问题类型选项
  final List<Map<String, dynamic>> _issueTypes = [
    {'value': 'not_working', 'text': 'Not Working', 'icon': Icons.error},
    {'value': 'leaking', 'text': 'Leaking Water', 'icon': Icons.water_damage},
    {'value': 'no_power', 'text': 'No Power', 'icon': Icons.power_off},
    {'value': 'stuck', 'text': 'Stuck Door', 'icon': Icons.block},
    {'value': 'noisy', 'text': 'Too Noisy', 'icon': Icons.volume_up},
    {'value': 'dirty', 'text': 'Very Dirty', 'icon': Icons.cleaning_services},
    {'value': 'other', 'text': 'Other Issue', 'icon': Icons.report_problem},
  ];

  // 提交报告
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _auth.currentUser!;
      
      // 获取用户信息
      String userName = user.email?.split('@')[0] ?? 'User';
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        userName = userDoc.data()!['name'] ?? user.email?.split('@')[0] ?? 'User';
      }

      // 获取 laundry 的 ownerUid
      String ownerUid = '';
      try {
        final laundryDoc = await _firestore.collection('laundries').doc(widget.laundryId).get();
        if (laundryDoc.exists) {
          ownerUid = laundryDoc.data()?['ownerUid'] ?? '';
        }
      } catch (e) {
        print('Error fetching laundry ownerUid: $e');
      }

      // 创建报告文档
      await _firestore.collection('machine_reports').add({
        'ownerUid': ownerUid, // for owner notifications
        'machineId': widget.machineId,
        'machineName': widget.machineName,
        'collection': widget.collection,
        'laundryId': widget.laundryId,
        'laundryName': widget.laundryName,
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email!,
        'issueType': _selectedIssueType,
        'description': _descriptionController.text.trim(),
        'imageUrls': [], // 空数组，不需要图片
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 更新机器的状态
      await _firestore.collection(widget.collection).doc(widget.machineId).update({
        'needsRepair': true,
        'lastReported': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Machine Issue'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 机器信息卡片
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Machine Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.local_laundry_service, 'Machine:', widget.machineName),
                      _buildDetailRow(Icons.store, 'Laundry:', widget.laundryName),
                      _buildDetailRow(
                        Icons.category,
                        'Type:',
                        widget.collection == 'washingMachines' ? 'Washing Machine' : 'Dryer Machine',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 问题类型选择
              const Text(
                'Issue Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _issueTypes.map((issue) {
                  final isSelected = _selectedIssueType == issue['value'];
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(issue['icon'], size: 16),
                        const SizedBox(width: 6),
                        Text(issue['text']),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedIssueType = issue['value'];
                      });
                    },
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 问题描述
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Please describe the issue in detail...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue';
                  }
                  if (value.trim().length < 10) {
                    return 'Description should be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 10),

              // 取消按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}