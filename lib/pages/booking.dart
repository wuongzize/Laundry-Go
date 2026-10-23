import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laundry Booking"),
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
            const Text(
              "Choose a time slot",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _slot("9:00 AM"),
            _slot("11:00 AM"),
            _slot("2:00 PM"),
            _slot("4:00 PM"),
          ],
        ),
      ),
    );
  }

  Widget _slot(String time) {
    return Card(
      child: ListTile(
        title: Text(time, style: const TextStyle(fontSize: 18)),
        trailing: ElevatedButton(onPressed: () {}, child: const Text("Book")),
      ),
    );
  }
}
