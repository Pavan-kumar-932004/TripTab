import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'member_avatar.dart';

/// A member in the picker list.
class PickerMember {
  final String id;
  final String name;

  const PickerMember({required this.id, required this.name});
}

/// An animated, collapsible member picker with checkboxes.
///
/// Shows the selected count in the header and smoothly expands/collapses
/// the member list via [AnimatedSize].
class MemberPicker extends StatefulWidget {
  final List<PickerMember> members;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const MemberPicker({
    super.key,
    required this.members,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  State<MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<MemberPicker> {
  bool _expanded = true;

  void _toggleMember(String id) {
    final updated = Set<String>.from(widget.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  'Select members',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sheetTextPrimary,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count selected',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.sheetTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated member list
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  children: widget.members.map((member) {
                    final isSelected = widget.selectedIds.contains(member.id);
                    return _MemberRow(
                      member: member,
                      isSelected: isSelected,
                      onTap: () => _toggleMember(member.id),
                    );
                  }).toList(),
                )
              : SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final PickerMember member;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            MemberAvatar(name: member.name, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                member.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sheetTextPrimary,
                ),
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.sheetTextSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
