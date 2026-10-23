import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'AddPromotionDialog.dart';
import '../theme/app_theme.dart';

class PromotePage extends StatelessWidget {
  final String ownerUid;

  const PromotePage({super.key, required this.ownerUid});

  // 执行 Manual Promotion
  Future<void> executeManualPromotion(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final amount = data["amount"] ?? 0;

    final users = await FirebaseFirestore.instance.collection("users").get();
    for (final u in users.docs) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(u.id)
          .collection("vouchers")
          .add({
            "amount": amount,
            "expireAt": DateTime.now().add(const Duration(days: 1)),
            "fromOwner": ownerUid,
            "type": "manual",
          });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Voucher sent: RM$amount")));
    }
  }

  // 编辑 Manual / Auto Promotion
  void editPromotion(
    BuildContext context,
    DocumentSnapshot doc,
    String type,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final collection = FirebaseFirestore.instance
        .collection("owners")
        .doc(ownerUid)
        .collection("promotions");

    if (type == "manual") {
      double amount = data["amount"] ?? 1;
      TextEditingController controller = TextEditingController(
        text: amount.toString(),
      );

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Edit Manual Promotion"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Discount Amount (RM)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                double newAmount = double.tryParse(controller.text) ?? amount;
                collection.doc(doc.id).update({"amount": newAmount});
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      );
    } else if (type == "auto") {
      double amount = data["amount"] ?? 1;
      TimeOfDay start = TimeOfDay(
        hour: data["startHour"] ?? 8,
        minute: 0,
      ); // 默认 8:00
      TimeOfDay end = TimeOfDay(
        hour: data["endHour"] ?? 10,
        minute: 0,
      ); // 默认10:00
      TextEditingController controller = TextEditingController(
        text: amount.toString(),
      );

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text("Edit Auto Promotion"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Discount Amount (RM)",
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Start Time: "),
                    TextButton(
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: start,
                        );
                        if (picked != null) {
                          setStateDialog(() => start = picked);
                        }
                      },
                      child: Text(start.format(context)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text("End Time: "),
                    TextButton(
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: end,
                        );
                        if (picked != null) setStateDialog(() => end = picked);
                      },
                      child: Text(end.format(context)),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Active"),
                  value: data["active"] ?? false,
                  onChanged: (v) {
                    collection.doc(doc.id).update({"active": v});
                    setStateDialog(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  int startHour = start.hour;
                  int endHour = end.hour;
                  double newAmount = double.tryParse(controller.text) ?? amount;
                  collection.doc(doc.id).update({
                    "amount": newAmount,
                    "startHour": startHour,
                    "endHour": endHour,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Promotion Settings"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddPromotionDialog(ownerUid: ownerUid),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Promotion Status",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("owners")
                    .doc(ownerUid)
                    .collection("promotions")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text("No promotions set"));
                  }

                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data["type"] ?? "manual";
                      final isActive = data["active"] ?? false;
                      final amount = data["amount"] ?? 1;
                      final startHour = data["startHour"] ?? 8;
                      final endHour = data["endHour"] ?? 10;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$type Promotion",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isActive)
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.green.withOpacity(0.1),
                                         borderRadius: BorderRadius.circular(8),
                                       ),
                                       child: const Text("Active", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                     )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (type == "manual")
                                Text("Amount: RM$amount", style: const TextStyle(fontSize: 16, color: Colors.black87)),
                              if (type == "auto")
                                Text(
                                  "Amount: RM$amount\nTime: $startHour:00 - $endHour:00",
                                  style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (type == "manual")
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () => executeManualPromotion(context, doc),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text("Execute Again"),
                                      ),
                                    ),
                                  if (type == "auto")
                                    Switch(
                                      value: isActive,
                                      onChanged: (v) {
                                        FirebaseFirestore.instance
                                            .collection("owners")
                                            .doc(ownerUid)
                                            .collection("promotions")
                                            .doc(doc.id)
                                            .update({"active": v});
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                    onPressed: () => editPromotion(context, doc, type),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Delete Promotion"),
                                          content: const Text("Are you sure?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                            TextButton(
                                              onPressed: () {
                                                FirebaseFirestore.instance
                                                    .collection("owners")
                                                    .doc(ownerUid)
                                                    .collection("promotions")
                                                    .doc(doc.id)
                                                    .delete();
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
