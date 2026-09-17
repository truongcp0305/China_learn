import 'package:flutter/material.dart';

import '../theme.dart';

/// HSK level pill, matching `.tag-accent` / `.tag-accent-2` / `.tag-neutral`.
/// Levels beyond 1-3 (out of current app scope) fall back to the neutral style.
class HskTag extends StatelessWidget {
  const HskTag(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (level) {
      case '1':
        bg = AppColors.accent100;
        fg = AppColors.accent800;
        break;
      case '2':
        bg = AppColors.accent2_100;
        fg = AppColors.accent2_800;
        break;
      default:
        bg = AppColors.neutral100;
        fg = AppColors.neutral800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(1.5)),
      child: Text(
        'HSK$level',
        style: TextStyle(fontSize: 11, letterSpacing: 0.3, color: fg, fontFamily: 'Roboto'),
      ),
    );
  }
}

/// Generic tag pill for non-HSK labels (part of speech, "Tốt"/"Khá"/"Kém"...).
class LabelTag extends StatelessWidget {
  const LabelTag(this.label, {super.key, this.tone = LabelTagTone.neutral});

  final String label;
  final LabelTagTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (tone) {
      case LabelTagTone.accent:
        bg = AppColors.accent100;
        fg = AppColors.accent800;
        break;
      case LabelTagTone.accent2:
        bg = AppColors.accent2_100;
        fg = AppColors.accent2_800;
        break;
      case LabelTagTone.neutral:
        bg = AppColors.neutral100;
        fg = AppColors.neutral800;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(1.5)),
      child: Text(label, style: TextStyle(fontSize: 11, letterSpacing: 0.3, color: fg)),
    );
  }
}

enum LabelTagTone { accent, accent2, neutral }
