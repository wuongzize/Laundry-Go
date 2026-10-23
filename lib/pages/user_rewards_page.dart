// file name: user_rewards_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:laundry_app/pages/reward_page.dart';
import 'reward_model.dart';
import 'point_service.dart';
import '../theme/app_theme.dart';

class UserRewardsPage extends StatefulWidget {
  const UserRewardsPage({super.key});

  @override
  State<UserRewardsPage> createState() => _UserRewardsPageState();
}

class _UserRewardsPageState extends State<UserRewardsPage> {
  final PointService _pointService = PointService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rewards'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<UserReward>>(
        stream: _pointService.getUserRewards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rewards = snapshot.data ?? [];

          if (rewards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.card_giftcard, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    'No Rewards Yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Redeem your points for rewards!',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RewardPage()),
                      );
                    },
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Browse Rewards'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return _buildRewardCard(reward);
            },
          );
        },
      ),
    );
  }

  Widget _buildRewardCard(UserReward reward) {
    final isExpired = reward.expiresAt != null && 
                      DateTime.now().isAfter(reward.expiresAt!) &&
                      reward.status != 'used';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: UserReward.getStatusColor(reward.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              _getRewardIcon(reward),
              size: 30,
              color: UserReward.getStatusColor(reward.status),
            ),
          ),
        ),
        title: Text(
          reward.rewardName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              reward.displayValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: UserReward.getStatusColor(reward.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(reward.status),
                        size: 14,
                        color: UserReward.getStatusColor(reward.status),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        UserReward.getStatusText(reward.status),
                        style: TextStyle(
                          color: UserReward.getStatusColor(reward.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reward.voucherCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Code: ${reward.voucherCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Redeemed: ${DateFormat('MMM d, yyyy').format(reward.createdAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (reward.expiresAt != null)
              Text(
                'Expires: ${DateFormat('MMM d, yyyy').format(reward.expiresAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? Colors.red : Colors.orange,
                ),
              ),
          ],
        ),
        trailing: reward.status == 'active' && reward.voucherCode != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _copyVoucherCode(reward.voucherCode!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text(
                      'Copy',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  IconData _getRewardIcon(UserReward reward) {
    if (reward.status == 'used') return Icons.check_circle;
    if (reward.status == 'expired') return Icons.timer_off;
    
    if (reward.rewardType == 'cash') return Icons.attach_money;
    if (reward.rewardType == 'free_use') {
      return reward.machineType == 'washing' 
          ? Icons.local_laundry_service 
          : Icons.local_fire_department;
    }
    
    return Icons.card_giftcard;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'used':
        return Icons.done_all;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.help;
    }
  }

  Future<void> _copyVoucherCode(String code) async {
    // 这里需要添加剪贴板功能
    // 你可以使用 flutter/services 中的 Clipboard
    // 或者显示一个对话框
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $code'),
        backgroundColor: Colors.green,
      ),
    );
  }
}