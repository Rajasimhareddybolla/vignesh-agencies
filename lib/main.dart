import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'firebase_options.dart';

import 'services/push_notification_service.dart'; // Add import
import 'services/warranty_notification_service.dart'; // Warranty notifications
import 'services/cart_service.dart';
import 'services/order_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check to prevent upload delays
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  // Initialize Push Notifications
  final pushService = PushNotificationService();
  // We don't await this strictly to avoid blocking UI, or we can.
  // Often better to fire and forget or await if critical.
  await pushService.initialize();

  // Initialize Warranty Notification Service (for local scheduled notifications)
  await WarrantyNotificationService.initialize();

  runApp(const VigneshAgenciesApp());
}

class VigneshAgenciesApp extends StatelessWidget {
  const VigneshAgenciesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<PushNotificationService>(
          create: (_) => PushNotificationService(),
        ),
        Provider<OrderService>(create: (_) => OrderService()),
        ChangeNotifierProvider<CartService>(create: (_) => CartService()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Vignesh Agencies',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
