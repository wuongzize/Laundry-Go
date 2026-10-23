import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AutoPromotionPage extends StatefulWidget {
  const AutoPromotionPage({super.key, required String ownerUid});

  @override
  State<AutoPromotionPage> createState() => _AutoPromotionPageState();
}

class _AutoPromotionPageState extends State<AutoPromotionPage> {
  TimeOfDay? start;
  TimeOfDay? end;
  final TextEditingController voucherValueController = TextEditingController();

  /// 🔥 自动读取 Owner UID
  String get ownerUid => FirebaseAuth.instance.currentUser!.uid;

  /// 🔥 发放 Voucher 给所有用户
  Future<void> _giveVoucherToAllUsers(int amount, String type) async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection("users")
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final userUid = userDoc.id;
      final int amount = int.tryParse(voucherValueController.text) ?? 3;
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userUid)
          .collection("vouchers")
          .add({
            "title": "RM$amount OFF",
            "description": type == "auto"
                ? "Automatic promotion reward"
                : "Manual reward",
            "amount": amount,
            "type": type,
            "createdAt": Timestamp.now(),
            "expireAt": DateTime.now().add(const Duration(days: 1)),
            "fromOwner": ownerUid,
          });
    }
  }

  /// 🔥 保存 Auto Promotion
  Future<void> saveAutoPromotion() async {
    if (start == null || end == null) return;
    final int amount = int.tryParse(voucherValueController.text) ?? 3;

    final promotionsRef = FirebaseFirestore.instance
        .collection("owners")
        .doc(ownerUid)
        .collection("promotions");

    await promotionsRef.add({
      "type": "auto",
      "active": true,
      "startHour": start!.hour,
      "startMin": start!.minute,
      "endHour": end!.hour,
      "endMin": end!.minute,
      "amount": amount,
      "createdAt": Timestamp.now(),
    });

    /// 🔥 立刻发送一次 Voucher
    await _giveVoucherToAllUsers(3, "auto");

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Auto promotion saved")));
  }

  Future pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) setState(() => start = t);
  }

  Future pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) setState(() => end = t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auto Promotion"),
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
            TextField(
              controller: voucherValueController,
              decoration: const InputDecoration(
                labelText: "Voucher Value (RM)",
                hintText: "Enter voucher amount",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text("Start Time"),
              subtitle: Text(
                start == null ? "Not selected" : start!.format(context),
              ),
              trailing: const Icon(Icons.access_time),
              onTap: pickStart,
            ),
            ListTile(
              title: const Text("End Time"),
              subtitle: Text(
                end == null ? "Not selected" : end!.format(context),
              ),
              trailing: const Icon(Icons.access_time),
              onTap: pickEnd,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: saveAutoPromotion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Save & Activate"),
            ),
          ],
        ),
      ),
    );
  }
}
