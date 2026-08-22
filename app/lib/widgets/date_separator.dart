import 'package:campfire/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The pill between two days of history. Port of `DateSeparator.tsx`.
class DateSeparator extends StatelessWidget {
  const DateSeparator({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CampfireTokens.glass,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            labelFor(date),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: CampfireTokens.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  /// `Today`, `Yesterday`, or `August 16 · Saturday`.
  static String labelFor(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (isSameDay(date, today)) return 'Today';
    if (isSameDay(date, today.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${DateFormat('MMMM d').format(date)} · ${DateFormat('EEEE').format(date)}';
  }
}

/// Same calendar day in local time — the comparison the grouping and the
/// separator both need.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
