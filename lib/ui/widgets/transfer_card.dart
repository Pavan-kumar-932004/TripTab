import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

class TransferCard extends StatelessWidget {
  final int amount;
  final String fromUser;
  final String toUser;
  final DateTime createdAt;

  const TransferCard({
    super.key,
    required this.amount,
    required this.fromUser,
    required this.toUser,
    required this.createdAt,
  });

  String _formatAmount(int paise) {
    final rupees = paise / 100;
    if (rupees == rupees.truncate()) return '₹${rupees.toStringAsFixed(0)}';
    return '₹${rupees.toStringAsFixed(2)}';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('HH:mm').format(dt);
    if (isToday) return timeStr;
    return '${DateFormat('d MMM').format(dt)}  $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(width: 4, color: Colors.blue),
              // Icon
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sync_alt_rounded, color: Colors.blue, size: 20),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAmount(amount),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.colorTextPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '$fromUser → $toUser',
                        style: GoogleFonts.inter(fontSize: 13, color: context.colorTextSecondary),
                      ),
                      SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.swap_horiz_rounded, size: 11, color: context.colorTextTertiary),
                        SizedBox(width: 3),
                        Text('Transfer', style: GoogleFonts.inter(fontSize: 11, color: context.colorTextTertiary)),
                      ]),
                    ],
                  ),
                ),
              ),
              // Time
              Padding(
                padding: EdgeInsets.only(right: 14, top: 14),
                child: Text(
                  _formatTime(createdAt),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: context.colorTextTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
