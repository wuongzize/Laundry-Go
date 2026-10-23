import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_dialog.dart';

class AppDrawer extends StatelessWidget {
  final bool isOwner;

  const AppDrawer({super.key, required this.isOwner, required String role});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.local_laundry_service,
                    color: Colors.white,
                    size: 48,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'WasHero Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // USER / OWNER
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: Text(
                isOwner ? 'Owner' : 'User',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),



            // Setting
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),

            // Voucher
            ListTile(
              leading: const Icon(Icons.card_giftcard, color: Colors.white),
              title: const Text(
                'Voucher',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Check Status
                  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final isPremium = doc.data()?['isPremium'] ?? false;
                  
                  if (context.mounted) {
                    if (isPremium) {
                      Navigator.pushNamed(context, '/voucher');
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => const PremiumDialog(featureName: 'Voucher'),
                      );
                    }
                  }
                }
              },
            ),

            const Divider(color: Colors.white60),

            // Quit
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
