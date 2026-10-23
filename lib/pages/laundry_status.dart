import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LaundryStatusPage extends StatelessWidget {
  const LaundryStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laundry Status"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _statusCard(
              title: "Washing Machine 1",
              isAvailable: true, // 未来可以连 Firebase IoT 数据
            ),
            _statusCard(title: "Washing Machine 2", isAvailable: false),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({required String title, required bool isAvailable}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 18),
      child: ListTile(
        leading: Icon(
          Icons.local_laundry_service,
          size: 40,
          color: isAvailable ? Colors.green : Colors.red,
        ),
        title: Text(title, style: const TextStyle(fontSize: 20)),
        subtitle: Text(
          isAvailable ? "Available" : "In Use",
          style: TextStyle(
            fontSize: 16,
            color: isAvailable ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
