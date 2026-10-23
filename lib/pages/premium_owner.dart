
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class PremiumPage extends StatefulWidget {
  final String ownerUid;

  const PremiumPage({super.key, required this.ownerUid});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;

  Future<void> activatePremium() async {
    final code = codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => isLoading = true);

    // 假设 premium code 存在 Firestore 的 premium_codes collection
    final query = await FirebaseFirestore.instance
        .collection("premium_codes")
        .doc(code)
        .get();

    if (!query.exists) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid code")));
      return;
    }

    // 标记 owner 为 premium
    await FirebaseFirestore.instance
        .collection("owners")
        .doc(widget.ownerUid)
        .update({"premium": true});

    setState(() => isLoading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Premium activated!")));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activate Premium"),
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
              "Enter your activation code:",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter code",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : activatePremium,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Activate", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
