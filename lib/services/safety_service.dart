import 'package:flutter/material.dart';
import 'package:eco_tourism/services/weather_service.dart';

/// Overall trail safety verdict. Order matters: later = more severe
/// (except [unknown], which is handled separately).
enum SafetyLevel { safe, risky, danger, unknown }

extension SafetyLevelX on SafetyLevel {
  String get label => switch (this) {
        SafetyLevel.safe => 'SAFE',
        SafetyLevel.risky => 'RISKY',
        SafetyLevel.danger => 'DANGER',
        SafetyLevel.unknown => 'UNKNOWN',
      };

  Color get color => switch (this) {
        SafetyLevel.safe => Colors.greenAccent,
        SafetyLevel.risky => Colors.amber,
        SafetyLevel.danger => Colors.redAccent,
        SafetyLevel.unknown => Colors.blueGrey,
      };

  IconData get icon => switch (this) {
        SafetyLevel.safe => Icons.check_circle_outline,
        SafetyLevel.risky => Icons.warning_amber_rounded,
        SafetyLevel.danger => Icons.dangerous_outlined,
        SafetyLevel.unknown => Icons.help_outline,
      };

  int get _rank => switch (this) {
        SafetyLevel.unknown => -1,
        SafetyLevel.safe => 0,
        SafetyLevel.risky => 1,
        SafetyLevel.danger => 2,
      };
}

/// Category of hazard, used to avoid repeating the same hazard from both
/// current conditions and several forecast slots.
enum HazardKind { thunderstorm, rain, snow, wind, cold, heat, visibility, atmosphere }

/// One reason contributing to the verdict, e.g. "Wind gusts 65 km/h".
class SafetyFactor {
  final HazardKind kind;
  final SafetyLevel level;
  final String message;

  /// True if this comes from the forecast rather than current conditions.
  final bool isForecast;

  const SafetyFactor({
    required this.kind,
    required this.level,
    required this.message,
    this.isForecast = false,
  });

  @override
  String toString() => '${level.label}: $message';
}

class SafetyAssessment {
  final SafetyLevel level;

  /// Most severe first; current conditions before forecast at equal severity.
  final List<SafetyFactor> factors;

  const SafetyAssessment({required this.level, this.factors = const []});

  static const unknown = SafetyAssessment(
    level: SafetyLevel.unknown,
    factors: [
      SafetyFactor(
        kind: HazardKind.atmosphere,
        level: SafetyLevel.unknown,
        message: 'Live weather unavailable — check local conditions before you go',
      ),
    ],
  );

  String get label => level.label;
  Color get color => level.color;
  IconData get icon => level.icon;
  bool get isDanger => level == SafetyLevel.danger;

  /// One-line explanation suitable for a card subtitle.
  String get summary {
    if (factors.isNotEmpty) return factors.first.message;
    return 'No weather hazards expected in the next 12 h';
  }
}

/// Single source of truth for turning weather into a trail safety verdict.
///
/// Rules are evaluated over current conditions and the next 12 hours of
/// forecast. Forecast hazards more than [_fullWeightWindow] away are capped at
/// [SafetyLevel.risky] — they warrant caution and planning, not a "do not go".
///
/// Thresholds are deliberately conservative for mountain trekking but avoid
/// flagging ordinary conditions (overcast skies, cool temperatures) that the
/// old per-screen rules treated as hazards.
class SafetyService {
  SafetyService._();

  // Wind (m/s, as returned by OpenWeather with units=metric).
  static const double windRiskyMs = 10; // ~36 km/h: hard to keep balance on ridges
  static const double windDangerMs = 15; // ~54 km/h: exposed sections unsafe
  static const double gustRiskyMs = 14; // ~50 km/h
  static const double gustDangerMs = 20; // ~72 km/h

  // Apparent temperature (°C).
  static const double coldRiskyC = -5;
  static const double coldDangerC = -15; // frostbite within ~30 min on exposed skin
  static const double heatRiskyC = 35;
  static const double heatDangerC = 41; // heatstroke risk under exertion

  // Precipitation intensity (mm/h). Standard light/moderate/heavy boundaries.
  static const double rainRiskyMmH = 2.5;
  static const double rainDangerMmH = 7.6; // flash-flood / landslide risk
  static const double snowDangerMmH = 3;

