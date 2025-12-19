import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/match_provider.dart';
import 'ui/setup_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MatchProvider(),
      child: MaterialApp(
        title: 'Dart Master Pro',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.greenAccent,
        ),
        // Start at the Setup Screen
        home: SetupScreen(), 
      ),
    ),
  );
}