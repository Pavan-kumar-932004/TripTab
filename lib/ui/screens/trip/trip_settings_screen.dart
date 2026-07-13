import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/members_provider.dart';
import '../../../providers/trips_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/member_avatar.dart';
import '../../../services/notification_service.dart';

/// Screen for managing a trip after creation.
class TripSettingsScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripSettingsScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripSettingsScreen> createState() => _TripSettingsScreenState();
}

class _TripSettingsScreenState extends ConsumerState<TripSettingsScreen> {
  final _titleController = TextEditingController();
  final _memberController = TextEditingController();
  bool _isSavingTitle = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  Future<void> _updateTitle() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSavingTitle = true);
    final db = ref.read(databaseProvider);
    try {
      await db.tripsDao.updateTrip(
        widget.tripId,
        TripsCompanion(
          title: Value(title),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title updated')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTitle = false);
    }
  }

  Future<void> _addMember() async {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    const uuid = Uuid();
    final memberId = uuid.v4();

    try {
      await db.into(db.users).insert(
        UsersCompanion.insert(id: memberId, name: name),
      );
      await db.into(db.tripMembers).insert(
        TripMembersCompanion.insert(
          tripId: widget.tripId,
          userId: memberId,
        ),
      );
      _memberController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add member: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    
    TripsCompanion companion;
    if (newStatus == 'active') {
      companion = TripsCompanion(
        status: Value(newStatus),
        startedAt: Value(now), // we might not want to overwrite if already started, but simple for now
        updatedAt: Value(now),
      );
    } else if (newStatus == 'settled') {
      companion = TripsCompanion(
        status: Value(newStatus),
        endedAt: Value(now),
        updatedAt: Value(now),
      );
    } else {
      companion = TripsCompanion(
        status: Value(newStatus),
        updatedAt: Value(now),
      );
    }

    await db.tripsDao.updateTrip(widget.tripId, companion);
    
    if (newStatus == 'active') {
      final latestTrip = await db.tripsDao.getTrip(widget.tripId);
      if (latestTrip != null) {
        ref.read(notificationServiceProvider).showTripActiveNotification(
          latestTrip.id,
          latestTrip.title,
        );
      }
    } else if (newStatus == 'settled') {
      ref.read(notificationServiceProvider).hideTripActiveNotification();
    }
  }

  Future<void> _deleteTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colorSurface,
        title: Text('Delete Trip?', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text('This cannot be undone. All expenses will be hidden.', style: GoogleFonts.inter(color: context.colorTextSecondary)),
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

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await db.tripsDao.softDeleteTrip(widget.tripId);
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));
    final membersAsync = ref.watch(tripMemberUsersProvider(widget.tripId));
    final memberRolesAsync = ref.watch(tripMembersProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: tripAsync.when(
        data: (trip) {
          if (trip == null) return const Center(child: Text('Trip not found'));
          
          // Pre-fill controller once
          if (_titleController.text.isEmpty && !_isSavingTitle) {
            _titleController.text = trip.title;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Section ─────────────────────────────────────
                Text('Status', style: GoogleFonts.inter(fontSize: 14, color: context.colorTextSecondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trip.status == 'active' ? Icons.timer_outlined : 
                        trip.status == 'settled' ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                        color: trip.status == 'active' ? AppColors.primary : 
                               trip.status == 'settled' ? Colors.green : context.colorTextTertiary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trip.status == 'active' ? 'Active Trip' : 
                          trip.status == 'settled' ? 'Settled Trip' : 'Draft Trip',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (trip.status == 'draft')
                        ElevatedButton(
                          onPressed: () => _changeStatus('active'),
                          child: Text('Start'),
                        ),
                      if (trip.status == 'active')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                          onPressed: () => _changeStatus('settled'),
                          child: Text('Settle', style: TextStyle(color: Colors.white)),
                        ),
                      if (trip.status == 'settled')
                        TextButton(
                          onPressed: () => _changeStatus('active'),
                          child: Text('Reopen'),
                        ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),

                // ── Details Section ────────────────────────────────────
                Text('Details', style: GoogleFonts.inter(fontSize: 14, color: context.colorTextSecondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: GoogleFonts.inter(),
                        decoration: InputDecoration(
                          hintText: 'Trip Title',
                          filled: true,
                          fillColor: context.colorSurfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSavingTitle ? null : _updateTitle,
                      child: _isSavingTitle ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
                    ),
                  ],
                ),

                SizedBox(height: 32),
                Divider(color: context.colorDivider),
                SizedBox(height: 32),

                // ── Members Section ────────────────────────────────────
                Row(
                  children: [
                    Text('Members', style: GoogleFonts.inter(fontSize: 14, color: context.colorTextSecondary, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push(
                        '/trip/${widget.tripId}/invite?name=${Uri.encodeComponent(trip.title)}',
                      ),
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: Text('Invite', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                membersAsync.when(
                  data: (users) {
                    final roles = memberRolesAsync.value ?? [];
                    final roleMap = {for (final r in roles) r.userId: r.role};
                    
                    return Column(
                      children: [
                        ...users.map((user) {
                          final role = roleMap[user.id] ?? 'member';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: MemberAvatar(name: user.name, size: 40),
                            title: Text(user.name, style: GoogleFonts.inter(color: context.colorTextPrimary)),
                            subtitle: (user.upiVpa != null || user.phoneNumber != null)
                                ? Text(
                                    [if (user.upiVpa != null) 'UPI: ${user.upiVpa}', if (user.phoneNumber != null) 'Phone: ${user.phoneNumber}'].join(' • '),
                                    style: GoogleFonts.inter(fontSize: 12, color: context.colorTextSecondary),
                                  )
                                : null,
                            trailing: role == 'owner' ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Owner', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ) : null,
                            onTap: () async {
                              final upiController = TextEditingController(text: user.upiVpa);
                              final phoneController = TextEditingController(text: user.phoneNumber);
                              
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: context.colorSurface,
                                  title: Text('Edit ${user.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: upiController,
                                        decoration: InputDecoration(labelText: 'UPI VPA (Optional)'),
                                      ),
                                      SizedBox(height: 12),
                                      TextField(
                                        controller: phoneController,
                                        decoration: InputDecoration(labelText: 'Phone Number (Optional)'),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save')),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final db = ref.read(databaseProvider);
                                await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
                                  UsersCompanion(
                                    upiVpa: Value(upiController.text.trim().isEmpty ? null : upiController.text.trim()),
                                    phoneNumber: Value(phoneController.text.trim().isEmpty ? null : phoneController.text.trim()),
                                  ),
                                );
                              }
                            },
                          );
                        }),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _memberController,
                                style: GoogleFonts.inter(),
                                decoration: InputDecoration(
                                  hintText: 'New member name',
                                  filled: true,
                                  fillColor: context.colorSurfaceVariant,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                                ),
                                onSubmitted: (_) => _addMember(),
                              ),
                            ),
                            SizedBox(width: 12),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: _addMember,
                              icon: Icon(Icons.add_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),

                SizedBox(height: 48),
                
                // ── Danger Zone ──────────────────────────────────────
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: _deleteTrip,
                    icon: Icon(Icons.delete_outline_rounded),
                    label: Text('Delete Trip', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 48),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
