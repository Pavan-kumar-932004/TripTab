import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/members_provider.dart';
import '../../../providers/timeline_provider.dart';
import '../../../providers/trips_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cash_pool_card.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/transfer_card.dart';
import '../cash_pool/create_cash_pool_sheet.dart';
import '../expense/add_expense_sheet.dart';
import '../transfer/add_transfer_sheet.dart';
import '../../../services/notification_service.dart';

/// Detail screen for a specific trip.
///
/// Shows a chronological timeline of expenses, transfers, and cash pools.
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> with WidgetsBindingObserver {
  
  /// Channel that MainActivity calls when QuickAddActivity finishes.
  /// Only registered on Android — on iOS this is a no-op.
  static const _refreshChannel = MethodChannel('triptab/refresh');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _refreshChannel.setMethodCallHandler(_onNativeRefresh);
    }
  }

  /// Called by native when QuickAddActivity finishes writing to SQLite.
  /// Immediately invalidates providers — no WAL delay needed because
  /// the native side sends this AFTER the write is complete.
  Future<dynamic> _onNativeRefresh(MethodCall call) async {
    if (call.method == 'onExpenseAdded') {
      if (!mounted) return;
      // Small tick to let SQLite's page cache flush.
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      ref.invalidate(tripTimelineProvider(widget.tripId));
      ref.invalidate(tripByIdProvider(widget.tripId));
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _refreshChannel.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The QuickAdd overlay runs in a separate Flutter engine, so its
      // database writes won't automatically trigger this engine's Drift
      // streams.  Give the SQLite WAL a moment to checkpoint, then
      // invalidate all providers to force a fresh read.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        ref.invalidate(tripTimelineProvider(widget.tripId));
        ref.invalidate(tripByIdProvider(widget.tripId));
        ref.invalidate(tripMemberUsersProvider(widget.tripId));
      });
    }
  }

  void _openAddExpense(BuildContext context, [Expense? expenseToEdit, List<ExpenseParticipant>? participants]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        tripId: widget.tripId,
        expenseToEdit: expenseToEdit,
        participantsToEdit: participants,
      ),
    );
  }

  void _openAddTransfer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransferSheet(tripId: widget.tripId),
    );
  }

  void _openCreateCashPool(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateCashPoolSheet(tripId: widget.tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(tripTimelineProvider(widget.tripId));
    final membersAsync = ref.watch(tripMemberUsersProvider(widget.tripId));
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));

    // Build a member-ID → name map for resolving payer UUIDs.
    final memberMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        memberMap[m.id] = m.name;
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: context.colorBackground,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Text(
                tripAsync.when(
                  data: (trip) => trip?.title ?? 'Trip',
                  loading: () => 'Loading...',
                  error: (_, __) => 'Trip',
                ),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: context.colorTextPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      context.colorBackground,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Member avatars row ────────────────────────────────
          SliverToBoxAdapter(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) return SizedBox.shrink();
                return Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Members',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${members.length}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            return Tooltip(
                              message: members[i].name,
                              child: MemberAvatar(
                                name: members[i].name,
                                size: 42,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                      Divider(color: context.colorDivider),
                    ],
                  ),
                );
              },
              loading: () => SizedBox.shrink(),
              error: (_, __) => SizedBox.shrink(),
            ),
          ),

          // ── Trip duration indicator ────────────────────────────
          SliverToBoxAdapter(
            child: tripAsync.when(
              data: (trip) {
                if (trip == null) return SizedBox.shrink();
                String durationText;
                IconData durationIcon;
                Color durationColor;
                switch (trip.status) {
                  case 'active':
                    final days = trip.startedAt != null
                        ? DateTime.now().difference(trip.startedAt!).inDays
                        : 0;
                    durationText = 'Active for $days day${days == 1 ? '' : 's'}';
                    durationIcon = Icons.timer_outlined;
                    durationColor = AppColors.primary;
                    break;
                  case 'settled':
                    durationText = 'Settled';
                    durationIcon = Icons.check_circle_rounded;
                    durationColor = Colors.green;
                    break;
                  default: // draft
                    durationText = 'Not started';
                    durationIcon = Icons.edit_note_rounded;
                    durationColor = context.colorTextTertiary;
                }
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(durationIcon, size: 14, color: durationColor),
                      SizedBox(width: 6),
                      Text(
                        durationText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: durationColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => SizedBox.shrink(),
              error: (_, __) => SizedBox.shrink(),
            ),
          ),

          // ── Expenses header ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Timeline',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colorTextSecondary,
                ),
              ),
            ),
          ),

          // ── Timeline list ─────────────────────────────────────
          timelineAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 56,
                            color:
                                context.colorTextTertiary.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No activity yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.colorTextSecondary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap + to log an expense.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colorTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = events[index];
                    
                    switch (event.type) {
                      case TimelineEventType.expense:
                        final expense = event.data as Expense;
                        return Dismissible(
                          key: Key('expense-${expense.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            color: AppColors.error,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: context.colorSurface,
                                title: Text('Delete Expense?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                content: Text('Are you sure you want to delete this expense?', style: GoogleFonts.inter()),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                    onPressed: () => Navigator.pop(ctx, true), 
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) {
                            final db = ref.read(databaseProvider);
                            db.expensesDao.softDeleteExpense(expense.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Expense deleted', style: GoogleFonts.inter()),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    (db.update(db.expenses)..where((e) => e.id.equals(expense.id)))
                                      .write(const ExpensesCompanion(deletedAt: Value(null)));
                                  },
                                ),
                              ),
                            );
                          },
                          child: GestureDetector(
                            onTap: () async {
                              final db = ref.read(databaseProvider);
                              final participants = await db.expensesDao.watchParticipantsForExpense(expense.id).first;
                              if (context.mounted) {
                                _openAddExpense(context, expense, participants);
                              }
                            },
                            child: ExpenseCard(
                              amount: expense.amountMinor,
                              reason: expense.reason,
                              paidBy: memberMap[expense.fundedByUser] ?? 'Someone',
                              createdAt: expense.entryAt,
                            ),
                          ),
                        );
                      case TimelineEventType.transfer:
                        final transfer = event.data as Transfer;
                        return TransferCard(
                          amount: transfer.amountMinor,
                          fromUser: memberMap[transfer.fromUser] ?? 'Someone',
                          toUser: memberMap[transfer.toUser] ?? 'Someone',
                          createdAt: transfer.createdAt,
                        );
                      case TimelineEventType.cashPool:
                        final pool = event.data as CashPool;
                        return CashPoolCard(
                          amount: pool.amountMinor,
                          fromUser: memberMap[pool.fromUser] ?? 'Someone',
                          heldByUser: memberMap[pool.heldByUser] ?? 'Someone',
                          createdAt: pool.createdAt,
                        );
                    }
                  },
                  childCount: events.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  'Error: $err',
                  style: GoogleFonts.inter(color: context.colorTextTertiary),
                ),
              ),
            ),
          ),

          // ── Bottom padding ────────────────────────────────────
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),

      // ── Bottom action row ───────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colorSurface,
          border: Border(
            top: BorderSide(color: context.colorDivider),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => context.push('/trip/${widget.tripId}/settings'),
                icon: Icon(Icons.settings_rounded, size: 18),
                label: Text(
                  'Manage',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => context.push('/trip/${widget.tripId}/settlement'),
                icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                label: Text(
                  'Settle Up',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              tripAsync.when(
                data: (trip) {
                  if (trip == null) return SizedBox.shrink();
                  
                  final isActive = trip.status == 'active';
                  final isDraft = trip.status == 'draft';
                  
                  if (trip.status == 'settled') {
                    return Text(
                      'Trip Settled',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.success),
                    );
                  }

                  return TextButton.icon(
                    onPressed: () async {
                      if (isDraft) {
                        final db = ref.read(databaseProvider);
                        await db.tripsDao.updateTrip(widget.tripId, TripsCompanion(
                          status: const Value('active'),
                          startedAt: Value(DateTime.now()),
                          updatedAt: Value(DateTime.now()),
                        ));
                        final latestTrip = await db.tripsDao.getTrip(widget.tripId);
                        if (latestTrip != null) {
                          ref.read(notificationServiceProvider).showTripActiveNotification(
                            latestTrip.id,
                            latestTrip.title,
                          );
                        }
                      } else if (isActive) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: context.colorSurface,
                            title: Text('Settle Trip?', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.colorTextPrimary)),
                            content: Text('Mark this trip as settled. You can reopen it later from settings.', style: GoogleFonts.inter(color: context.colorTextSecondary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter())),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Settle', style: GoogleFonts.inter())),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final db = ref.read(databaseProvider);
                          await db.tripsDao.updateTrip(widget.tripId, TripsCompanion(
                            status: const Value('settled'),
                            endedAt: Value(DateTime.now()),
                            updatedAt: Value(DateTime.now()),
                          ));
                          ref.read(notificationServiceProvider).hideTripActiveNotification();
                        }
                      }
                    },
                    icon: Icon(isDraft ? Icons.play_arrow_rounded : Icons.check_circle_outline_rounded, size: 18),
                    label: Text(
                      isDraft ? 'Start Trip' : 'End Trip',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  );
                },
                loading: () => SizedBox.shrink(),
                error: (_, __) => SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'expense') _openAddExpense(context);
          if (value == 'transfer') _openAddTransfer(context);
          if (value == 'cash_pool') _openCreateCashPool(context);
        },
        offset: const Offset(0, -120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'expense',
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                SizedBox(width: 12),
                Text('Add Expense', style: GoogleFonts.inter()),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'transfer',
            child: Row(
              children: [
                Icon(Icons.sync_alt_rounded, color: Colors.blue),
                SizedBox(width: 12),
                Text('Record Transfer', style: GoogleFonts.inter()),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'cash_pool',
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.purple),
                SizedBox(width: 12),
                Text('Create Cash Pool', style: GoogleFonts.inter()),
              ],
            ),
          ),
        ],
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
