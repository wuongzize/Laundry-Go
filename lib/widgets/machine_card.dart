import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MachineCard extends StatelessWidget {
  final String machineName;
  final String status;
  final String? remainingTime;
  final VoidCallback? onBook;
  final VoidCallback? onReport;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final bool isDryer;

  const MachineCard({
    super.key,
    required this.machineName,
    required this.status,
    this.remainingTime,
    this.onBook,
    this.onReport,
    this.onFavorite,
    this.isFavorite = false,
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

  String _getStatusText() {
    switch (status) {
      case 'available': return "Available";
      case 'busy': return "In Use";
      case 'reserved': return "Reserved";
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final bool isAvailable = status == 'available';

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
        border: Border.all(
          color: isAvailable ? Colors.green.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDryer ? Icons.local_fire_department_rounded : Icons.local_laundry_service_rounded,
                    color: statusColor,
                    size: 32,
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
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                       if (!isAvailable && remainingTime != null) 
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Ends in: $remainingTime",
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    if (onFavorite != null)
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: onFavorite,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Bottom Actions
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReport != null)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppTheme.textSecondary),
                    label: const Text("Report", style: TextStyle(color: AppTheme.textSecondary)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                const SizedBox(width: 8),
                if (isAvailable && onBook != null)
                  ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text("Book Now"),
                  )
                else
                   OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Unavailable"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
