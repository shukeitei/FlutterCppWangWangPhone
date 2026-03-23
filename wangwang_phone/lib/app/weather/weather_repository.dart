import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'weather_types.dart';

/// 统一封装默认天气仓库，保证桌面小组件和独立天气 App 共用同一份真实天气配置。
WeatherRepository buildDefaultWeatherRepository({
  http.Client? client,
  WeatherLocationProvider? locationProvider,
}) {
  return SevenTimerWeatherRepository(
    client: client ?? http.Client(),
    locationProvider: locationProvider ?? const DeviceWeatherLocationProvider(),
  );
}

abstract class WeatherRepository {
  const WeatherRepository();

  Future<WeatherReport> fetchWeather();

  void dispose() {}
}

abstract class WeatherLocationProvider {
  const WeatherLocationProvider();

  Future<WeatherLocationConfig> resolveLocation();
}

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherLocationException extends WeatherException {
  const WeatherLocationException(super.message);
}

class WeatherRequestException extends WeatherException {
  const WeatherRequestException(super.message);
}

class DeviceWeatherLocationProvider extends WeatherLocationProvider {
  const DeviceWeatherLocationProvider();

  /// 仅获取近似定位，并把经纬度裁成两位小数，既满足天气查询也尽量减少精确位置暴露。
  @override
  Future<WeatherLocationConfig> resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const WeatherLocationException('定位服务未开启，请先打开系统定位');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const WeatherLocationException('需要位置权限才能获取当前位置天气');
      }

      if (permission == LocationPermission.deniedForever) {
        throw const WeatherLocationException(
          '位置权限已被永久拒绝，请到系统设置里开启',
        );
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      return WeatherLocationConfig(
        latitude: _roundCoordinate(position.latitude),
        longitude: _roundCoordinate(position.longitude),
        cityName: '当前位置',
      );
    } on WeatherLocationException {
      rethrow;
    } on UnsupportedError {
      throw const WeatherLocationException('当前平台暂不支持定位天气');
    } catch (_) {
      throw const WeatherLocationException('当前位置获取失败，请稍后重试');
    }
  }
}

class SevenTimerWeatherRepository extends WeatherRepository {
  SevenTimerWeatherRepository({
    required this.client,
    required this.locationProvider,
  });

  final http.Client client;
  final WeatherLocationProvider locationProvider;

  /// 请求 7Timer 的 civil 预报，并在仓库层把 3 小时粒度聚合成页面可直接消费的模型。
  @override
  Future<WeatherReport> fetchWeather() async {
    final location = await locationProvider.resolveLocation();
    final uri = Uri.https('www.7timer.info', '/bin/api.pl', {
      'lon': location.longitude.toStringAsFixed(2),
      'lat': location.latitude.toStringAsFixed(2),
      'product': 'civil',
      'output': 'json',
      'unit': 'metric',
      'tzshift': DateTime.now().timeZoneOffset.inHours.toString(),
    });

    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherRequestException('天气接口请求失败（${response.statusCode}）');
    }

    try {
      final Map<String, dynamic> jsonMap =
          jsonDecode(response.body) as Map<String, dynamic>;
      final forecast = SevenTimerCivilForecast.fromJson(jsonMap);
      return forecast.toReport(config: location);
    } on WeatherException {
      rethrow;
    } on FormatException catch (error) {
      throw WeatherRequestException(error.message);
    } catch (_) {
      throw const WeatherRequestException('天气数据解析失败，请稍后重试');
    }
  }

  @override
  void dispose() {
    client.close();
  }
}

class SevenTimerCivilForecast {
  const SevenTimerCivilForecast({
    required this.initTime,
    required this.forecastSlots,
  });

  final DateTime initTime;
  final List<SevenTimerForecastSlot> forecastSlots;

  /// Civil 产品返回的是 3 小时预报序列，这里先做结构校验，后续再聚合成首页和详情页需要的日级数据。
  factory SevenTimerCivilForecast.fromJson(Map<String, dynamic> json) {
    final rawSeries = json['dataseries'];
    if (rawSeries is! List || rawSeries.isEmpty) {
      throw const FormatException('天气数据为空');
    }

    final initTime = _parseInitTime(json['init']);
    final parsedList = rawSeries.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('天气数据格式错误');
      }

