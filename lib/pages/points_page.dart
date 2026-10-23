// file name: points_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'point_model.dart';
import 'point_service.dart';
import 'reward_page.dart'; // 奖励页面
import 'user_rewards_page.dart';
import '../theme/app_theme.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  final PointService _pointService = PointService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentBalance = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Points'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RewardPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 积分余额卡片
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Your Points Balance',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<int>(
                    stream: _pointService.getUserPointBalance(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0;
                      _currentBalance = balance;
                      return Text(
                        balance.toString(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Points',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoItem('Earn 10 points', 'Per reservation'),
                      const SizedBox(width: 20),
                      _buildInfoItem('Redeem rewards', 'Exchange points'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 兑换奖励按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RewardPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.card_giftcard, color: Colors.white),
                label: const Text(
                  'Redeem Rewards',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          
          const SizedBox(height: 10),

          // My Redemptions Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserRewardsPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.history, color: Colors.deepPurple),
                label: const Text(
                  'My Redemptions',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 交易记录标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 交易记录列表
          Expanded(
            child: StreamBuilder<List<PointTransaction>>(
              stream: _pointService.getUserPointTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Make a reservation to earn points!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionCard(transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(PointTransaction transaction) {
    final isEarn = transaction.type == 'earn';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isEarn ? Colors.green.shade100 : Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEarn ? Icons.add_circle : Icons.remove_circle,
            color: isEarn ? Colors.green : Colors.blue,
            size: 30,
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(transaction.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isEarn ? '+' : '-'}${transaction.amount}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isEarn ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'points',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}