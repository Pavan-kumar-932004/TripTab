import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settlement_service.dart';
import 'expenses_provider.dart';
import 'transfers_provider.dart';
import 'cash_pools_provider.dart';
import 'database_provider.dart';

/// Provides on-demand settlement computation for a trip.
///
/// Combines expenses, their participants, transfers, and cash pools,
/// then runs the greedy debt-minimization algorithm.
///
/// This is a [FutureProvider] (not Stream) because settlement is a
/// read-only, on-demand aggregation — never a stored running balance
/// (see ARCHITECTURE.md).
final tripSettlementProvider =
    FutureProvider.family<SettlementResult, String>((ref, tripId) async {
  // Wait for all three streams to have data.
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final transfersAsync = ref.watch(tripTransfersProvider(tripId));
  final cashPoolsAsync = ref.watch(tripCashPoolsProvider(tripId));

  final expenses = expensesAsync.valueOrNull;
  final transfers = transfersAsync.valueOrNull;
  final cashPools = cashPoolsAsync.valueOrNull;

  if (expenses == null || transfers == null || cashPools == null) {
    // Streams haven't emitted yet — return empty result.
    return const SettlementResult(
      netBalances: {},
      settlements: [],
      totalSpendMinor: 0,
      totalFundedPerUser: {},
      totalSharePerUser: {},
    );
  }

  // Fetch all participants for all live expenses in this trip.
  final db = ref.read(databaseProvider);
  final participants = await db.expensesDao.getParticipantsForTrip(tripId);

  return SettlementService().computeSettlement(
    expenses: expenses,
    participants: participants,
    transfers: transfers,
    cashPools: cashPools,
  );
});
