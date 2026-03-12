import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/recipe_results_screen.dart';

class SmartPantryApp extends ConsumerWidget {
  const SmartPantryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Smart Pantry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      routes: {
        DashboardScreen.routeName: (_) => const DashboardScreen(),
        RecipeResultsScreen.routeName: (_) => const RecipeResultsScreen(),
      },
      initialRoute: DashboardScreen.routeName,
    );
  }
}

