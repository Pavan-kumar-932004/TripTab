import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// Displays a single expense as a styled card.
///
/// [amount] is in paise (integer minor units) — displayed as ₹X.XX.
/// [reason] is nullable per the project's "never block capture" rule.
/// Includes a subtle slide-in animation on first build.
class ExpenseCard extends StatefulWidget {
  final int amount;
  final String? reason;
  final String paidBy;
  final DateTime createdAt;

  const ExpenseCard({
    super.key,
    required this.amount,
    this.reason,
    required this.paidBy,
    required this.createdAt,
  });

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAmount(int paise) {
    final rupees = paise / 100;
    if (rupees == rupees.truncate()) {
      return '₹${rupees.toStringAsFixed(0)}';
    }
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Returns exact time as HH:mm, with date if not today.
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('HH:mm').format(dt);
    if (isToday) return timeStr;
    return '${DateFormat('d MMM').format(dt)}  $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 4,
                    color: AppColors.primary,
                  ),
                  // Icon circle
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatAmount(widget.amount),
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.colorTextPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            widget.reason?.isNotEmpty == true
                                ? widget.reason!
                                : 'No description',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: widget.reason?.isNotEmpty == true
                                  ? context.colorTextSecondary
                                  : context.colorTextTertiary,
                              fontStyle: widget.reason?.isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 11, color: context.colorTextTertiary),
                              SizedBox(width: 3),
                              Text(
                                widget.paidBy,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: context.colorTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Time
                  Padding(
                    padding: EdgeInsets.only(right: 14, top: 14),
                    child: Text(
                      _formatTime(widget.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.colorTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
