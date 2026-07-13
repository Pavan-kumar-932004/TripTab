import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import 'cash_pools_provider.dart';
import 'expenses_provider.dart';
import 'transfers_provider.dart';

enum TimelineEventType { expense, transfer, cashPool }

class TimelineEvent {
  final TimelineEventType type;
  final DateTime timestamp;
  final Object data; // Expense, Transfer, or CashPool

  TimelineEvent({
    required this.type,
    required this.timestamp,
    required this.data,
  });
}

/// Combines expenses, transfers, and cash pools into a single sorted timeline.
final tripTimelineProvider = Provider.family<AsyncValue<List<TimelineEvent>>, String>((ref, tripId) {
  final expensesAsync = ref.watch(tripExpensesProvider(tripId));
  final transfersAsync = ref.watch(tripTransfersProvider(tripId));
  final cashPoolsAsync = ref.watch(tripCashPoolsProvider(tripId));

  // If any are still loading and don't have data, return loading
  if (expensesAsync.isLoading || transfersAsync.isLoading || cashPoolsAsync.isLoading) {
    if (!expensesAsync.hasValue || !transfersAsync.hasValue || !cashPoolsAsync.hasValue) {
      return const AsyncValue.loading();
    }
  }

  // If any have error, return error
  if (expensesAsync.hasError) return AsyncValue.error(expensesAsync.error!, expensesAsync.stackTrace!);
  if (transfersAsync.hasError) return AsyncValue.error(transfersAsync.error!, transfersAsync.stackTrace!);
  if (cashPoolsAsync.hasError) return AsyncValue.error(cashPoolsAsync.error!, cashPoolsAsync.stackTrace!);

  final expenses = expensesAsync.value ?? [];
  final transfers = transfersAsync.value ?? [];
  final cashPools = cashPoolsAsync.value ?? [];

  final events = <TimelineEvent>[];

  for (final e in expenses) {
    events.add(TimelineEvent(type: TimelineEventType.expense, timestamp: e.paymentAt, data: e));
  }
  for (final t in transfers) {
    events.add(TimelineEvent(type: TimelineEventType.transfer, timestamp: t.paymentAt, data: t));
  }
  for (final c in cashPools) {
    events.add(TimelineEvent(type: TimelineEventType.cashPool, timestamp: c.createdAt, data: c));
  }

  // Sort descending by timestamp (newest first)
  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return AsyncValue.data(events);
});
