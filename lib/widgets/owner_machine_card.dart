import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OwnerMachineCard extends StatelessWidget {
  final String machineName;
  final String status;
  final int todayUsed;
  final String? remainingTime;
  final bool isDryer;
  final Function(String) onStatusChanged;
  final VoidCallback onManualStart;
  final VoidCallback onManualStop;
  final VoidCallback onDelete;

  const OwnerMachineCard({
    super.key,
    required this.machineName,
    required this.status,
    required this.todayUsed,
    required this.onStatusChanged,
    required this.onManualStart,
    required this.onManualStop,
    required this.onDelete,
    this.remainingTime,
    this.isDryer = false,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'available': return Colors.green;
      case 'busy': return Colors.red;
      case 'reserved': return Colors.orange;
      case 'offline': return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final bool isBusy = status == 'busy';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDryer ? Icons.local_fire_department_rounded : Icons.local_laundry_service_rounded,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machineName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                       Row(
                        children: [
                          Icon(Icons.today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            "Used Today: $todayUsed",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete Machine',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Control Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Status Dropdown
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: status,
                        isExpanded: true,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child:  Row(children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text('Available')
                            ]),
                          ),
                          DropdownMenuItem(
                            value: 'busy',
                            child: Row(children: [
                              Icon(Icons.timelapse, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('Busy')
                            ]),
                          ),
                          DropdownMenuItem(
                            value: 'reserved',
                            child: Row(children: [
                              Icon(Icons.bookmark, color: Colors.orange, size: 16),
                              SizedBox(width: 8),
                              Text('Reserved')
                            ]),
                          ),
                          DropdownMenuItem(
                            value: 'offline',
                            child: Row(children: [
                              Icon(Icons.do_not_disturb_on, color: Colors.grey, size: 16),
                              SizedBox(width: 8),
                              Text('Offline')
                            ]),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) onStatusChanged(v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Action Buttons
                if (remainingTime != null)
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      remainingTime!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),
                
                // Manual Start/Stop
                if (!isBusy)
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.blue.shade50),
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.blue),
                    onPressed: onManualStart,
                    tooltip: 'Start Manual Cycle',
                  )
                else
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.orange.shade50),
                    icon: const Icon(Icons.stop_rounded, color: Colors.orange),
                    onPressed: onManualStop,
                    tooltip: 'Force Stop',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
