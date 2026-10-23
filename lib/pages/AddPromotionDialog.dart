import 'package:flutter/material.dart';
import 'ManualPromotionPage.dart';
import 'AutoPromotionPage.dart';

class AddPromotionDialog extends StatelessWidget {
  final String ownerUid;

  const AddPromotionDialog({super.key, required this.ownerUid});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Promotion"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text("Manual Promotion"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManualPromotionPage(ownerUid: ownerUid),
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Auto Promotion"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AutoPromotionPage(ownerUid: ownerUid), // ✅ 正确
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
