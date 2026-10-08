import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F3FF), Color(0xFFFFF9F3)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -90,
            right: -75,
            child: _SoftCircle(size: 230, color: Color(0x1F8B6CE5)),
          ),
          const Positioned(
            bottom: -100,
            left: -80,
            child: _SoftCircle(size: 250, color: Color(0x1FF28C3A)),
          ),
          child,
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outlineColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.09),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
