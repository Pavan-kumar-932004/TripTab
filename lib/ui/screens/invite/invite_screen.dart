import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/database_provider.dart';
import '../../theme/app_colors.dart';

/// Screen to share a trip invite via QR code, link, or 6-char code.
class InviteScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String tripName;

  const InviteScreen({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen>
    with SingleTickerProviderStateMixin {
  String? _inviteCode;
  bool _isGenerating = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _generateInvite();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateInvite() async {
    setState(() => _isGenerating = true);
    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      final code = await db.tripInvitesDao.createInvite(
        tripId: widget.tripId,
        createdBy: currentUser.id,
      );
      if (mounted) setState(() => _inviteCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create invite: $e',
                style: GoogleFonts.inter()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String get _shareLink =>
      'https://triptab.app/join/$_inviteCode';

  void _copyCode() {
    if (_inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copied!', style: GoogleFonts.inter()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareLink2() {
    if (_inviteCode == null) return;
    SharePlus.instance.share(
      ShareParams(
        text:
            'Join my trip "${widget.tripName}" on TripTab!\n\nUse code: $_inviteCode\n\nOr tap this link: $_shareLink',
        subject: 'Join ${widget.tripName} on TripTab',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invite People',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _generateInvite,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('New code', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_inviteCode == null) {
      return Center(
        child: Text('Failed to generate invite.',
            style: GoogleFonts.inter(color: context.colorTextSecondary)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        children: [
          // ── Trip label ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.tripName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Share any of the options below\nto invite someone to this trip',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.colorTextSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // ── QR Code ─────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: _shareLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF009688),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Scan with camera to join',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.colorTextTertiary,
            ),
          ),

          const SizedBox(height: 28),

          // ── 6-char Code ─────────────────────────────────────────
          Text(
            'Or share the invite code',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.colorTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: context.colorCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _inviteCode!,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: context.colorTextTertiary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Tap to copy • Valid for 7 days',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.colorTextTertiary,
            ),
          ),

          const SizedBox(height: 32),

          // ── Share button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _shareLink2,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(
                'Share Invite',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── How it works ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How joining works',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colorTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _howItWorksStep('1', 'They download TripTab & create an account'),
                _howItWorksStep('2', 'Tap the + button on the home screen'),
                _howItWorksStep('3', 'Enter the code or scan QR'),
                _howItWorksStep('4', 'Done — they\'re in the trip!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colorTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