      return _parseCivilForecastSlot(item, initTime);
    }).whereType<SevenTimerForecastSlot>().toList()
      ..sort((left, right) => left.at.compareTo(right.at));

    if (parsedList.isEmpty) {
      throw const FormatException('天气数据格式错误');
    }

    return SevenTimerCivilForecast(
      initTime: initTime,
      forecastSlots: parsedList,
    );
  }

  WeatherReport toReport({required WeatherLocationConfig config}) {
    final now = DateTime.now();
    final dailyForecasts = _aggregateDailyForecasts(forecastSlots)
        .take(7)
        .toList();
    if (dailyForecasts.isEmpty) {
      throw const FormatException('天气数据为空');
    }

    return WeatherReport(
      location: config,
      updatedAt: now,
      currentForecast: _pickCurrentSlot(forecastSlots, now),
      dailyForecasts: dailyForecasts,
    );
  }
}

SevenTimerForecastSlot? _parseCivilForecastSlot(
  Map<String, dynamic> item,
  DateTime initTime,
) {
  final timepoint = _parseIntValue(item['timepoint']);
  final temperature = _parseTemperatureValue(item['temp2m']);
  if (timepoint == null || temperature == null) {
    return null;
  }

  final wind10m = item['wind10m'] as Map<String, dynamic>?;
  return SevenTimerForecastSlot(
    at: initTime.add(Duration(hours: timepoint)),
    weatherType: SevenTimerWeatherCodeMapper.fromApiValue(
      item['weather']?.toString() ?? '',
    ),
    temperature: temperature,
    cloudCover: _parsePercentScale(item['cloudcover']),
    relativeHumidity: _parseHumidityPercent(item['rh2m']),
    windDirection: _parseWindDirection(wind10m?['direction']),
    windSpeedLevel: _parseIntValue(wind10m?['speed']),
    precipitationType: SevenTimerPrecipitationTypeParser.fromApiValue(
      item['prec_type']?.toString() ?? 'none',
    ),
    precipitationAmount: _parseIntValue(item['prec_amount']),
    liftedIndex: _parseIntValue(item['lifted_index']),
  );
}

DateTime _parseInitTime(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.length != 10) {
    return DateTime.now();
  }

  final year = int.tryParse(raw.substring(0, 4)) ?? DateTime.now().year;
  final month = int.tryParse(raw.substring(4, 6)) ?? DateTime.now().month;
  final day = int.tryParse(raw.substring(6, 8)) ?? DateTime.now().day;
  final hour = int.tryParse(raw.substring(8, 10)) ?? 0;
  return DateTime(year, month, day, hour);
}

int? _parseTemperatureValue(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed == -9999) {
    return null;
  }
  return parsed;
}

int? _parseIntValue(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed == -9999) {
    return null;
  }
  return parsed;
}

int? _parseHumidityPercent(Object? value) {
  final raw = value?.toString().replaceAll('%', '').trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  return _parseIntValue(raw);
}

int? _parsePercentScale(Object? value) {
  final parsed = _parseIntValue(value);
  if (parsed == null) {
    return null;
  }

  const mapping = {
    0: 0,
    1: 10,
    2: 20,
    3: 35,
    4: 45,
    5: 55,
    6: 65,
    7: 75,
    8: 85,
    9: 90,
  };

  return mapping[parsed] ?? parsed.clamp(0, 100);
}

String _parseWindDirection(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw == '-9999') {
    return '--';
  }
  return raw;
}

SevenTimerForecastSlot _pickCurrentSlot(
  List<SevenTimerForecastSlot> forecastSlots,
  DateTime now,
) {
  final sorted = [...forecastSlots]
    ..sort(
      (left, right) => left.at
          .difference(now)
          .abs()
          .compareTo(right.at.difference(now).abs()),
    );
  return sorted.first;
}

