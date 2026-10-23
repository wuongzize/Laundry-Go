import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/user_home.dart';
import 'pages/owner_home.dart';
import 'pages/laundry_status.dart';
import 'pages/booking.dart';
import 'pages/voucher.dart';
import 'pages/settings.dart';
import 'pages/laundry_machines.dart';
import 'pages/favourite_machine.dart'; // 修正为复数
import 'pages/favourite_laundry.dart'; // 修正为复数
import 'pages/reserved_machine.dart';   // 修正为复数
import 'pages/payment_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasHero',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/userHome': (context) => const UserHomePage(),
        '/ownerHome': (context) => const OwnerHomePage(),
        '/laundry': (context) => const LaundryStatusPage(),
        '/booking': (context) => const BookingPage(),
        '/settings': (context) => const SettingsPage(),
        '/favouriteMachines': (context) => const FavouriteMachinesPage(),
        '/favouriteLaundries': (context) => const FavouriteLaundriesPage(),
        '/reservedMachines': (context) => const ReservedMachinesPage(),
        // 可以为 PaymentPage 添加路由，但通常使用 onGenerateRoute 或直接 Navigator.push
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/voucher') {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            return MaterialPageRoute(
              builder: (_) => VoucherPage(userUid: currentUser.uid),
            );
          } else {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Voucher')),
                body: const Center(child: Text('Error: Not logged in')),
              ),
            );
          }
        }
        
        if (settings.name == '/laundryMachines') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('laundryId') && args.containsKey('laundryName')) {
            return MaterialPageRoute(
              builder: (_) => LaundryMachinesPage(
                laundryId: args['laundryId'],
                laundryName: args['laundryName'],
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Laundry Machines')),
                body: const Center(child: Text('Error: Missing laundry information')),
              ),
            );
          }
        }
        
        if (settings.name == '/payment') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && 
              args.containsKey('machineName') && 
              args.containsKey('laundryName') && 
              args.containsKey('reservationTime') && 
              args.containsKey('amount')) {
            return MaterialPageRoute(
              builder: (_) => PaymentPage(
                machineName: args['machineName'],
                laundryName: args['laundryName'],
                reservationTime: args['reservationTime'],
                amount: args['amount'],
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Payment')),
                body: const Center(child: Text('Error: Missing payment information')),
              ),
            );
          }
        }
        
        return null;
      },
    );
  }
}