import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/settlement_provider.dart';
import '../../../providers/members_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../services/settlement_service.dart';
import '../../theme/app_colors.dart';

/// Settlement screen showing who owes whom and how much.
///
/// Uses the greedy debt-minimization algorithm to compute the minimum
/// number of transfers needed to settle all trip debts.
class SettlementScreen extends ConsumerWidget {
  final String tripId;

  const SettlementScreen({super.key, required this.tripId});

  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  String _fmt(int paise) => _currencyFormat.format(paise / 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementAsync = ref.watch(tripSettlementProvider(tripId));
    final membersAsync = ref.watch(tripMemberUsersProvider(tripId));

    // Build member ID → name map
    final memberMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        memberMap[m.id] = m.name;
      }
    }

    String nameOf(String id) => memberMap[id] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settle Up',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: settlementAsync.when(
        data: (result) => _buildContent(context, ref, result, nameOf),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to compute settlement',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: GoogleFonts.inter(fontSize: 13, color: context.colorTextTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SettlementResult result,
    String Function(String) nameOf,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary Card ──────────────────────────────────────
          _buildSummaryCard(context, result),
          const SizedBox(height: 28),

          // ── Member Balances ───────────────────────────────────
          _buildSectionHeader(context, 'Member Balances', Icons.people_alt_rounded),
          const SizedBox(height: 12),
          _buildBalanceList(context, result, nameOf),
          const SizedBox(height: 28),

          // ── Settlement Plan ───────────────────────────────────
          _buildSectionHeader(context, 'Settlement Plan', Icons.swap_horiz_rounded),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Minimum transfers to settle all debts',
              style: GoogleFonts.inter(fontSize: 13, color: context.colorTextTertiary),
            ),
          ),
          _buildSettlementCards(context, ref, result, nameOf),
        ],
      ),
    );
  }

  // ── Summary Card ────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, SettlementResult result) {
    final expenseCount = result.totalFundedPerUser.values.fold<int>(0, (a, b) => a + b);
    // expenseCount above is total funded amount, not count. Let's compute from totalSpendMinor.

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Trip Spend',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _fmt(result.totalSpendMinor),
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.totalFundedPerUser.length} member${result.totalFundedPerUser.length == 1 ? '' : 's'} contributed • ${result.settlements.length} settlement${result.settlements.length == 1 ? '' : 's'} needed',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colorTextPrimary,
          ),
        ),
      ],
    );
  }

  // ── Balance List ────────────────────────────────────────────────

  Widget _buildBalanceList(
    BuildContext context,
    SettlementResult result,
    String Function(String) nameOf,
  ) {
    final sorted = result.netBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return _emptyState(context, 'No expenses recorded yet.');
    }

    // Find max absolute balance for proportional bars
    final maxAbs = sorted.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);

    return Column(
      children: sorted.map((entry) {
        final name = nameOf(entry.key);
        final balance = entry.value;
        final isPositive = balance > 0;
        final isZero = balance.abs() < 50; // less than 0.5 paise
        final funded = result.totalFundedPerUser[entry.key] ?? 0;
        final share = result.totalSharePerUser[entry.key] ?? 0;
        final proportion = maxAbs > 0 ? entry.value.abs() / maxAbs : 0.0;

        Color balanceColor;
        String balanceText;
        if (isZero) {
          balanceColor = context.colorTextTertiary;
          balanceText = 'Settled';
        } else if (isPositive) {
          balanceColor = AppColors.success;
          balanceText = 'gets back ${_fmt(balance)}';
        } else {
          balanceColor = AppColors.error;
          balanceText = 'owes ${_fmt(balance.abs())}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorCardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colorDivider),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: (isZero
                            ? context.colorTextTertiary
                            : isPositive
                                ? AppColors.success
                                : AppColors.error)
                        .withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isZero
                            ? context.colorTextTertiary
                            : isPositive
                                ? AppColors.success
                                : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name & details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colorTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Paid ${_fmt(funded)} • Share ${_fmt(share)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colorTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Balance
                  Text(
                    balanceText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
              if (!isZero) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: proportion,
                    minHeight: 4,
                    backgroundColor: context.colorSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation(balanceColor.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Settlement Cards ────────────────────────────────────────────

  Widget _buildSettlementCards(
    BuildContext context,
    WidgetRef ref,
    SettlementResult result,
    String Function(String) nameOf,
  ) {
    if (result.settlements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'All Settled!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No payments needed — everyone is square.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colorTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: result.settlements.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final instruction = mapEntry.value;
        final fromName = nameOf(instruction.fromUserId);
        final toName = nameOf(instruction.toUserId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.colorCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorDivider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    // Settlement number badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Transfer ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmt(instruction.amountMinor),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.colorTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // From → To row
                    Row(
                      children: [
                        // From
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.error.withValues(alpha: 0.12),
                                child: Text(
                                  fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fromName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colorTextPrimary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'pays',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.colorTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Arrow
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),

                        // To
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                                child: Text(
                                  toName.isNotEmpty ? toName[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                toName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: context.colorTextPrimary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'receives',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.colorTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Record Payment button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.colorDivider)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _recordSettlement(context, ref, instruction),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Record Payment',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _recordSettlement(
    BuildContext context,
    WidgetRef ref,
    SettlementInstruction instruction,
  ) async {
    try {
      final db = ref.read(databaseProvider);
      await db.transfersDao.createTransfer(
        TransfersCompanion.insert(
          id: const Uuid().v4(),
          tripId: tripId,
          fromUser: instruction.fromUserId,
          toUser: instruction.toUserId,
          amountMinor: instruction.amountMinor,
          type: 'settlement',
          paymentAt: DateTime.now(),
          originDeviceId: 'local',
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment recorded!', style: GoogleFonts.inter()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Invalidate settlement to recompute
        ref.invalidate(tripSettlementProvider(tripId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _emptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 14, color: context.colorTextTertiary),
      ),
    );
  }
}
