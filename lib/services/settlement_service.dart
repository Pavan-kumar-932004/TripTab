/// Pure-Dart settlement computation — no database imports.
///
/// Computes net balances per user and applies a greedy debt-minimization
/// algorithm to produce the fewest transfers needed to settle a trip.
///
/// All monetary values are `int` minor units (paise).

/// A single settlement instruction: [fromUserId] pays [toUserId] [amountMinor].
class SettlementInstruction {
  final String fromUserId;
  final String toUserId;
  final int amountMinor;

  const SettlementInstruction({
    required this.fromUserId,
    required this.toUserId,
    required this.amountMinor,
  });

  @override
  String toString() =>
      'SettlementInstruction($fromUserId → $toUserId: $amountMinor)';
}

/// Aggregated settlement result for an entire trip.
class SettlementResult {
  /// Net balance per user in paise.
  /// Positive = the group owes this user money (they over-paid).
  /// Negative = this user owes the group money (they under-paid).
  final Map<String, int> netBalances;

  /// Minimized list of transfers to settle all debts.
  final List<SettlementInstruction> settlements;

  /// Total trip spend in paise (sum of all non-deleted expense amounts).
  final int totalSpendMinor;

  /// Per-user total funded (how much each user paid for on behalf of the group).
  final Map<String, int> totalFundedPerUser;

  /// Per-user total share (how much each user owes based on their splits).
  final Map<String, int> totalSharePerUser;

  const SettlementResult({
    required this.netBalances,
    required this.settlements,
    required this.totalSpendMinor,
    required this.totalFundedPerUser,
    required this.totalSharePerUser,
  });
}

/// Stateless service that computes settlements from raw trip data.
class SettlementService {
  /// Compute the full settlement for a trip.
  ///
  /// All list items are duck-typed (use `dynamic`) so the service has
  /// zero coupling to Drift-generated classes.
  SettlementResult computeSettlement({
    required List<dynamic> expenses,
    required List<dynamic> participants,
    required List<dynamic> transfers,
    required List<dynamic> cashPools,
  }) {
    // ── 1. Build cashPoolId → fromUserId lookup ────────────────
    final poolOwner = <String, String>{};
    for (final pool in cashPools) {
      if (pool.deletedAt == null) {
        poolOwner[pool.id as String] = pool.fromUser as String;
      }
    }

    // ── 2. Build set of non-deleted expense IDs ────────────────
    final liveExpenseIds = <String>{};
    for (final exp in expenses) {
      if (exp.deletedAt == null) {
        liveExpenseIds.add(exp.id as String);
      }
    }

    // ── 3. Accumulate net balances ─────────────────────────────
    final netBalances = <String, int>{};
    final totalFunded = <String, int>{};
    final totalShare = <String, int>{};
    int totalSpend = 0;

    // 3a. Expenses — credit the funder
    for (final exp in expenses) {
      if (exp.deletedAt != null) continue;

      final amount = exp.amountMinor as int;
      totalSpend += amount;

      String? funder;
      if (exp.fundedByUser != null) {
        funder = exp.fundedByUser as String;
      } else if (exp.fundedByCashPool != null) {
        final poolId = exp.fundedByCashPool as String;
        funder = poolOwner[poolId];
      }

      if (funder != null) {
        netBalances[funder] = (netBalances[funder] ?? 0) + amount;
        totalFunded[funder] = (totalFunded[funder] ?? 0) + amount;
      }
    }

    // 3b. Participants — debit each participant their share
    for (final p in participants) {
      final expenseId = p.expenseId as String;
      if (!liveExpenseIds.contains(expenseId)) continue;

      final userId = p.userId as String;
      final share = p.shareMinor as int;
      netBalances[userId] = (netBalances[userId] ?? 0) - share;
      totalShare[userId] = (totalShare[userId] ?? 0) + share;
    }

    // 3c. Non-settlement transfers — credit sender, debit receiver
    for (final t in transfers) {
      if (t.deletedAt != null) continue;
      if ((t.type as String) == 'settlement') continue;

      final amount = t.amountMinor as int;
      final from = t.fromUser as String;
      final to = t.toUser as String;
      netBalances[from] = (netBalances[from] ?? 0) + amount;
      netBalances[to] = (netBalances[to] ?? 0) - amount;
    }

    // ── 4. Minimize debts ──────────────────────────────────────
    final settlements = _minimizeDebts(Map<String, int>.from(netBalances));

    return SettlementResult(
      netBalances: netBalances,
      settlements: settlements,
      totalSpendMinor: totalSpend,
      totalFundedPerUser: totalFunded,
      totalSharePerUser: totalShare,
    );
  }

  /// Greedy debt minimization.
  ///
  /// Produces the minimum number of peer-to-peer transfers needed
  /// to bring every user's balance to zero.
  List<SettlementInstruction> _minimizeDebts(Map<String, int> balances) {
    // Treat anything under 50 paise (₹0.50) as zero — rounding dust.
    balances.removeWhere((_, v) => v.abs() < 50);

    if (balances.isEmpty) return const [];

    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];

    for (final entry in balances.entries) {
      if (entry.value > 0) {
        creditors.add(entry);
      } else if (entry.value < 0) {
        debtors.add(entry);
      }
    }

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => a.value.compareTo(b.value));

    final creds = creditors.map((e) => [e.key, e.value]).toList();
    final debts = debtors.map((e) => [e.key, e.value]).toList();

    final instructions = <SettlementInstruction>[];

    int ci = 0;
    int di = 0;

    while (ci < creds.length && di < debts.length) {
      final creditorId = creds[ci][0] as String;
      final creditorBal = creds[ci][1] as int;
      final debtorId = debts[di][0] as String;
      final debtorBal = (debts[di][1] as int).abs();

      final transferAmount = creditorBal < debtorBal ? creditorBal : debtorBal;

      if (transferAmount >= 50) {
        instructions.add(SettlementInstruction(
          fromUserId: debts[di][0] as String,
          toUserId: creds[ci][0] as String,
          amountMinor: transferAmount,
        ));
      }

      creds[ci] = [creditorId, creditorBal - transferAmount];
      debts[di] = [debtorId, -(debtorBal - transferAmount)];

      if ((creds[ci][1] as int) < 50) ci++;
      if ((debts[di][1] as int).abs() < 50) di++;
    }

    return instructions;
  }
}
