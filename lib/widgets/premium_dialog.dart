import 'package:flutter/material.dart';
import '../pages/subscription_page.dart';

class PremiumDialog extends StatelessWidget {
  final String featureName;

  const PremiumDialog({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.workspace_premium, color: Colors.amber),
          SizedBox(width: 10),
          Text('Premium Feature'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The "$featureName" feature is available only for Premium members.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to Premium to access:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('Reserve Machines'),
          _buildFeatureItem('Collect Points'),
          _buildFeatureItem('Redeem Rewards'),
          _buildFeatureItem('Exclusive Vouchers'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
