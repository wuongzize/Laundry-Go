import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class WashingMachinePage extends StatefulWidget {
  const WashingMachinePage({super.key});

  @override
  State<WashingMachinePage> createState() => _WashingMachinePageState();
}

class _WashingMachinePageState extends State<WashingMachinePage> {
  String? selectedLaundryId;

  // -----------------------------
  // Status UI Mapping Functions
  // -----------------------------
  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'busy':
        return Colors.red;
      case 'reserved':
        return Colors.orange;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return "Available";
      case 'busy':
        return "In Use";
      case 'reserved':
        return "Reserved";
      case 'offline':
        return "Offline";
      default:
        return status;
    }
  }

  // -----------------------------
  // Add Machine Dialog
  // -----------------------------
  Future<void> _addMachineDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String status = 'available';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Washing Machine'),
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

            final laundries = snapshot.data!.docs;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Machine Name'),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: selectedLaundryId,
                  hint: const Text("Select Laundry"),
                  items: laundries.map((doc) {
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

                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(value: 'busy', child: Text('Busy')),
                    DropdownMenuItem(
                      value: 'reserved',
                      child: Text('Reserved'),
                    ),
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
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedLaundryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please select a Laundry"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final uid = FirebaseAuth.instance.currentUser!.uid;

              await FirebaseFirestore.instance
                  .collection('washingMachines')
                  .add({
                    'name': name,
                    'status': status,
                    'ownerUid': uid,
                    'laundryId': selectedLaundryId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Main UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Washing Machines"),
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
            .collection('washingMachines')
            .where('ownerUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No washing machines added yet"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.local_laundry_service,
                    size: 40,
                    color: _getStatusColor(data['status']),
                  ),
                  title: Text(
                    data['name'],
                    style: const TextStyle(fontSize: 20),
                  ),
                  subtitle: Text(
                    _getStatusText(data['status']),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(data['status']),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('washingMachines')
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
