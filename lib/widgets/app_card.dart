import 'package:flutter/material.dart';

import '../theme.dart';

/// Surface-filled card matching the `.card` component in the design system.
class AppCard extends StatelessWidget {
  const AppCard({super.key, this.kicker, required this.child, this.padding});

  final String? kicker;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kicker != null) ...[
            Text(
              kicker!,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }
}
