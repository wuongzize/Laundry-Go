import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class ReservedMachinesPage extends StatelessWidget {
  const ReservedMachinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserved Machines'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 简单的查询，不需要索引
        stream: FirebaseFirestore.instance
            .collection('reserved_machines')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 显示加载状态
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading reservations...'),
                ],
              ),
            );
          }

          // 显示错误
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 50),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reservations',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // 可以在这里添加重试逻辑
                      Navigator.of(context).pop();
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // 检查是否有数据
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.schedule,
              title: 'No Reservations Yet',
              message: 'Reserve a machine to see it here.\nGo to a laundry and reserve a machine.',
            );
          }

          // 获取数据
          final reservations = snapshot.data!.docs;
          
          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              final data = reservation.data() as Map<String, dynamic>;
              
              // 安全获取数据
              final machineName = data['machineName'] ?? 'Unknown Machine';
              final laundryName = data['laundryName'] ?? 'Unknown Laundry';
              final collection = data['collection'] ?? 'washingMachines';
              final reservationTime = data['reservationTime']?.toDate();
              final statusChangeTime = data['statusChangeTime']?.toDate();
              final createdAt = data['createdAt']?.toDate();
              final machineId = data['machineId'] ?? '';
              final reservationId = reservation.id;
              final status = data['status'] ?? 'pending';
              final endTime = (data['endTime'] as Timestamp?)?.toDate();

              // Dynamic Status Calculation
              final now = DateTime.now();
              String displayStatus = status;
              
              if (status != 'completed') {
                if (reservationTime != null && endTime != null) {
                  if (now.isBefore(reservationTime)) {
                    displayStatus = 'pending';
                  } else if (now.isAfter(reservationTime) && now.isBefore(endTime)) {
                    displayStatus = 'active';
                  } else if (now.isAfter(endTime)) {
                    displayStatus = 'completed';
                  }
                }
              }

              // 状态颜色和文本
              Color statusColor = Colors.grey;
              String statusText = 'Pending';
              IconData statusIcon = Icons.schedule;
              
              switch (displayStatus) {
                case 'pending':
                  statusColor = Colors.orange;
                  statusText = 'Scheduled';
                  statusIcon = Icons.schedule;
                  break;
                case 'active':
                  statusColor = Colors.green; // Changed to green for active washing
                  statusText = 'Washing';
                  statusIcon = Icons.local_laundry_service;
                  break;
                case 'completed':
                  statusColor = Colors.blue;
                  statusText = 'Completed';
                  statusIcon = Icons.check_circle;
                  break;
                default:
                  statusColor = Colors.grey;
                  statusText = status;
                  statusIcon = Icons.help;
              }
              
              // 图标基于机器类型
              IconData machineIcon = collection == 'washingMachines' 
                  ? Icons.local_laundry_service 
                  : Icons.local_fire_department;
                  
              // 格式化时间显示
              String timeText = '';
              if (reservationTime != null) {
                timeText = 'Reserved for: ${_formatTime(reservationTime)}';
              }
              
              // 计算剩余时间（如果状态是pending或active）
              // 计算剩余时间（基于动态状态）
              String remainingText = '';
              
              if (displayStatus == 'pending' && reservationTime != null) {
                if (now.isBefore(reservationTime)) {
                  final duration = reservationTime.difference(now);
                  if (duration.inHours > 0) {
                    remainingText = 'Starts in: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
                  } else {
                    remainingText = 'Starts in: ${duration.inMinutes}m';
                  }
                } else {
                   remainingText = "Starting soon...";
                }
              } else if (displayStatus == 'active' && endTime != null) {
                   if (now.isBefore(endTime)) {
                     final duration = endTime.difference(now);
                     if (duration.inHours > 0) {
                       remainingText = 'Ends in: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
                     } else {
                       remainingText = 'Ends in: ${duration.inMinutes}m';
                     }
                   } else {
                     remainingText = "Laundry Done!";
                   }
              } else if (displayStatus == 'completed') {
                  remainingText = "Finished";
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      machineIcon,
                      size: 30,
                      color: statusColor,
                    ),
                  ),
                  title: Text(
                    machineName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        laundryName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (remainingText.isNotEmpty)
                        Text(
                          remainingText,
                          style: TextStyle(
                            fontSize: 13,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: status != 'completed'
                      ? IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          onPressed: () {
                            _showCancelDialog(
                              context,
                              reservationId,
                              machineId,
                              collection,
                              machineName,
                            );
                          },
                        )
                      : null,
                  onTap: () {
                    // 可以添加点击查看详情功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Viewing details for $machineName'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 刷新功能
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refreshing reservations...'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        backgroundColor: AppTheme.secondaryColor,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  // 格式化时间显示
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    
    // 判断上午/下午
    final period = time.hour < 12 ? 'AM' : 'PM';
    final displayHour = time.hour > 12 ? time.hour - 12 : time.hour;
    
    return '$displayHour:$minute $period';
  }

  // 显示取消预约对话框
  void _showCancelDialog(
    BuildContext context,
    String reservationId,
    String machineId,
    String collection,
    String machineName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cancel Reservation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this reservation?'),
            const SizedBox(height: 8),
            Text(
              'Machine: $machineName',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ This action cannot be undone.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Reservation',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // 关闭对话框
              await _cancelReservation(
                context,
                reservationId,
                machineId,
                collection,
              );
            },
            child: const Text(
              'Cancel Reservation',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 取消预约
  Future<void> _cancelReservation(
    BuildContext context,
    String reservationId,
    String machineId,
    String collection,
  ) async {
    try {
      // 显示加载状态
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 12),
              Text('Cancelling reservation...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // 更新机器状态为 available
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(machineId)
          .update({'status': 'available'});

      // 删除预约记录
      await FirebaseFirestore.instance
          .collection('reserved_machines')
          .doc(reservationId)
          .delete();

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reservation cancelled successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to cancel: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}