/// 把 3 小时预报按自然日聚合成 7 天概览，让桌面卡片和详情页保持“看一眼就懂”的信息密度。
List<SevenTimerDailyForecast> _aggregateDailyForecasts(
  List<SevenTimerForecastSlot> forecastSlots,
) {
  final grouped = <DateTime, List<SevenTimerForecastSlot>>{};
  for (final slot in forecastSlots) {
    final dayKey = DateTime(slot.at.year, slot.at.month, slot.at.day);
    grouped.putIfAbsent(dayKey, () => <SevenTimerForecastSlot>[]).add(slot);
  }

  final orderedDays = grouped.keys.toList()
    ..sort((left, right) => left.compareTo(right));

  return orderedDays.map((dayKey) {
    final daySlots = grouped[dayKey]!
      ..sort((left, right) => left.at.compareTo(right.at));
    final representative = _pickRepresentativeSlot(daySlots);
    final temperatures = daySlots.map((slot) => slot.temperature).toList()
      ..sort();

    return SevenTimerDailyForecast(
      date: dayKey,
      weatherType: representative.weatherType,
      maxTemperature: temperatures.last,
      minTemperature: temperatures.first,
      cloudCover: _averageNullableInt(daySlots.map((slot) => slot.cloudCover)),
      relativeHumidity: _averageNullableInt(
        daySlots.map((slot) => slot.relativeHumidity),
      ),
      windDirection: representative.windDirection,
      windSpeedLevel: _maxNullableInt(
        daySlots.map((slot) => slot.windSpeedLevel),
      ),
      precipitationType: _pickDailyPrecipitation(daySlots),
    );
  }).toList();
}

SevenTimerForecastSlot _pickRepresentativeSlot(
  List<SevenTimerForecastSlot> daySlots,
) {
  final daytimeSlots = daySlots
      .where((slot) => slot.at.hour >= 8 && slot.at.hour <= 20)
      .toList();
  final candidates = daytimeSlots.isNotEmpty ? daytimeSlots : [...daySlots];

  candidates.sort((left, right) {
    final weatherCompare = right.weatherType.severityRank.compareTo(
      left.weatherType.severityRank,
    );
    if (weatherCompare != 0) {
      return weatherCompare;
    }

    final precipitationCompare = right.precipitationType.severityRank
        .compareTo(left.precipitationType.severityRank);
    if (precipitationCompare != 0) {
      return precipitationCompare;
    }

    final distanceCompare = (left.at.hour - 14).abs().compareTo(
      (right.at.hour - 14).abs(),
    );
    if (distanceCompare != 0) {
      return distanceCompare;
    }

    return left.at.compareTo(right.at);
  });

  return candidates.first;
}

SevenTimerPrecipitationType _pickDailyPrecipitation(
  List<SevenTimerForecastSlot> daySlots,
) {
  final precipitationTypes = daySlots.map((slot) => slot.precipitationType)
      .toList()
    ..sort((left, right) => right.severityRank.compareTo(left.severityRank));
  return precipitationTypes.first;
}

int? _averageNullableInt(Iterable<int?> values) {
  final validValues = values.whereType<int>().toList();
  if (validValues.isEmpty) {
    return null;
  }

  final total = validValues.reduce((sum, value) => sum + value);
  return (total / validValues.length).round();
}

int? _maxNullableInt(Iterable<int?> values) {
  final validValues = values.whereType<int>().toList();
  if (validValues.isEmpty) {
    return null;
  }

  return validValues.reduce(math.max);
}

double _roundCoordinate(double value) {
  return double.parse(value.toStringAsFixed(2));
}

/// 控制天气数据加载、错误展示和详情页同步刷新，桌面和天气页共用这一份状态。
class WeatherController extends ChangeNotifier {
  WeatherController({required WeatherRepository repository})
    : _repository = repository;

  final WeatherRepository _repository;

  WeatherState _state = const WeatherState(isLoading: true);

  WeatherState get state => _state;

  Future<void> loadWeather() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final report = await _repository.fetchWeather();
      _state = WeatherState(report: report, isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _buildWeatherErrorMessage(error),
      );
    }

    notifyListeners();
  }
}

String _buildWeatherErrorMessage(Object error) {
  if (error is WeatherException) {
    return error.message;
  }
  return '天气加载失败，请稍后重试';
}
