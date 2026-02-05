import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart'; // ADD THIS

import '../widgets/custom_error_widget.dart';
import 'core/app_export.dart';
import 'services/mongodb_service.dart';
import 'providers/user_provider.dart'; // ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MongoDB
  try {
    final mongoService = MongoDBService();
    await mongoService.connect();
    print('✅ MongoDB initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize MongoDB: $e');
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(
      errorDetails: details,
    );
  };

  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
  ]).then((value) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐ WRAP WITH PROVIDER
    return ChangeNotifierProvider(
      create: (_) => UserProvider()..initFromCache(),
      child: Sizer(
        builder: (context, orientation, screenType) {
          return MaterialApp(
            title: 'Rentify',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child!,
              );
            },
            debugShowCheckedModeBanner: false,
            routes: AppRoutes.routes,
            initialRoute: AppRoutes.initial,
          );
        },
      ),
    );
  }
}