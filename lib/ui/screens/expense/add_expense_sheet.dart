import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/members_provider.dart';
import '../../../providers/cash_pools_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/member_picker.dart';
import '../../widgets/split_toggle.dart';

/// The notification-panel-style quick-add expense sheet.
///
/// This is the STAR of the app — designed to match the mockup exactly:
/// a white/light card-like notification appearance with:
/// - Notification-style header (app icon + trip name + "now")
/// - Amount field with clear button
/// - Reason field (ALWAYS optional, NEVER blocking capture)
/// - Split toggle (default: Everyone, per DECISIONS_AND_GOTCHAS.md #1)
/// - Animated member picker when "Specific" is selected
/// - SAVE button
///
/// On save:
/// - If "Everyone": all trip members become participants with equal shares
/// - If "Specific": only selected members
/// - Share = amount_minor / participant_count, remainder to first participant
/// - Writes via expensesDao.createExpenseWithParticipants
/// - Writes via expensesDao.createExpenseWithParticipants
class AddExpenseSheet extends ConsumerStatefulWidget {
  final String tripId;
  final Expense? expenseToEdit;
  final List<ExpenseParticipant>? participantsToEdit;

  const AddExpenseSheet({
    super.key, 
    required this.tripId,
    this.expenseToEdit,
    this.participantsToEdit,
  });

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  SplitMode _splitMode = SplitMode.everyone;
  Set<String> _selectedMemberIds = {};
  bool _isSaving = false;
  
  // 'user_<id>' or 'pool_<id>'
  String? _selectedFundedById;

  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryController.forward();

