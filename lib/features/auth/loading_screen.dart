import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'auth_background.dart';

/// Shown at app start while a saved sign-in is checked.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/branding/memora_app_icon.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  semanticLabel: 'Memora',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Memora',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
