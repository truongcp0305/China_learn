import 'package:flutter/material.dart';

import '../theme.dart';

/// Small uppercase-tracking section header used across detail screens
/// (word detail, grammar detail).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, letterSpacing: 1.0, color: AppColors.neutral600));
  }
}

/// A label/value row with a bottom divider, used for the "Ôn tập" metadata
/// block on detail screens.
class MetaRow extends StatelessWidget {
  const MetaRow({super.key, required this.label, this.value, this.tag});
  final String label;
  final String? value;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.neutral700)),
          tag ?? Text(value ?? '', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
