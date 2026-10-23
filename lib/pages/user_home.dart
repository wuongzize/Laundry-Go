import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Added for Timer
import '../widget/app_drawer.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_card.dart';
import 'laundry_machines.dart';
import 'voucher.dart';
import 'favourite_machine.dart';
import 'favourite_laundry.dart';
import 'reserved_machine.dart';
import 'user_reports_page.dart';
import 'points_page.dart';
import 'subscription_page.dart';
import '../widgets/premium_dialog.dart';
import '../services/notification_service.dart';
import 'notification_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  bool _isPremium = false;
  String searchQuery = "";

  bool showDropdown = false;
  final TextEditingController _controller = TextEditingController();
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _checkNotifications();
    // Check every minute
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkNotifications());
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isPremium = doc.data()?['isPremium'] ?? false;
        });
      }
    }
  }

  void _checkNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      NotificationService().checkReservations(user.uid);
    }
  }

  void _handlePremiumFeature(String featureName, Widget page) {
    if (_isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => PremiumDialog(featureName: featureName),
      ).then((_) => _checkPremiumStatus()); // Re-check in case they upgraded
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(role: "user", isOwner: false),
      appBar: AppBar(
        title: const Text("User Dashboard"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          if (!_isPremium)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                ).then((_) => _checkPremiumStatus());
              },
              icon: const Icon(Icons.star, color: Colors.amber),
              label: const Text('Go Premium', style: TextStyle(color: Colors.amber)),
            ),
          // Notification Icon with Badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.length;
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationPage()),
                      ).then((_) => _checkNotifications());
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            showDropdown = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Find Your Laundry",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium, size: 16, color: Colors.deepOrange),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Search laundry by name...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            searchQuery = "";
                            showDropdown = false;
                          });
                        },
                      ) 
                    : null,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.trim().toLowerCase();
                    showDropdown = true;
                  });
                },
                onTap: () {
                  setState(() {
                    showDropdown = true;
                  });
                },
              ),
              const SizedBox(height: 10),
              
              if (showDropdown)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("laundries")
                          .orderBy("name")
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        final filtered = docs.where((d) {
                          final name = d["name"].toString().toLowerCase();
                          return name.contains(searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("No matching laundry found."),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = filtered[index];
                            return ListTile(
                              title: Text(doc["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(doc["address"] ?? "No address"),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LaundryMachinesPage(
                                      laundryId: doc.id,
                                      laundryName: doc["name"],
                                    ),
                                  ),
                                ).then((_) {
                                  setState(() {
                                    showDropdown = false;
                                    _controller.clear();
                                  });
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              
              if (!showDropdown) ...[
                const SizedBox(height: 20),
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      DashboardCard(
                        title: "Favorites",
                        subtitle: "Machines",
                        icon: Icons.star_rounded,
                        color: Colors.amber,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FavouriteMachinesPage()),
                        ),
                      ),
                      DashboardCard(
                        title: "My Laundries",
                        subtitle: "Saved Places",
                        icon: Icons.favorite_rounded,
                        color: Colors.pink,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FavouriteLaundriesPage()),
                        ),
                      ),
                      DashboardCard(
                        title: "Reservations",
                        subtitle: "Active Bookings",
                        icon: Icons.schedule_rounded,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReservedMachinesPage()),
                        ),
                      ),
                      DashboardCard(
                        title: "Vouchers",
                        subtitle: "My Rewards",
                        icon: Icons.card_giftcard_rounded,
                        color: Colors.purple,
                        onTap: () {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null) {
                            _handlePremiumFeature(
                              'Exclusive Vouchers',
                              VoucherPage(userUid: currentUser.uid),
                            );
                          }
                        },
                      ),
                      DashboardCard(
                        title: "My Points",
                        subtitle: "Redeem Rewards",
                        icon: Icons.loyalty_rounded,
                        color: Colors.teal,
                        onTap: () => _handlePremiumFeature(
                          'Redeem Rewards',
                          const PointsPage(),
                        ),
                      ),
                       DashboardCard(
                        title: "Report Issue",
                        subtitle: "Get Help",
                        icon: Icons.report_problem_rounded,
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserReportsPage()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}