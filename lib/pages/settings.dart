import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.person), title: Text("Profile")),
          ListTile(leading: Icon(Icons.lock), title: Text("Change Password")),
          ListTile(leading: Icon(Icons.logout), title: Text("Logout")),
        ],
      ),
    );
  }
}
