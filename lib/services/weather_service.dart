import 'dart:convert';
import 'package:http/http.dart' as http;

/// Current conditions plus a short-range forecast for one location.
///
/// [current] is the raw OpenWeather `/weather` payload. [forecast] holds the
/// raw `/forecast` list entries (3-hour slots, soonest first) and may be empty
/// if the forecast request failed — current conditions alone are still usable.
class TrailWeather {
  final Map<String, dynamic> current;
  final List<Map<String, dynamic>> forecast;
  final DateTime fetchedAt;

  const TrailWeather({
    required this.current,
    this.forecast = const [],
    required this.fetchedAt,
  });

  double? get temperatureC => _num((current['main'] as Map?)?['temp']);

  double? get feelsLikeC => _num((current['main'] as Map?)?['feels_like']);

  double? get windKmh {
    final ms = _num((current['wind'] as Map?)?['speed']);
    return ms == null ? null : ms * 3.6;
  }

  /// Short condition group, e.g. "Rain", "Clouds", "Clear". Empty if unknown.
  String get condition {
    final list = current['weather'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      return (list.first['main'] ?? '').toString();
    }
    return '';
  }

  /// Real probability of precipitation (0–100) for the next forecast slot.
  /// Null when no forecast is available.
  int? get precipChancePercent {
    if (forecast.isEmpty) return null;
    final pop = _num(forecast.first['pop']);
    return pop == null ? null : (pop * 100).round().clamp(0, 100);
  }

  static double? _num(dynamic v) => v is num ? v.toDouble() : null;
}

class WeatherService {
  final String apiKey = "89fdbfe86f3b7d07b25741ad9ca20d5a";

  static const Duration _cacheTtl = Duration(minutes: 10);

  /// Number of 3-hour forecast slots to fetch (4 → next 12 hours).
  static const int _forecastSlots = 4;

  static final Map<String, TrailWeather> _cache = {};
  static final Map<String, Future<TrailWeather>> _inFlight = {};

  /// ~1 km grid so nearby taps/trails share one cached response.
  static String _cacheKey(double lat, double lon) =>
      '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  /// Current conditions + 12h forecast, cached for 10 minutes and
  /// de-duplicated across concurrent callers (Home, Trails, Plan My Trek).
  Future<TrailWeather> getTrailWeather(double lat, double lon) {
    final key = _cacheKey(lat, lon);

    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return Future.value(cached);
    }

    return _inFlight[key] ??= _fetch(lat, lon).then((result) {
      _cache[key] = result;
      return result;
    }).whenComplete(() => _inFlight.remove(key));
  }

  Future<TrailWeather> _fetch(double lat, double lon) async {
    final results = await Future.wait([
      _getCurrent(lat, lon),
      _getForecast(lat, lon).catchError((_) => <Map<String, dynamic>>[]),
    ]);

    return TrailWeather(
      current: results[0] as Map<String, dynamic>,
      forecast: results[1] as List<Map<String, dynamic>>,
      fetchedAt: DateTime.now(),
    );
  }

  /// Raw current-conditions payload. Prefer [getTrailWeather].
  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    return (await getTrailWeather(lat, lon)).current;
  }

  Future<Map<String, dynamic>> _getCurrent(double lat, double lon) async {
    final url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load weather");
    }
  }

  Future<List<Map<String, dynamic>>> _getForecast(double lat, double lon) async {
    final url =
        "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&cnt=$_forecastSlots";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception("Failed to load forecast");
    }

    final list = (jsonDecode(response.body) as Map)['list'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