  // Visibility (metres; OpenWeather caps at 10,000).
  static const int visibilityRiskyM = 1000;
  static const int visibilityDangerM = 200;

  static const Duration _horizon = Duration(hours: 12);
  static const Duration _fullWeightWindow = Duration(hours: 3);

  /// Assess a [TrailWeather]. Returns [SafetyAssessment.unknown] if null.
  static SafetyAssessment assess(TrailWeather? weather, {DateTime? now}) {
    if (weather == null) return SafetyAssessment.unknown;
    return assessRaw(
      current: weather.current,
      forecast: weather.forecast,
      now: now,
    );
  }

  /// Assess raw OpenWeather payloads. Exposed for testing.
  static SafetyAssessment assessRaw({
    required Map<String, dynamic>? current,
    List<Map<String, dynamic>> forecast = const [],
    DateTime? now,
  }) {
    if (current == null || current.isEmpty) return SafetyAssessment.unknown;
    final clock = now ?? DateTime.now();

    final byKind = <HazardKind, SafetyFactor>{};
    void keep(SafetyFactor f) {
      final existing = byKind[f.kind];
      if (existing == null || f.level._rank > existing.level._rank) {
        byKind[f.kind] = f;
      }
    }

    for (final f in _evaluate(current, precipHours: 1)) {
      keep(f);
    }

    for (final slot in forecast) {
      final dt = slot['dt'];
      if (dt is! num) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(dt.toInt() * 1000);
      final until = at.difference(clock);
      if (until > _horizon) continue;

      final when = _describeWhen(until);
      final capAtRisky = until > _fullWeightWindow;

      for (final f in _evaluate(slot, precipHours: 3)) {
        final level = capAtRisky && f.level == SafetyLevel.danger
            ? SafetyLevel.risky
            : f.level;
        keep(SafetyFactor(
          kind: f.kind,
          level: level,
          message: '${f.message} $when',
          isForecast: true,
        ));
      }
    }

    final factors = byKind.values.toList()
      ..sort((a, b) {
        final bySeverity = b.level._rank.compareTo(a.level._rank);
        if (bySeverity != 0) return bySeverity;
        if (a.isForecast != b.isForecast) return a.isForecast ? 1 : -1;
        return a.kind.index.compareTo(b.kind.index);
      });

    final level = factors.isEmpty ? SafetyLevel.safe : factors.first.level;
    return SafetyAssessment(level: level, factors: factors);
  }

