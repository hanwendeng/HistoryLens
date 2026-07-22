// MaterialApp with theme configuration and HomeScreen entry.

import 'package:flutter/material.dart';
import 'config/constants.dart';
import 'screens/home_screen.dart';

class HistoryLensApp extends StatelessWidget {
  const HistoryLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(kitGreen),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 1,
          scrolledUnderElevation: 2,
        ),
        chipTheme: ChipThemeData(
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(kitGreen),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
