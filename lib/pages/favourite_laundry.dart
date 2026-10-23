import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:laundry_app/pages/laundry_machines.dart';
import '../theme/app_theme.dart';

class FavouriteLaundriesPage extends StatelessWidget {
  const FavouriteLaundriesPage({super.key});

  // 获取洗衣店的可用机器统计
  Future<Map<String, dynamic>> _getLaundryStats(String laundryId) async {
    final washingSnapshot = await FirebaseFirestore.instance
        .collection('washingMachines')
        .where('laundryId', isEqualTo: laundryId)
        .get();

    final dryerSnapshot = await FirebaseFirestore.instance
        .collection('dryerMachines')
        .where('laundryId', isEqualTo: laundryId)
        .get();

    final totalWashing = washingSnapshot.docs.length;
    final availableWashing = washingSnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'available') == 'available')
        .length;

    final totalDryer = dryerSnapshot.docs.length;
    final availableDryer = dryerSnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'available') == 'available')
        .length;

    return {
      'washing': '$availableWashing/$totalWashing',
      'dryer': '$availableDryer/$totalDryer',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourite Laundries'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favourite_laundries')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final favourites = snapshot.data!.docs;

          if (favourites.isEmpty) {
            return const Center(child: Text('No favourite laundries yet'));
          }

          return ListView.builder(
            itemCount: favourites.length,
            itemBuilder: (context, index) {
              final fav = favourites[index];
              final laundryId = fav['laundryId'];
              final laundryName = fav['laundryName'];

              return FutureBuilder<Map<String, dynamic>>(
                future: _getLaundryStats(laundryId),
                builder: (context, statsSnapshot) {
                  final stats = statsSnapshot.data ?? {'washing': '0/0', 'dryer': '0/0'};

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.local_laundry_service, size: 40, color: Colors.red),
                      title: Text(laundryName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Washing Machines: ${stats['washing']} available'),
                          Text('Dryer Machines: ${stats['dryer']} available'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () {
                              favourites[index].reference.delete();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LaundryMachinesPage(
                                    laundryId: laundryId,
                                    laundryName: laundryName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}