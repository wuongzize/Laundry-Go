// file name: point_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:laundry_app/pages/point_model.dart';
import 'package:laundry_app/pages/reward_model.dart';

class PointService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 为用户添加积分
  Future<void> addPointsForReservation(String reservationId, String machineName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    const int pointsPerReservation = 10;
    final userId = user.uid;

    try {
      // 1. 获取用户当前积分
      final pointDoc = await _firestore
          .collection('user_points')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      // 2. 更新或创建积分记录
      if (pointDoc.docs.isNotEmpty) {
        // 更新现有记录
        final currentDoc = pointDoc.docs.first;
        final currentBalance = currentDoc['balance'] ?? 0;
        final currentTotalEarned = currentDoc['totalEarned'] ?? 0;

        await currentDoc.reference.update({
          'balance': currentBalance + pointsPerReservation,
          'totalEarned': currentTotalEarned + pointsPerReservation,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 创建新记录
        await _firestore.collection('user_points').add({
          'userId': userId,
          'balance': pointsPerReservation,
          'totalEarned': pointsPerReservation,
          'totalSpent': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. 记录积分交易
      await _firestore.collection('point_transactions').add({
        'userId': userId,
        'amount': pointsPerReservation,
        'type': 'earn',
        'description': 'Points earned for reserving $machineName',
        'referenceId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error adding points: $e');
      rethrow;
    }
  }

  // 获取用户积分余额
  Stream<int> getUserPointBalance() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('user_points')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['balance'] ?? 0;
      }
      return 0;
    });
  }

  // 获取用户积分交易记录
  Stream<List<PointTransaction>> getUserPointTransactions() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('point_transactions')
        .where('userId', isEqualTo: user.uid)
        // .orderBy('createdAt', descending: true) // Removed to avoid index error
        .snapshots()
        .map((snapshot) {
      final transactions = snapshot.docs
          .map((doc) => PointTransaction.fromFirestore(doc))
          .toList();
      
      // Client-side sorting
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    });
  }

  // 兑换奖励
  Future<UserReward?> redeemReward(String rewardId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // 1. 获取奖励详情
      final rewardDoc = await _firestore.collection('rewards').doc(rewardId).get();
      if (!rewardDoc.exists) throw Exception('Reward not found');

      final reward = Reward.fromFirestore(rewardDoc);
      
      // 2. 检查奖励是否可用
      if (!reward.isActive || reward.stock <= 0) {
        throw Exception('Reward is not available');
      }

      // 3. 获取用户积分
      final pointDoc = await _firestore
          .collection('user_points')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (pointDoc.docs.isEmpty) throw Exception('No points found');
      
      final currentBalance = pointDoc.docs.first['balance'] ?? 0;
      if (currentBalance < reward.pointCost) {
        throw Exception('Insufficient points');
      }

      // 4. 更新用户积分
      final currentTotalSpent = pointDoc.docs.first['totalSpent'] ?? 0;
      await pointDoc.docs.first.reference.update({
        'balance': currentBalance - reward.pointCost,
        'totalSpent': currentTotalSpent + reward.pointCost,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. 记录积分支出
      await _firestore.collection('point_transactions').add({
        'userId': user.uid,
        'amount': reward.pointCost,
        'type': 'spend',
        'description': 'Redeemed reward: ${reward.name}',
        'referenceId': rewardId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. 减少奖励库存
      await rewardDoc.reference.update({
        'stock': reward.stock - 1,
      });

      // 7. 创建用户奖励记录
      final voucherCode = _generateVoucherCode();
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      final userRewardRef = await _firestore.collection('user_rewards').add({
        'userId': user.uid,
        'rewardId': rewardId,
        'rewardName': reward.name,
        'pointCost': reward.pointCost,
        'rewardType': reward.type,
        'cashValue': reward.cashValue,
        'machineType': reward.machineType,
        'status': 'active',
        'voucherCode': voucherCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      // 8. 同时创建优惠券记录（与现有系统集成）
      if (reward.type == 'cash' && reward.cashValue != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('vouchers')
            .add({
              'title': 'RM${reward.cashValue!.toStringAsFixed(2)} OFF',
              'description': 'Reward voucher (from points)',
              'amount': reward.cashValue,
              'type': 'reward',
              'createdAt': FieldValue.serverTimestamp(),
              'expireAt': Timestamp.fromDate(expiresAt),
            });
      } else if (reward.type == 'free_use') {
         // Free Use Voucher - Assumed value RM6.00
         await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('vouchers')
            .add({
              'title': 'Free ${reward.machineType == 'washing' ? 'Wash' : 'Dry'}',
              'description': 'Free ${reward.machineType} reward',
              'amount': 6.0, // Hardcoded base price
              'type': 'reward',
              'createdAt': FieldValue.serverTimestamp(),
              'expireAt': Timestamp.fromDate(expiresAt),
            });       
      }

      // 获取创建的奖励记录
      final createdDoc = await userRewardRef.get();
      return UserReward.fromFirestore(createdDoc);

    } catch (e) {
      print('Error redeeming reward: $e');
      rethrow;
    }
  }

  // 生成优惠券代码
  String _generateVoucherCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code = '';
    
    for (int i = 0; i < 8; i++) {
      code += chars[(random >> (i * 3)) % chars.length];
    }
    
    return 'REW-$code';
  }

  // 获取可用奖励
  Stream<List<Reward>> getAvailableRewards() {
    return _firestore
        .collection('rewards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final rewards = snapshot.docs
          .map((doc) => Reward.fromFirestore(doc))
          .where((r) => r.stock > 0) // Client-side filtering
          .toList();
      
      // Client-side sorting
      rewards.sort((a, b) => a.pointCost.compareTo(b.pointCost));
      
      return rewards;
    });
  }

  // 获取用户已兑换的奖励
  Stream<List<UserReward>> getUserRewards() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user_rewards')
        .where('userId', isEqualTo: user.uid)
        // .orderBy('createdAt', descending: true) // Removed to avoid index error
        .snapshots()
        .map((snapshot) {
      final rewards = snapshot.docs
          .map((doc) => UserReward.fromFirestore(doc))
          .toList();
      
      // Client-side sorting
      rewards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rewards;
  
    });
  }

  // 初始化默认奖励
  Future<void> seedDefaultRewards() async {
    final rewardsSnapshot = await _firestore.collection('rewards').limit(1).get();
    if (rewardsSnapshot.docs.isNotEmpty) {
      print('Rewards already exist. Skipping seed.');
      return;
    }

    final batch = _firestore.batch();
    final rewardsRef = _firestore.collection('rewards');

    final defaultRewards = [
      {
        'name': 'RM1 Voucher',
        'description': 'RM1.00 off your next reservation',
        'pointCost': 100,
        'type': 'cash',
        'cashValue': 1.0,
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'RM2 Voucher',
        'description': 'RM2.00 off your next reservation',
        'pointCost': 200,
        'type': 'cash',
        'cashValue': 2.0,
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'RM3 Voucher',
        'description': 'RM3.00 off your next reservation',
        'pointCost': 300,
        'type': 'cash',
        'cashValue': 3.0,
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'RM4 Voucher',
        'description': 'RM4.00 off your next reservation',
        'pointCost': 400,
        'type': 'cash',
        'cashValue': 4.0,
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Free Wash',
        'description': 'One time free washing machine use',
        'pointCost': 500,
        'type': 'free_use',
        'machineType': 'washing',
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Free Dry',
        'description': 'One time free dryer machine use',
        'pointCost': 500,
        'type': 'free_use',
        'machineType': 'dryer',
        'isActive': true,
        'stock': 9999,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var reward in defaultRewards) {
      final docRef = rewardsRef.doc();
      batch.set(docRef, reward);
    }

    await batch.commit();
    print('Default rewards seeded successfully.');
  }

  // 辅助方法：删除所有奖励（仅用于测试）
  Future<void> clearAllRewards() async {
    final snapshot = await _firestore.collection('rewards').get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}