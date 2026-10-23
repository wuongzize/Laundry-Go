// file name: reward_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'reward_model.dart';
import 'point_service.dart';
import 'user_rewards_page.dart'; // 用户已兑换奖励页面
import '../theme/app_theme.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final PointService _pointService = PointService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentBalance = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserRewardsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 积分余额和说明
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Points',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: _pointService.getUserPointBalance(),
                        builder: (context, snapshot) {
                          final balance = snapshot.data ?? 0;
                          _currentBalance = balance;
                          return Text(
                            '$balance pts',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Exchange your points for exciting rewards!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 奖励列表标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available Rewards',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 奖励列表
          Expanded(
            child: StreamBuilder<List<Reward>>(
              stream: _pointService.getAvailableRewards(),
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
                        const Icon(Icons.card_giftcard, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No rewards available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check back later for new rewards!',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _pointService.seedDefaultRewards();
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Initialize Default Rewards'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade100,
                            foregroundColor: Colors.deepPurple,
                          ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Reward reward) {
    final canAfford = _currentBalance >= reward.pointCost;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              reward.icon,
              style: const TextStyle(fontSize: 30),
            ),
          ),
        ),
        title: Text(
          reward.name,
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
              reward.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 5,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        '${reward.pointCost} pts',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reward.type == 'cash')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'RM${reward.cashValue?.toStringAsFixed(2)} OFF',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (reward.type == 'free_use')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Free ${reward.machineType == 'washing' ? 'Wash' : 'Dry'}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (reward.stock > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Stock: ${reward.stock} available',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAfford ? () => _redeemReward(reward) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? Colors.deepPurple : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  canAfford ? 'Redeem' : 'Need ${reward.pointCost - _currentBalance} more',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemReward(Reward reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Redeem "${reward.name}"?'),
            const SizedBox(height: 10),
            Text(
              'This will cost ${reward.pointCost} points.',
              style: const TextStyle(color: Colors.amber),
            ),
            const SizedBox(height: 10),
            if (reward.type == 'cash')
              Text('Value: RM${reward.cashValue?.toStringAsFixed(2)} OFF'),
            if (reward.type == 'free_use')
              Text('You will receive a free ${reward.machineType == 'washing' ? 'washing' : 'drying'} voucher'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userReward = await _pointService.redeemReward(reward.id);
        
        if (userReward != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully redeemed ${reward.name}!'),
              backgroundColor: Colors.green,
            ),
          );

          // 显示兑换成功对话框
          await _showRedemptionSuccess(context, userReward);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to redeem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRedemptionSuccess(BuildContext context, UserReward userReward) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Redemption Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have successfully redeemed:'),
            const SizedBox(height: 10),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userReward.rewardName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userReward.displayValue,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (userReward.voucherCode != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Voucher Code:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userReward.voucherCode!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'monospace',
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your voucher has been added to your account.',
              style: TextStyle(color: Colors.grey),
            ),
            if (userReward.expiresAt != null)
              Text(
                'Expires: ${DateFormat('MMM d, yyyy').format(userReward.expiresAt!)}',
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('View My Rewards'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserRewardsPage()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}