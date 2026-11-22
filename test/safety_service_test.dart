import 'package:flutter_test/flutter_test.dart';
import 'package:eco_tourism/services/safety_service.dart';
import 'package:eco_tourism/services/weather_service.dart';

/// Builds a minimal OpenWeather-shaped payload.
Map<String, dynamic> wx({
  int id = 800, // clear sky
  double temp = 15,
  double? feelsLike,
  double wind = 2,
  double? gust,
  int visibility = 10000,
  double? rain1h,
  double? rain3h,
  double? snow1h,
  DateTime? at,
}) {
  return {
    if (at != null) 'dt': at.millisecondsSinceEpoch ~/ 1000,
    'weather': [
      {'id': id, 'main': 'x'}
    ],
    'main': {'temp': temp, 'feels_like': feelsLike ?? temp},
    'wind': {'speed': wind, if (gust != null) 'gust': gust},
    'visibility': visibility,
    if (rain1h != null) 'rain': {'1h': rain1h},
    if (rain3h != null) 'rain': {'3h': rain3h},
    if (snow1h != null) 'snow': {'1h': snow1h},
  };
}

void main() {
  final now = DateTime(2026, 11, 22, 9);

  SafetyLevel levelOf(Map<String, dynamic> current,
          [List<Map<String, dynamic>> forecast = const []]) =>
      SafetyService.assessRaw(current: current, forecast: forecast, now: now).level;

  group('baseline', () {
    test('no weather → UNKNOWN with explanation', () {
      final a = SafetyService.assess(null);
      expect(a.level, SafetyLevel.unknown);
      expect(a.summary, contains('unavailable'));
    });

    test('clear, mild, calm → SAFE with no factors', () {
      final a = SafetyService.assessRaw(current: wx(), now: now);
      expect(a.level, SafetyLevel.safe);
      expect(a.factors, isEmpty);
    });

    test('overcast skies alone are not a hazard (old rule flagged RISKY)', () {
      expect(levelOf(wx(id: 804)), SafetyLevel.safe);
    });

    test('cool 3°C day is not DANGER (old rule: ≤5°C → DANGER)', () {
      expect(levelOf(wx(temp: 3)), SafetyLevel.safe);
    });

    test('mist with good visibility is SAFE', () {
      expect(levelOf(wx(id: 701, visibility: 4000)), SafetyLevel.safe);
    });
  });

  group('conditions', () {
    test('thunderstorm → DANGER', () {
      expect(levelOf(wx(id: 211)), SafetyLevel.danger);
    });

    test('light rain → RISKY, heavy rain code → DANGER', () {
      expect(levelOf(wx(id: 500)), SafetyLevel.risky);
      expect(levelOf(wx(id: 502)), SafetyLevel.danger);
    });

    test('rain intensity escalates a light-rain code', () {
      expect(levelOf(wx(id: 500, rain1h: 9)), SafetyLevel.danger);
    });

    test('freezing rain → DANGER', () {
      expect(levelOf(wx(id: 511)), SafetyLevel.danger);
    });

    test('light snow → RISKY, heavy snow → DANGER', () {
      expect(levelOf(wx(id: 600)), SafetyLevel.risky);
      expect(levelOf(wx(id: 602)), SafetyLevel.danger);
      expect(levelOf(wx(id: 600, snow1h: 4)), SafetyLevel.danger);
    });
  });

  group('wind, temperature, visibility', () {
    test('wind thresholds', () {
      expect(levelOf(wx(wind: 9)), SafetyLevel.safe);
      expect(levelOf(wx(wind: 11)), SafetyLevel.risky);
      expect(levelOf(wx(wind: 16)), SafetyLevel.danger);
      expect(levelOf(wx(wind: 5, gust: 21)), SafetyLevel.danger);
    });

    test('wind message reports km/h', () {
      final a = SafetyService.assessRaw(current: wx(wind: 16), now: now);
      expect(a.summary, contains('58 km/h'));
    });

    test('apparent temperature drives cold rules (wind chill)', () {
      expect(levelOf(wx(temp: 0, feelsLike: -7)), SafetyLevel.risky);
      expect(levelOf(wx(temp: -8, feelsLike: -18)), SafetyLevel.danger);
    });

    test('heat rules', () {
      expect(levelOf(wx(temp: 36)), SafetyLevel.risky);
      expect(levelOf(wx(temp: 34, feelsLike: 43)), SafetyLevel.danger);
    });

    test('visibility thresholds', () {
      expect(levelOf(wx(visibility: 800)), SafetyLevel.risky);
      expect(levelOf(wx(visibility: 150)), SafetyLevel.danger);
    });
  });

  group('forecast', () {
    test('storm within 3 h counts fully → DANGER', () {
      final a = SafetyService.assessRaw(
        current: wx(),
        forecast: [wx(id: 211, at: now.add(const Duration(hours: 2)))],
        now: now,
      );
      expect(a.level, SafetyLevel.danger);
      expect(a.factors.single.isForecast, isTrue);
      expect(a.summary, contains('in ~2 h'));
    });

    test('storm 6–12 h out is capped at RISKY', () {
      expect(
        levelOf(wx(), [wx(id: 211, at: now.add(const Duration(hours: 6)))]),
        SafetyLevel.risky,
      );
    });

    test('slots beyond 12 h are ignored', () {
      expect(
        levelOf(wx(), [wx(id: 211, at: now.add(const Duration(hours: 15)))]),
        SafetyLevel.safe,
      );
    });

    test('3h precipitation volume is converted to mm/h', () {
      // 24 mm over 3 h = 8 mm/h → heavy, within full-weight window.
      expect(
        levelOf(wx(), [wx(id: 500, rain3h: 24, at: now.add(const Duration(hours: 1)))]),
        SafetyLevel.danger,
      );
    });

    test('same hazard now and later is reported once, keeping the worse', () {
      final a = SafetyService.assessRaw(
        current: wx(id: 500),
        forecast: [
          wx(id: 500, at: now.add(const Duration(hours: 3))),
          wx(id: 502, at: now.add(const Duration(hours: 2))),
        ],
        now: now,
      );
      final rain = a.factors.where((f) => f.kind == HazardKind.rain).toList();
      expect(rain, hasLength(1));
      expect(rain.single.level, SafetyLevel.danger);
    });

    test('factors sorted most severe first, current before forecast', () {
      final a = SafetyService.assessRaw(
        current: wx(wind: 11, visibility: 150),
        forecast: [wx(id: 600, at: now.add(const Duration(hours: 5)))],
        now: now,
      );
      expect(a.factors.first.kind, HazardKind.visibility);
      expect(a.factors.first.level, SafetyLevel.danger);
      expect(a.factors.map((f) => f.level),
          [SafetyLevel.danger, SafetyLevel.risky, SafetyLevel.risky]);
      expect(a.factors.last.isForecast, isTrue);
    });
  });

  group('TrailWeather display helpers', () {
    test('precip chance comes from forecast pop', () {
      final w = TrailWeather(
        current: wx(),
        forecast: [
          {'pop': 0.42}
        ],
        fetchedAt: now,
      );
      expect(w.precipChancePercent, 42);
      expect(w.temperatureC, 15);
    });

    test('no forecast → null precip chance (not a guess)', () {
      final w = TrailWeather(current: wx(), fetchedAt: now);
      expect(w.precipChancePercent, isNull);
    });
  });
}
