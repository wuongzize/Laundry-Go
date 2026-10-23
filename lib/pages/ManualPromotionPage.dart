import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ManualPromotionPage extends StatefulWidget {
  final String ownerUid;

  const ManualPromotionPage({super.key, required this.ownerUid});

  @override
  State<ManualPromotionPage> createState() => _ManualPromotionPageState();
}

class _ManualPromotionPageState extends State<ManualPromotionPage> {
  double? selectedAmount;
  bool isSending = false;

  /// 发放 voucher
  Future<void> _sendVoucherToAllUsers(double amount) async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final userUid = userDoc.id;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userUid)
          .collection("vouchers")
          .add({
            "title": "RM$amount OFF",
            "description": "Manual Promotion",
            "amount": amount,
            "type": "manual",
            "createdAt": Timestamp.now(),
            "expireAt": Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 1)),
            ),
          });
    }
  }

  Future<void> executeManualPromotion() async {
    if (selectedAmount == null) return;

    setState(() => isSending = true);

    try {
      await _sendVoucherToAllUsers(selectedAmount!);

      // 保存 promotion 記錄
      await FirebaseFirestore.instance
          .collection("owners")
          .doc(widget.ownerUid)
          .collection("promotions")
          .add({
            "type": "manual",
            "active": false,
            "amount": selectedAmount,
            "createdAt": Timestamp.now(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Voucher Sent: RM$selectedAmount")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manual Promotion"),
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
              "Select Discount Amount",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [1, 2, 3, 4, 5].map((e) {
                return ChoiceChip(
                  label: Text("RM$e"),
                  selected: selectedAmount == e.toDouble(),
                  onSelected: (_) =>
                      setState(() => selectedAmount = e.toDouble()),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isSending ? null : executeManualPromotion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Execute Promotion",
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
