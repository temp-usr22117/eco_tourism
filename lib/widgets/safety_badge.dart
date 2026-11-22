import 'package:flutter/material.dart';
import 'package:eco_tourism/services/safety_service.dart';

/// Status pill (SAFE / RISKY / DANGER / UNKNOWN). Tapping it explains why.
class SafetyBadge extends StatelessWidget {
  final SafetyAssessment assessment;
  final String? placeName;
  final bool compact;

  const SafetyBadge({
    super.key,
    required this.assessment,
    this.placeName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = assessment.color;
    return Semantics(
      button: true,
      label: 'Safety ${assessment.label}. Tap for details.',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showSafetyDetails(context, assessment, placeName: placeName),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(assessment.icon, size: compact ? 13 : 15, color: color),
              const SizedBox(width: 4),
              Text(
                assessment.label,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing every factor behind a safety verdict.
Future<void> showSafetyDetails(
  BuildContext context,
  SafetyAssessment assessment, {
  String? placeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF0B1220),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final current = assessment.factors.where((f) => !f.isForecast).toList();
      final upcoming = assessment.factors.where((f) => f.isForecast).toList();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(assessment.icon, color: assessment.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why ${assessment.label}?',
                          style: TextStyle(
                            color: assessment.color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (placeName != null && placeName.isNotEmpty)
                          Text(
                            placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (assessment.factors.isEmpty)
                const _FactorRow(
                  icon: Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  text: 'No weather hazards now or in the next 12 hours.',
                ),
              if (current.isNotEmpty) ...[
                const _SectionLabel('NOW'),
                ...current.map(_factorRow),
              ],
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionLabel('NEXT 12 HOURS'),
                ...upcoming.map(_factorRow),
              ],
              const SizedBox(height: 12),
              const Text(
                'Based on live weather at the trailhead. Conditions at altitude can be '
                'colder and windier — always check with local guides.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _factorRow(SafetyFactor f) => _FactorRow(
      icon: f.level.icon,
      color: f.level.color,
      text: f.message,
    );

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );
}

class _FactorRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FactorRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      );
}
