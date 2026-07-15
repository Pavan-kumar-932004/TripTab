import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/database_provider.dart';
import '../../theme/app_colors.dart';

/// Screen for creating a new trip with members.
///
/// Generates client-side UUIDs for the trip and all trip_members rows
/// (never server auto-increment), consistent with the offline-first
/// sync architecture.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _titleController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _memberNames = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    if (_memberNames.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name is already added'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() {
      _memberNames.add(name);
      _memberController.clear();
    });
  }

  void _removeMember(String name) {
    setState(() => _memberNames.remove(name));
  }

  Future<void> _createTrip() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a trip title',
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

    setState(() => _isCreating = true);

    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      const uuid = Uuid();

      final tripId = uuid.v4();

      // Create the trip — starts as 'draft'; user taps "Start Trip" to activate
      await db.into(db.trips).insert(
        TripsCompanion.insert(
          id: tripId,
          title: title,
          createdBy: currentUser?.id ?? '',
        ),
      );

      // Add the creator as admin
      if (currentUser != null) {
        await db.into(db.tripMembers).insert(
          TripMembersCompanion.insert(
            tripId: tripId,
            userId: currentUser.id,
            role: Value('admin'),
          ),
        );
      }

      // Add other members — create local user rows for each, then
      // trip_members entries linking them to this trip.
      for (final name in _memberNames) {
        final memberId = uuid.v4();

        await db.into(db.users).insert(
          UsersCompanion.insert(
            id: memberId,
            name: name,
          ),
        );

        await db.into(db.tripMembers).insert(
          TripMembersCompanion.insert(
            tripId: tripId,
            userId: memberId,
          ),
        );
      }

      // Auto-generate the first invite code so the admin can immediately
      // share the QR with others right after creation.
      final inviteCode = currentUser != null
          ? await db.tripInvitesDao.createInvite(
              tripId: tripId,
              createdBy: currentUser.id,
            )
          : null;

      if (mounted) {
        // Navigate to the invite screen (QR code) so the admin can
        // share it immediately. The invite screen routes back to the trip.
        final encodedName = Uri.encodeComponent(title);
        context.go(
          '/trip/$tripId/invite?name=$encodedName&isNewTrip=true'
          '${inviteCode != null ? '&code=$inviteCode' : ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create trip: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Trip',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Trip title ──────────────────────────────────────
            Text(
              'Trip Title',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextSecondary,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(
                  color: context.colorTextPrimary, fontSize: 15),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Goa Trip 2026',
                prefixIcon:
                    Icon(Icons.flight_rounded, color: context.colorTextTertiary),
              ),
            ),

            SizedBox(height: 24),

            // ── Your name ───────────────────────────────────────
            Text(
              'Your Name',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextSecondary,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colorSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded,
                      color: context.colorTextTertiary, size: 20),
                  SizedBox(width: 12),
                  Text(
                    currentUser?.name ?? 'You',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: context.colorTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'You',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28),

            // ── Add members ─────────────────────────────────────
            Text(
              'Add Members',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorTextSecondary,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    style: GoogleFonts.inter(
                        color: context.colorTextPrimary, fontSize: 15),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Member name',
                      prefixIcon: Icon(Icons.person_add_alt_1_rounded,
                          color: context.colorTextTertiary),
                    ),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _addMember,
                    icon: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            if (_memberNames.isNotEmpty) ...[
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _memberNames.map((name) {
                  return Chip(
                    label: Text(name),
                    onDeleted: () => _removeMember(name),
                    deleteIcon: Icon(Icons.close_rounded, size: 16),
                  );
                }).toList(),
              ),
            ],

            SizedBox(height: 40),

            // ── Create button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createTrip,
                child: _isCreating
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'Create Trip',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
