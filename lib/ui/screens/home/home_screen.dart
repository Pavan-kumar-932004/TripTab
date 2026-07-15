import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/theme_provider.dart';
import '../../../providers/trips_provider.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';

/// Main home screen showing the user's trips list.
///
/// Reads from the local Drift DB via [allTripsProvider] — fully
/// functional offline, no loading spinners waiting for network.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure the notification persists or is recreated on app startup if a trip is active.
    ref.listen(allTripsProvider, (previous, next) {
      next.whenData((trips) {
        final activeTrips = trips.where((t) => t.status == 'active').toList();
        if (activeTrips.isNotEmpty) {
          final trip = activeTrips.first;
          ref.read(notificationServiceProvider).showTripActiveNotification(
            trip.id,
            trip.title,
          );
        }
      });
    });

    final tripsAsync = ref.watch(allTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TripTab',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/join'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(
              'Join',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              size: 22,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          SizedBox(width: 4),
        ],
      ),
      body: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return _EmptyState();
          }
          return ListView.builder(
            padding: EdgeInsets.only(top: 8, bottom: 100),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _TripCard(trip: trip);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48,
                    color: AppColors.error),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.colorTextTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_trip_fab',
        onPressed: () => context.push('/trip/create'),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

/// Empty state shown when no trips exist yet.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.luggage_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No trips yet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colorTextPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first trip or join\none with an invite code',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colorTextTertiary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => context.push('/join'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(
                'Join a Trip',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A trip card shown in the home list.
class _TripCard extends StatelessWidget {
  final dynamic trip; // Trip type from Drift

  const _TripCard({required this.trip});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.statusActive;
      case 'settled':
        return AppColors.statusSettled;
      default: // draft
        return AppColors.statusDraft;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'settled':
        return 'Settled';
      default:
        return 'Draft';
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final status = trip.status ?? 'draft';

    return Card(
      child: InkWell(
        onTap: () => context.push('/trip/${trip.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Trip icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title ?? 'Untitled Trip',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        // Status badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _statusColor(status).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(status),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          _formatDate(trip.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colorTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colorTextTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
