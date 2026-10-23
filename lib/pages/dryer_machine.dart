import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class DryerMachinePage extends StatefulWidget {
  const DryerMachinePage({super.key});

  @override
  State<DryerMachinePage> createState() => _DryerMachinePageState();
}

class _DryerMachinePageState extends State<DryerMachinePage> {
  String? selectedLaundryId; // <-- 关键：存放用户选择的 Laundry Id

  Future<void> _addMachineDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String status = 'available';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Dryer Machine'),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('laundries')
              .where(
                'ownerUid',
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final laundryDocs = snapshot.data!.docs;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Machine name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Machine Name'),
                ),
                const SizedBox(height: 10),

                // Laundry selector
                DropdownButtonFormField<String>(
                  initialValue: selectedLaundryId,
                  hint: const Text("Select Laundry"),
                  items: laundryDocs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLaundryId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Machine status
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(value: 'busy', child: Text('Busy')),
                    DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  ],
                  onChanged: (v) => status = v!,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            );
          },
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedLaundryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select a Laundry first"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final uid = FirebaseAuth.instance.currentUser!.uid;

              await FirebaseFirestore.instance.collection('dryerMachines').add({
                'name': name,
                'status': status,
                'ownerUid': uid,
                'laundryId': selectedLaundryId, // <-- 与 WashingMachine 完全一致
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dryer Machines"),
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
        onPressed: () => _addMachineDialog(context),
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dryerMachines')
            .where('ownerUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No dryer machines added yet"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.local_laundry_service,
                    color: Colors.purple,
                  ),
                  title: Text(data['name']),
                  subtitle: Text("Status: ${data['status']}"),

                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('dryerMachines')
                          .doc(doc.id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
