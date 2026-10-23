import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class LaundryRegisterPage extends StatefulWidget {
  const LaundryRegisterPage({super.key});

  @override
  State<LaundryRegisterPage> createState() => _LaundryRegisterPageState();
}

class _LaundryRegisterPageState extends State<LaundryRegisterPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  bool loading = false;

  Future<void> saveLaundry() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = nameController.text.trim();
    final addr = addressController.text.trim();

    if (name.isEmpty || addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection("laundries").doc(uid).set({
      "name": name,
      "address": addr,
      "ownerId": uid, // Linked for verification
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pop(context); // return to owner homepage
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Laundry"),
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
              controller: nameController,
              decoration: const InputDecoration(labelText: "Laundry Name"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: "Laundry Address"),
            ),
            const SizedBox(height: 25),

            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: saveLaundry,
                    child: const Text("Save"),
                  ),
          ],
        ),
      ),
    );
  }
}
