import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'member_avatar.dart';
import 'member_picker.dart';

/// Per-member amount editor for unequal (exact-amount) splits.
///
/// Shows one row per participant with a ₹ text field. A validation bar
/// at the top shows assigned vs total and colour-codes green when balanced
/// or amber/red when over/under.
///
/// All amounts are in **paise** internally; displayed as rupees to the user.
class UnequalSplitEditor extends StatefulWidget {
  /// Members to show amount fields for.
  final List<PickerMember> members;

  /// Total expense amount in paise.
  final int totalPaise;

  /// Current per-member shares in paise, keyed by user ID.
  final Map<String, int> shares;

  /// Called whenever any share value changes.
  final ValueChanged<Map<String, int>> onChanged;

  /// Whether to use dark-theme styling (for QuickAddScreen).
  final bool darkMode;

  const UnequalSplitEditor({
    super.key,
    required this.members,
    required this.totalPaise,
    required this.shares,
    required this.onChanged,
    this.darkMode = false,
  });

  @override
  State<UnequalSplitEditor> createState() => _UnequalSplitEditorState();
}

class _UnequalSplitEditorState extends State<UnequalSplitEditor> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _initControllers();
  }

  void _initControllers() {
    for (final member in widget.members) {
      final existing = widget.shares[member.id] ?? 0;
      _controllers[member.id] = TextEditingController(
        text: existing > 0 ? (existing / 100).toStringAsFixed(existing % 100 == 0 ? 0 : 2) : '',
      );
    }
  }

  @override
  void didUpdateWidget(covariant UnequalSplitEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Members list changed (e.g. user toggled a member in the picker)
    final oldIds = oldWidget.members.map((m) => m.id).toSet();
    final newIds = widget.members.map((m) => m.id).toSet();

    // Remove controllers for members that are no longer present
    for (final removed in oldIds.difference(newIds)) {
      _controllers[removed]?.dispose();
      _controllers.remove(removed);
    }

    // Add controllers for newly added members
    for (final added in newIds.difference(oldIds)) {
      final existing = widget.shares[added] ?? 0;
      _controllers[added] = TextEditingController(
        text: existing > 0 ? (existing / 100).toStringAsFixed(existing % 100 == 0 ? 0 : 2) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _assignedPaise {
    int total = 0;
    for (final member in widget.members) {
      total += widget.shares[member.id] ?? 0;
    }
    return total;
  }

  void _onAmountChanged(String memberId, String text) {
    final value = double.tryParse(text.trim());
    final paise = value != null && value > 0 ? (value * 100).round() : 0;
    final updated = Map<String, int>.from(widget.shares);
    updated[memberId] = paise;
    widget.onChanged(updated);
  }

  void _distributeRemaining() {
    final remaining = widget.totalPaise - _assignedPaise;
    if (remaining <= 0) return;

    // Find members with zero or no share
    final zeroMembers = widget.members
        .where((m) => (widget.shares[m.id] ?? 0) == 0)
        .toList();

    if (zeroMembers.isEmpty) return;

    final perPerson = remaining ~/ zeroMembers.length;
    final leftover = remaining % zeroMembers.length;

    final updated = Map<String, int>.from(widget.shares);
    for (var i = 0; i < zeroMembers.length; i++) {
      final share = perPerson + (i < leftover ? 1 : 0);
      updated[zeroMembers[i].id] = share;
      _controllers[zeroMembers[i].id]?.text =
          (share / 100).toStringAsFixed(share % 100 == 0 ? 0 : 2);
    }
    widget.onChanged(updated);
  }

  void _splitEqually() {
    final count = widget.members.length;
    if (count == 0 || widget.totalPaise <= 0) return;

    final perPerson = widget.totalPaise ~/ count;
    final leftover = widget.totalPaise % count;

    final updated = <String, int>{};
    for (var i = 0; i < widget.members.length; i++) {
      final share = perPerson + (i < leftover ? 1 : 0);
      updated[widget.members[i].id] = share;
      _controllers[widget.members[i].id]?.text =
          (share / 100).toStringAsFixed(share % 100 == 0 ? 0 : 2);
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final assigned = _assignedPaise;
    final total = widget.totalPaise;
    final isBalanced = assigned == total && total > 0;
    final isOver = assigned > total;

    final textColor = widget.darkMode ? Colors.white : AppColors.sheetTextPrimary;
    final secondaryColor = widget.darkMode ? Colors.white54 : AppColors.sheetTextSecondary;
    final fieldFill = widget.darkMode
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFF5F5F5);
    final hintColor = widget.darkMode ? Colors.white24 : const Color(0xFFBDBDBD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Validation bar ──────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isBalanced
                ? AppColors.success.withValues(alpha: 0.12)
                : isOver
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBalanced
                  ? AppColors.success.withValues(alpha: 0.4)
                  : isOver
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.warning.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isBalanced
                    ? Icons.check_circle_rounded
                    : isOver
                        ? Icons.error_rounded
                        : Icons.info_rounded,
                size: 16,
                color: isBalanced
                    ? AppColors.success
                    : isOver
                        ? AppColors.error
                        : AppColors.warning,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  total > 0
                      ? '₹${(assigned / 100).toStringAsFixed(2)} / ₹${(total / 100).toStringAsFixed(2)}'
                      : 'Enter amount first',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isBalanced
                        ? AppColors.success
                        : isOver
                            ? AppColors.error
                            : AppColors.warning,
                  ),
                ),
              ),
              if (!isBalanced && total > 0 && assigned < total)
                GestureDetector(
                  onTap: _distributeRemaining,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Auto-fill',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 8),

        // ── Quick action: split equally ─────────────────────────
        if (total > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: _splitEqually,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_handle_rounded,
                      size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Split equally',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Per-member fields ──────────────────────────────────
        ...widget.members.map((member) {
          final controller = _controllers[member.id];
          return Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                if (widget.darkMode)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      member.name.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  MemberAvatar(name: member.name, size: 28),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Text(
                    member.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: controller,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: hintColor,
                      ),
                      filled: true,
                      fillColor: fieldFill,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => _onAmountChanged(member.id, val),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
