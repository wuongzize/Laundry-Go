import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class VoucherPage extends StatefulWidget {
  final String userUid;

  const VoucherPage({super.key, required this.userUid});

  @override
  State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage> {
  final TextEditingController _studentIdController = TextEditingController();
  bool _isLoading = false;

  void _redeemStudentVoucher() async {
    final studentId = _studentIdController.text.trim().toUpperCase();
    
    // 1. Validate Format: 2 Letters + 8 Digits
    final RegExp idRegex = RegExp(r'^[A-Z]{2}\d{8}$');
    if (!idRegex.hasMatch(studentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Student ID Format (e.g., AB12345678)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDocRef = FirebaseFirestore.instance.collection("users").doc(widget.userUid);
      final userDoc = await userDocRef.get();
      
      // 2. Check Weekly Limit (Resets on Monday)
      final lastRedeem = (userDoc.data()?['lastStudentRedemptionDate'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      
      // Calculate start of current week (Monday)
      // weekday: 1=Mon, 7=Sun.
      // Subtract (weekday - 1) days to get to Monday.
      final todayStart = DateTime(now.year, now.month, now.day);
      final mondayOffset = now.weekday - 1; 
      final thisMonday = todayStart.subtract(Duration(days: mondayOffset)); // Midnight Monday

      bool canRedeem = true;
      if (lastRedeem != null) {
        if (lastRedeem.isAfter(thisMonday) || lastRedeem.isAtSameMomentAs(thisMonday)) {
          canRedeem = false;
        }
      }

      if (!canRedeem) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already redeemed this week. Resets on Monday.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. Award Voucher
      final expireDate = now.add(const Duration(days: 7)); // Valid for 1 week
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Add voucher
      final newVoucherRef = userDocRef.collection('vouchers').doc();
      batch.set(newVoucherRef, {
        "amount": 1,
        "type": "Student Discount",
        "fromOwner": "WasHero System",
        "expireAt": Timestamp.fromDate(expireDate),
        "createdAt": FieldValue.serverTimestamp(),
      });
      
      // Update last redemption date
      batch.update(userDocRef, {
        "lastStudentRedemptionDate": FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success! RM1 Voucher Redeemed.')),
      );
      
      _studentIdController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userUid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Voucher")),
        body: const Center(child: Text("Error: userUid not provided")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Voucher"),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
          ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Student Discount Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Student Discount",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your Student ID (e.g., AB12345678) to get RM1 OFF. Redeemable once a week (Resets Mon).",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _studentIdController,
                        decoration: const InputDecoration(
                          hintText: "Student ID",
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _redeemStudentVoucher,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Redeem"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(widget.userUid)
                  .collection("vouchers")
                  .orderBy("expireAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No vouchers yet"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final amount = data["amount"]?.toString() ?? "0";
                    final type = data["type"]?.toString() ?? "";
                    final fromOwner = data["fromOwner"]?.toString() ?? "";
                    final expireAtVal = data["expireAt"];
                    DateTime expireAt = DateTime.now();
                    
                    if (expireAtVal is Timestamp) {
                      expireAt = expireAtVal.toDate();
                    }

                    return _voucherCard(amount, type, fromOwner, expireAt);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _voucherCard(
    String amount,
    String type,
    String fromOwner,
    DateTime expireAt,
  ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(
          Icons.card_giftcard,
          size: 40,
          color: Colors.deepPurple,
        ),
        title: Text(
          "RM $amount OFF",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Type: $type"),
            Text("From Owner: $fromOwner"),
            Text("Expire At: ${expireAt.toString().substring(0, 16)}"),
          ],
        ),
      ),
    );
  }
}