    if (widget.expenseToEdit != null) {
      _amountController.text = (widget.expenseToEdit!.amountMinor / 100).toString();
      _reasonController.text = widget.expenseToEdit!.reason ?? '';
      
      if (widget.expenseToEdit!.fundedByUser != null) {
        _selectedFundedById = 'user_${widget.expenseToEdit!.fundedByUser}';
      } else if (widget.expenseToEdit!.fundedByCashPool != null) {
        _selectedFundedById = 'pool_${widget.expenseToEdit!.fundedByCashPool}';
      }

      if (widget.participantsToEdit != null) {
        // If the number of participants doesn't match total members, it's specific
        // We will do this check in build() when members are loaded, or just assume specific for now
        // if participants < members.length.
        // For now, we set selectedMemberIds. We'll refine the toggle in build.
        _selectedMemberIds = widget.participantsToEdit!.map((p) => p.userId).toSet();
        _splitMode = SplitMode.specific; // Will adjust in build if everyone is selected
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  /// Parses the amount text as rupees and converts to paise (integer).
  int? _parseAmountToPaise() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    final amountPaise = _parseAmountToPaise();
    if (amountPaise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid amount',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Reason is ALWAYS optional — never block capture
    final reason = _reasonController.text.trim();

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      const uuid = Uuid();
      final now = DateTime.now();
      final expenseId = uuid.v4();

      // Determine participants
      final members = ref.read(tripMemberUsersProvider(widget.tripId)).value;
      if (members == null || members.isEmpty) {
        throw Exception('No trip members found');
      }

      List<String> participantIds;
      if (_splitMode == SplitMode.everyone) {
        participantIds = members.map((m) => m.id).toList();
      } else {
        if (_selectedMemberIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select at least one member',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        participantIds = _selectedMemberIds.toList();
      }

      // Calculate equal shares in paise (integer division + remainder)
      final shareBase = amountPaise ~/ participantIds.length;
      final remainder = amountPaise % participantIds.length;

      // Parse fundedBy
      String? fundedByUser;
      String? fundedByCashPool;
      if (_selectedFundedById != null) {
        if (_selectedFundedById!.startsWith('user_')) {
          fundedByUser = _selectedFundedById!.substring(5);
        } else if (_selectedFundedById!.startsWith('pool_')) {
          fundedByCashPool = _selectedFundedById!.substring(5);
        }
      } else {
        fundedByUser = currentUser?.id;
      }

      final expense = ExpensesCompanion.insert(
        id: widget.expenseToEdit?.id ?? expenseId,
        tripId: widget.tripId,
        loggedBy: widget.expenseToEdit?.loggedBy ?? currentUser?.id ?? '',
        amountMinor: amountPaise,
        paymentAt: widget.expenseToEdit?.paymentAt ?? now,
        originDeviceId: widget.expenseToEdit?.originDeviceId ?? 'local-${uuid.v4().substring(0, 8)}',
        reason: Value(reason.isEmpty ? null : reason),
        fundedByUser: Value(fundedByUser),
        fundedByCashPool: Value(fundedByCashPool),
      );

      final participants = <ExpenseParticipantsCompanion>[];
      for (var i = 0; i < participantIds.length; i++) {
        final share = shareBase + (i < remainder ? 1 : 0);
        participants.add(ExpenseParticipantsCompanion.insert(
          expenseId: widget.expenseToEdit?.id ?? expenseId,
          userId: participantIds[i],
          shareMinor: share,
        ));
      }

      if (widget.expenseToEdit != null) {
        await db.expensesDao.updateExpenseWithParticipants(expense, participants);
      } else {
        await db.expensesDao.createExpenseWithParticipants(expense, participants);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripMemberUsersProvider(widget.tripId));
    final cashPoolsAsync = ref.watch(tripCashPoolsProvider(widget.tripId));
    final currentUser = ref.watch(currentUserProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    // Auto-adjust splitMode if editing and all members were selected
    if (widget.expenseToEdit != null && membersAsync.hasValue) {
      if (_selectedMemberIds.length == membersAsync.value!.length) {
        _splitMode = SplitMode.everyone;
      }
    }
    
    // Default funded by to current user if not set
    if (_selectedFundedById == null && membersAsync.hasValue && membersAsync.value!.isNotEmpty) {
      if (currentUser != null && membersAsync.value!.any((m) => m.id == currentUser.id)) {
        _selectedFundedById = 'user_${currentUser.id}';
      } else {
        _selectedFundedById = 'user_${membersAsync.value!.first.id}';
      }
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 12 + bottomInset,
          top: 80,
        ),
        decoration: BoxDecoration(
          color: AppColors.sheetSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════════════
                // NOTIFICATION-STYLE HEADER
                // ═══════════════════════════════════════════════
                Container(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE8E8E8),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // App icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '₹',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.colorTextPrimary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // Trip name + time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'TripTab',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.sheetTextPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' 🧳 • now',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.sheetTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Trip active • Tap to add expense',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.sheetTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.sheetTextSecondary
                              .withValues(alpha: 0.6),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════════════
                // BODY
                // ═══════════════════════════════════════════════
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Amount ──────────────────────────────
                      Text(
                        'Amount (₹)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sheetTextSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sheetTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBDBDBD),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _amountController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.sheetTextSecondary,
                                  ),
                                  onPressed: () {
                                    _amountController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      SizedBox(height: 14),

                      // ── Reason (OPTIONAL — never blocks capture) ──
                      Text(
                        'Reason',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sheetTextSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: _reasonController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.sheetTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Optional',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFBDBDBD),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _reasonController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.sheetTextSecondary,
                                  ),
                                  onPressed: () {
                                    _reasonController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      SizedBox(height: 16),
                      
                      // ── Funded By ──────────────────────────────
                      Text(
                        'Funded By',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sheetTextSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      membersAsync.when(
                        data: (members) {
                          final pools = cashPoolsAsync.value ?? [];
                          
                          // Build dropdown items
                          final items = <DropdownMenuItem<String>>[];
                          
                          // Add members
                          for (final m in members) {
                            items.add(DropdownMenuItem(
                              value: 'user_${m.id}',
                              child: Text(m.id == currentUser?.id ? 'Me (${m.name})' : m.name),
                            ));
                          }
                          
                          // Add active cash pools
                          for (final p in pools) {
                            if (p.status == 'open') {
                              final holder = members.firstWhere((m) => m.id == p.heldByUser, orElse: () => members.first);
                              items.add(DropdownMenuItem(
                                value: 'pool_${p.id}',
                                child: Text('Cash Pool: ₹${p.amountMinor/100} (held by ${holder.name})'),
                              ));
                            }
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: _selectedFundedById,
                            items: items,
                            onChanged: (val) {
                              setState(() {
                                _selectedFundedById = val;
                              });
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => Text('Error loading options'),
                      ),

                      SizedBox(height: 16),

                      // ── Split ──────────────────────────────
                      Text(
                        'Split',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sheetTextSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      SplitToggle(
                        current: _splitMode,
                        onChanged: (mode) {
                          setState(() => _splitMode = mode);
                          // When switching to Specific, pre-select all
                          if (mode == SplitMode.specific) {
                            final members = ref
                                .read(tripMemberUsersProvider(widget.tripId))
                                .value;
                            if (members != null) {
                              _selectedMemberIds =
                                  members.map((m) => m.id).toSet();
                            }
                          }
                        },
                      ),

                      // ── Member picker (animated) ───────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _splitMode == SplitMode.specific
                            ? Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: membersAsync.when(
                                  data: (members) => MemberPicker(
                                    members: members
                                        .map((m) => PickerMember(
                                              id: m.id,
                                              name: m.name,
                                            ))
                                        .toList(),
                                    selectedIds: _selectedMemberIds,
                                    onChanged: (ids) {
                                      setState(
                                          () => _selectedMemberIds = ids);
                                    },
                                  ),
                                  loading: () => Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => Text(
                                    'Could not load members',
                                    style: GoogleFonts.inter(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : SizedBox.shrink(),
                      ),

                      SizedBox(height: 18),

                      // ── Save button ────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSaving ? null : _save,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Text(widget.expenseToEdit != null ? 'UPDATE' : 'SAVE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