  /// Applies every rule to one weather snapshot (current or forecast slot).
  static List<SafetyFactor> _evaluate(
    Map<String, dynamic> w, {
    required int precipHours,
  }) {
    final out = <SafetyFactor>[];
    void add(HazardKind kind, SafetyLevel level, String message) =>
        out.add(SafetyFactor(kind: kind, level: level, message: message));

    final weatherList = w['weather'];
    final conditionId = (weatherList is List &&
            weatherList.isNotEmpty &&
            weatherList.first is Map &&
            weatherList.first['id'] is num)
        ? (weatherList.first['id'] as num).toInt()
        : null;

    // --- Condition codes: https://openweathermap.org/weather-conditions ---
    if (conditionId != null) {
      final group = conditionId ~/ 100;
      if (group == 2) {
        add(HazardKind.thunderstorm, SafetyLevel.danger,
            'Thunderstorm — lightning risk on exposed terrain');
      } else if (group == 3) {
        add(HazardKind.rain, SafetyLevel.risky, 'Drizzle — slippery sections');
      } else if (group == 5) {
        if (conditionId == 511) {
          add(HazardKind.rain, SafetyLevel.danger, 'Freezing rain — icy trail');
        } else if (const {502, 503, 504, 522, 531}.contains(conditionId)) {
          add(HazardKind.rain, SafetyLevel.danger,
              'Heavy rain — flash-flood and landslide risk');
        } else {
          add(HazardKind.rain, SafetyLevel.risky, 'Rain — slippery, muddy trail');
        }
      } else if (group == 6) {
        if (conditionId == 602 || conditionId == 622) {
          add(HazardKind.snow, SafetyLevel.danger,
              'Heavy snow — trail may be buried');
        } else {
          add(HazardKind.snow, SafetyLevel.risky,
              'Snow — microspikes and gaiters advised');
        }
      } else if (group == 7) {
        if (conditionId == 781 || conditionId == 771) {
          add(HazardKind.atmosphere, SafetyLevel.danger,
              conditionId == 781 ? 'Tornado warning' : 'Violent squalls');
        } else if (const {751, 761, 762}.contains(conditionId)) {
          add(HazardKind.atmosphere, SafetyLevel.risky,
              'Dust, sand or ash in the air');
        }
        // Mist / fog / haze are judged by the visibility value below.
      }
    }

    // --- Precipitation intensity (may escalate a code-based verdict) ---
    final rainMmH = _perHour(w['rain'], precipHours);
    if (rainMmH != null) {
      if (rainMmH >= rainDangerMmH) {
        add(HazardKind.rain, SafetyLevel.danger,
            'Heavy rain (${rainMmH.toStringAsFixed(1)} mm/h) — flash-flood risk');
      } else if (rainMmH >= rainRiskyMmH) {
        add(HazardKind.rain, SafetyLevel.risky,
            'Steady rain (${rainMmH.toStringAsFixed(1)} mm/h)');
      }
    }
    final snowMmH = _perHour(w['snow'], precipHours);
    if (snowMmH != null && snowMmH >= snowDangerMmH) {
      add(HazardKind.snow, SafetyLevel.danger,
          'Heavy snowfall (${snowMmH.toStringAsFixed(1)} mm/h)');
    }

    // --- Wind ---
    final wind = w['wind'];
    if (wind is Map) {
      final speed = _num(wind['speed']);
      final gust = _num(wind['gust']);
      if (speed != null && speed >= windDangerMs) {
        add(HazardKind.wind, SafetyLevel.danger,
            'Strong wind ${_kmh(speed)} km/h — avoid ridges and exposed sections');
      } else if (gust != null && gust >= gustDangerMs) {
        add(HazardKind.wind, SafetyLevel.danger,
            'Wind gusts ${_kmh(gust)} km/h — avoid ridges and exposed sections');
      } else if (speed != null && speed >= windRiskyMs) {
        add(HazardKind.wind, SafetyLevel.risky, 'Windy — ${_kmh(speed)} km/h');
      } else if (gust != null && gust >= gustRiskyMs) {
        add(HazardKind.wind, SafetyLevel.risky, 'Gusty — up to ${_kmh(gust)} km/h');
      }
    }

    // --- Temperature (apparent, so wind chill counts) ---
    final main = w['main'];
    if (main is Map) {
      final feels = _num(main['feels_like']) ?? _num(main['temp']);
      if (feels != null) {
        final t = feels.round();
        if (feels <= coldDangerC) {
          add(HazardKind.cold, SafetyLevel.danger,
              'Feels like $t°C — frostbite and hypothermia risk');
        } else if (feels <= coldRiskyC) {
          add(HazardKind.cold, SafetyLevel.risky,
              'Feels like $t°C — dress for severe cold');
        } else if (feels >= heatDangerC) {
          add(HazardKind.heat, SafetyLevel.danger,
              'Feels like $t°C — heatstroke risk');
        } else if (feels >= heatRiskyC) {
          add(HazardKind.heat, SafetyLevel.risky,
              'Feels like $t°C — carry extra water, avoid midday');
        }
      }
    }

    // --- Visibility ---
    final visibility = _num(w['visibility']);
    if (visibility != null) {
      if (visibility < visibilityDangerM) {
        add(HazardKind.visibility, SafetyLevel.danger,
            'Visibility under $visibilityDangerM m — easy to lose the trail');
      } else if (visibility < visibilityRiskyM) {
        add(HazardKind.visibility, SafetyLevel.risky,
            'Low visibility (${visibility.round()} m)');
      }
    }

    return out;
  }

  /// Converts OpenWeather's `{"1h": x}` / `{"3h": x}` volume into mm/h.
  static double? _perHour(dynamic precip, int hours) {
    if (precip is! Map) return null;
    final oneHour = _num(precip['1h']);
    if (oneHour != null) return oneHour;
    final threeHour = _num(precip['3h']);
    if (threeHour != null) return threeHour / 3;
    return null;
  }

  static String _describeWhen(Duration until) {
    final hours = until.inMinutes / 60;
    if (hours <= 1) return 'within the hour';
    return 'in ~${hours.round()} h';
  }

  static double? _num(dynamic v) => v is num ? v.toDouble() : null;
  static int _kmh(double ms) => (ms * 3.6).round();
}
