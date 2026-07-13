import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/members_provider.dart';
import '../../theme/app_colors.dart';

/// Sheet to record giving cash to someone to hold as a pool.
class CreateCashPoolSheet extends ConsumerStatefulWidget {
  final String tripId;

  const CreateCashPoolSheet({super.key, required this.tripId});

  @override
  ConsumerState<CreateCashPoolSheet> createState() => _CreateCashPoolSheetState();
}

class _CreateCashPoolSheetState extends ConsumerState<CreateCashPoolSheet> {
  final _amountController = TextEditingController();
  String? _fromUserId;
  String? _heldByUserId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
      _showError('Please enter a valid amount');
      return;
    }
    if (_fromUserId == null || _heldByUserId == null) {
      _showError('Please select both provider and holder');
      return;
    }
    if (_fromUserId == _heldByUserId) {
      _showError('Provider and holder cannot be the same');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final uuid = const Uuid().v4();

      await db.cashPoolsDao.createCashPool(
        CashPoolsCompanion.insert(
          id: uuid,
          tripId: widget.tripId,
          fromUser: _fromUserId!,
          heldByUser: _heldByUserId!,
          amountMinor: amountPaise,
          remainingMinor: amountPaise,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to create cash pool: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripMemberUsersProvider(widget.tripId));
    final currentUser = ref.watch(currentUserProvider);
    
    // Auto-select provider as current user if null
    if (_fromUserId == null && currentUser != null && membersAsync.hasValue) {
      if (membersAsync.value!.any((m) => m.id == currentUser.id)) {
        _fromUserId = currentUser.id;
      }
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Cash Pool', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: context.colorTextPrimary)),
          SizedBox(height: 24),
          
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              filled: true,
              fillColor: context.colorSurfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: 24),
          
          membersAsync.when(
            data: (members) {
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fromUserId,
                      decoration: InputDecoration(labelText: 'Provider', filled: true, fillColor: context.colorSurfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)),
                      items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                      onChanged: (val) => setState(() => _fromUserId = val),
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded, color: context.colorTextSecondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _heldByUserId,
                      decoration: InputDecoration(labelText: 'Holder', filled: true, fillColor: context.colorSurfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none)),
                      items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                      onChanged: (val) => setState(() => _heldByUserId = val),
                    ),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _isSaving ? null : _save,
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text('Create Pool', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
