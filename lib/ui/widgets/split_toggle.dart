import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// The two split modes available when adding an expense.
///
/// - [everyone]: default, splits across all trip members (one-tap default path)
/// - [specific]: opens the member picker for selective split
enum SplitMode { everyone, specific }

/// A toggle to switch between splitting with everyone or specific members.
///
/// Active button is filled teal; inactive is outlined with teal border.
/// Uses [AnimatedContainer] for smooth visual transitions.
class SplitToggle extends StatelessWidget {
  final SplitMode current;
  final ValueChanged<SplitMode> onChanged;

  const SplitToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Everyone',
            icon: Icons.groups_rounded,
            isActive: current == SplitMode.everyone,
            onTap: () => onChanged(SplitMode.everyone),
            isLeft: true,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ToggleButton(
            label: 'Specific',
            icon: Icons.person_rounded,
            isActive: current == SplitMode.specific,
            onTap: () => onChanged(SplitMode.specific),
            isLeft: false,
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLeft;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AppColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Split Type — how the amount is divided (independent of who participates)
// ─────────────────────────────────────────────────────────────────────────────

/// How an expense's total is divided among its participants.
///
/// - [equal]: divide evenly (integer paise, remainder to first participant)
/// - [unequal]: user enters exact per-person amounts
enum SplitType { equal, unequal }

/// A toggle to switch between equal and unequal (exact-amount) splitting.
///
/// Same visual style as [SplitToggle] but controls a separate axis.
class SplitTypeToggle extends StatelessWidget {
  final SplitType current;
  final ValueChanged<SplitType> onChanged;

  const SplitTypeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Equal',
            icon: Icons.drag_handle_rounded,
            isActive: current == SplitType.equal,
            onTap: () => onChanged(SplitType.equal),
            isLeft: true,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _ToggleButton(
            label: 'Unequal',
            icon: Icons.tune_rounded,
            isActive: current == SplitType.unequal,
            onTap: () => onChanged(SplitType.unequal),
            isLeft: false,
          ),
        ),
      ],
    );
  }
}
