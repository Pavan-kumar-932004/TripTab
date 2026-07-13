import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/members_provider.dart';
import '../../theme/app_colors.dart';

/// Entry point from the active-trip notification.
///
/// Launched by [QuickAddActivity] (transparent Android window).
/// Opens the bottom sheet on the first frame — no splash, no navigation.
/// After Save or dismiss, [SystemNavigator.pop()] finishes the Activity
/// and the user is returned to whatever app they were in.
class QuickAddScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String tripName;

  const QuickAddScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  bool _sheetOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted || _sheetOpened) return;
    _sheetOpened = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // No extra barrier — the Android window already dims the background
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _QuickAddSheet(
        tripId: widget.tripId,
        tripName: widget.tripName,
      ),
    );

    if (mounted) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

enum _SplitMode { everyone, specific }

class _QuickAddSheet extends ConsumerStatefulWidget {
  final String tripId;
  final String tripName;

  const _QuickAddSheet({required this.tripId, required this.tripName});

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _amountFocus = FocusNode();
  _SplitMode _splitMode = _SplitMode.everyone;
  Set<String> _selectedIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _save(List<LocalUser> members) async {
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount', style: GoogleFonts.inter()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      final amountPaise = (amount * 100).round();
      final expenseId = const Uuid().v4();
      final reason = _reasonController.text.trim();

      final participantIds = _splitMode == _SplitMode.everyone
          ? members.map((m) => m.id).toList()
          : _selectedIds.toList();

      if (participantIds.isEmpty) {
        setState(() => _saving = false);
        return;
      }

      final shareBase = amountPaise ~/ participantIds.length;
      final remainder = amountPaise % participantIds.length;

      final expense = ExpensesCompanion.insert(
        id: expenseId,
        tripId: widget.tripId,
        loggedBy: currentUser?.id ?? participantIds.first,
        fundedByUser: Value(currentUser?.id ?? participantIds.first),
        amountMinor: amountPaise,
        reason: Value(reason.isEmpty ? null : reason),
        paymentAt: DateTime.now(),
        originDeviceId: 'quick-add-notif',
      );

      final participants = <ExpenseParticipantsCompanion>[];
      for (var i = 0; i < participantIds.length; i++) {
        participants.add(ExpenseParticipantsCompanion.insert(
          expenseId: expenseId,
          userId: participantIds[i],
          shareMinor: shareBase + (i < remainder ? 1 : 0),
        ));
      }

      await db.expensesDao.createExpenseWithParticipants(expense, participants);
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripMemberUsersProvider(widget.tripId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      // Cap sheet height so it never overflows even on small screens
      constraints: BoxConstraints(maxHeight: screenH * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Scrollable content ────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset + 16),
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_long_rounded,
                                color: AppColors.primary, size: 18),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Add Expense',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                Text(widget.tripName,
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded,
                                color: Colors.white38, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // ── Amount ───────────────────────────────────
                    _label('Amount (₹)'),
                    SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: true),
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      decoration: _inputDecoration(
                        hint: '0',
                        hintSize: 26,
                        suffix: ValueListenableBuilder(
                          valueListenable: _amountController,
                          builder: (_, val, __) => val.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: 16, color: Colors.white38),
                                  onPressed: () {
                                    _amountController.clear();
                                    setState(() {});
                                  },
                                )
                              : SizedBox.shrink(),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    SizedBox(height: 12),

                    // ── Reason ───────────────────────────────────
                    _label('Reason (optional)'),
                    SizedBox(height: 6),
                    TextField(
                      controller: _reasonController,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.white),
                      textInputAction: TextInputAction.done,
                      decoration: _inputDecoration(
                          hint: 'e.g. Lunch, Taxi, Hotel'),
                    ),

                    SizedBox(height: 14),

                    // ── Split toggle ──────────────────────────────
                    _label('Split'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SplitButton(
                            label: 'Everyone',
                            icon: Icons.groups_rounded,
                            active: _splitMode == _SplitMode.everyone,
                            onTap: () => setState(
                                () => _splitMode = _SplitMode.everyone),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _SplitButton(
                            label: 'Specific',
                            icon: Icons.person_rounded,
                            active: _splitMode == _SplitMode.specific,
                            onTap: () => setState(
                                () => _splitMode = _SplitMode.specific),
                          ),
                        ),
                      ],
                    ),

                    // ── Member picker ─────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _splitMode == _SplitMode.specific
                          ? membersAsync.when(
                              data: (members) => Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _label('Select members'),
                                    SizedBox(height: 6),
                                    ...members.map((m) {
                                      final sel = _selectedIds.contains(m.id);
                                      return InkWell(
                                        onTap: () => setState(() => sel
                                            ? _selectedIds.remove(m.id)
                                            : _selectedIds.add(m.id)),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 2),
                                          child: Row(children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              child: Text(
                                                m.name
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: AppColors.primary),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                                child: Text(m.name,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: Colors.white))),
                                            Checkbox(
                                              value: sel,
                                              onChanged: (_) =>
                                                  setState(() => sel
                                                      ? _selectedIds.remove(m.id)
                                                      : _selectedIds.add(m.id)),
                                              activeColor: AppColors.primary,
                                              checkColor: Colors.white,
                                              side: BorderSide(
                                                  color: Colors.white38),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                            ),
                                          ]),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              loading: () => SizedBox.shrink(),
                              error: (_, __) => SizedBox.shrink(),
                            )
                          : SizedBox.shrink(),
                    ),

                    SizedBox(height: 20),

                    // ── Save button ───────────────────────────────
                    membersAsync.when(
                      data: (members) => SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => _save(members),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : Text('SAVE',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                        ),
                      ),
                      loading: () => SizedBox(
                        height: 50,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      ),
                      error: (_, __) => SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 0.5),
      );

  InputDecoration _inputDecoration({
    required String hint,
    double hintSize = 14,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: hintSize, color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SplitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SplitButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: active ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white54),
            SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }
}
