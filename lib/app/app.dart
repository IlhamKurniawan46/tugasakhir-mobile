import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class HoloDexApp extends StatelessWidget {
  const HoloDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HoloDex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
