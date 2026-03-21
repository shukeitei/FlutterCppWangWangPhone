import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WangWangApp());
}

class WangWangApp extends StatelessWidget {
  const WangWangApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFFF8FA3);

    return MaterialApp(
      title: '汪汪机',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'WangWang',
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F4FB),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'WangWang',
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF120B1B),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WeatherWidgetController _weatherController;

  @override
  void initState() {
    super.initState();
    _weatherController = WeatherWidgetController(
      repository: SevenTimerWeatherRepository(
        client: http.Client(),
        config: const WeatherLocationConfig(
          latitude: 22.5431,
          longitude: 114.0579,
          cityName: '深圳市',
        ),
      ),
    )..loadWeather();
  }

  @override
  void dispose() {
    _weatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = const [
      _AppIconData('微信', Icons.chat_bubble_rounded, Color(0xFF5EDC7E)),
      _AppIconData('设置', Icons.settings_rounded, Color(0xFF7D8BFF)),
      _AppIconData('天气', Icons.wb_sunny_rounded, Color(0xFFFFB65C)),
    ];

    final palette = HomePalette.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _weatherController,
                  builder: (context, _) {
                    return WeatherWidgetCard(
                      state: _weatherController.state,
                      onRefresh: _weatherController.loadWeather,
                      onOpenDetail: () {},
                    );
                  },
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: GridView.builder(
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 24,
                          childAspectRatio: 0.82,
                        ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _AppIcon(item: item);
                    },
                  ),
                ),
                FrostPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  borderRadius: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ...items.map((item) => _DockIcon(item: item)),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.iconSurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: palette.primaryText,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面天气小组件数据模型，承接7timer解析后的桌面摘要信息。
class WeatherWidgetData {
  const WeatherWidgetData({
    required this.cityName,
    required this.currentTemperatureCelsius,
    required this.highTemperatureCelsius,
    required this.lowTemperatureCelsius,
    required this.weatherType,
    required this.summary,
    required this.updatedAt,
    this.feelsLikeLabel = '体感舒适',
  });

  final String cityName;
  final int currentTemperatureCelsius;
  final int highTemperatureCelsius;
  final int lowTemperatureCelsius;
  final WeatherType weatherType;
  final String summary;
  final DateTime updatedAt;
  final String feelsLikeLabel;

  String updatedLabel(DateTime now) {
    final minutes = now.difference(updatedAt).inMinutes;
    if (minutes <= 0) {
      return '刚刚更新';
    }
    if (minutes < 60) {
      return '$minutes分钟前';
    }
    final hours = now.difference(updatedAt).inHours;
    return '$hours小时前';
  }
}

enum WeatherType { sunny, cloudy, partlyCloudy, rainy, snowy, thunder }

extension WeatherTypePresentation on WeatherType {
  String get label {
    return switch (this) {
      WeatherType.sunny => '晴朗',
      WeatherType.cloudy => '阴天',
      WeatherType.partlyCloudy => '多云',
      WeatherType.rainy => '下雨',
      WeatherType.snowy => '下雪',
      WeatherType.thunder => '雷暴',
    };
  }

  IconData get icon {
    return switch (this) {
      WeatherType.sunny => Icons.wb_sunny_rounded,
      WeatherType.cloudy => Icons.cloud_rounded,
      WeatherType.partlyCloudy => Icons.cloud_queue_rounded,
      WeatherType.rainy => Icons.umbrella_rounded,
      WeatherType.snowy => Icons.ac_unit_rounded,
      WeatherType.thunder => Icons.thunderstorm_rounded,
    };
  }

  List<Color> colorsFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (this) {
      WeatherType.sunny =>
        isDark
            ? const [Color(0xFFFFB457), Color(0xFFFF8F6B)]
            : const [Color(0xFFFFD978), Color(0xFFFFB36A)],
      WeatherType.cloudy =>
        isDark
            ? const [Color(0xFF7C8AA5), Color(0xFF5B647A)]
            : const [Color(0xFFC5D1E2), Color(0xFFAAB8CD)],
      WeatherType.partlyCloudy =>
        isDark
            ? const [Color(0xFF8C8AF7), Color(0xFFFF9D7A)]
            : const [Color(0xFFA7B6FF), Color(0xFFFFC49B)],
      WeatherType.rainy =>
        isDark
            ? const [Color(0xFF58A6FF), Color(0xFF4361EE)]
            : const [Color(0xFF86C5FF), Color(0xFF6F92FF)],
      WeatherType.snowy =>
        isDark
            ? const [Color(0xFF9DD7FF), Color(0xFF7AB6E6)]
            : const [Color(0xFFD5EEFF), Color(0xFFB9DAFF)],
      WeatherType.thunder =>
        isDark
            ? const [Color(0xFF8E7CFF), Color(0xFF5A45D6)]
            : const [Color(0xFFC1B5FF), Color(0xFF8E7DFF)],
    };
  }
}

class WeatherWidgetState {
  const WeatherWidgetState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
  });

  final WeatherWidgetData? data;
  final bool isLoading;
  final String? errorMessage;

  WeatherWidgetState copyWith({
    WeatherWidgetData? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WeatherWidgetState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class WeatherLocationConfig {
  const WeatherLocationConfig({
    required this.latitude,
    required this.longitude,
    required this.cityName,
  });

  final double latitude;
  final double longitude;
  final String cityName;
}

abstract class WeatherRepository {
  const WeatherRepository();

  Future<WeatherWidgetData> fetchWeather();
}

class SevenTimerWeatherRepository extends WeatherRepository {
  const SevenTimerWeatherRepository({
    required this.client,
    required this.config,
  });

  final http.Client client;
  final WeatherLocationConfig config;

  @override
  Future<WeatherWidgetData> fetchWeather() async {
    final uri = Uri.parse('http://www.7timer.info/bin/api.php').replace(
      queryParameters: {
        'lon': config.longitude.toString(),
        'lat': config.latitude.toString(),
        'product': 'civillight',
        'output': 'json',
      },
    );

    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('天气接口请求失败');
    }

    final Map<String, dynamic> jsonMap =
        jsonDecode(response.body) as Map<String, dynamic>;
    final forecast = SevenTimerForecast.fromJson(jsonMap);
    return forecast.toWidgetData(cityName: config.cityName);
  }
}

class SevenTimerForecast {
  const SevenTimerForecast({required this.dailyForecasts});

  final List<SevenTimerDailyForecast> dailyForecasts;

  factory SevenTimerForecast.fromJson(Map<String, dynamic> json) {
    final rawSeries = json['dataseries'];
    if (rawSeries is! List || rawSeries.isEmpty) {
      throw const FormatException('天气数据为空');
    }

    final parsedList = rawSeries
        .whereType<Map<String, dynamic>>()
        .map(SevenTimerDailyForecast.fromJson)
        .toList();

    if (parsedList.isEmpty) {
      throw const FormatException('天气数据格式错误');
    }

    return SevenTimerForecast(dailyForecasts: parsedList);
  }

  WeatherWidgetData toWidgetData({required String cityName}) {
    final today = dailyForecasts.first;
    return WeatherWidgetData(
      cityName: cityName,
      currentTemperatureCelsius: today.averageTemperature,
      highTemperatureCelsius: today.maxTemperature,
      lowTemperatureCelsius: today.minTemperature,
      weatherType: today.weatherType.toWidgetWeatherType(),
      summary: today.buildSummary(),
      updatedAt: DateTime.now(),
      feelsLikeLabel: '湿度${today.humidityLabel}',
    );
  }
}

class SevenTimerDailyForecast {
  const SevenTimerDailyForecast({
    required this.date,
    required this.weatherType,
    required this.maxTemperature,
    required this.minTemperature,
    required this.cloudCover,
    required this.relativeHumidity,
    required this.windDirection,
    required this.windSpeedLevel,
    required this.precipitationType,
  });

  final DateTime date;
  final SevenTimerWeatherCode weatherType;
  final int maxTemperature;
  final int minTemperature;
  final int? cloudCover;
  final int? relativeHumidity;
  final String windDirection;
  final int? windSpeedLevel;
  final SevenTimerPrecipitationType precipitationType;

  int get averageTemperature => ((maxTemperature + minTemperature) / 2).round();

  String get humidityLabel =>
      relativeHumidity == null ? '--' : '$relativeHumidity%';

  factory SevenTimerDailyForecast.fromJson(Map<String, dynamic> json) {
    return SevenTimerDailyForecast(
      date: _parseForecastDate(json['date']),
      weatherType: SevenTimerWeatherCodeMapper.fromApiValue(
        json['weather']?.toString() ?? '',
      ),
      maxTemperature: _parseTemperatureValue(json['temp2m_max']),
      minTemperature: _parseTemperatureValue(json['temp2m_min']),
      cloudCover: _parsePercentScale(json['cloudcover']),
      relativeHumidity: _parsePercentScale(json['rh2m']),
      windDirection:
          (json['wind10m'] as Map<String, dynamic>?)?['direction']
              ?.toString() ??
          '--',
      windSpeedLevel: _parseIntValue(
        (json['wind10m'] as Map<String, dynamic>?)?['speed'],
      ),
      precipitationType: SevenTimerPrecipitationTypeParser.fromApiValue(
        (json['prec_type'] ?? json['precipitation']?['type'])?.toString() ??
            'none',
      ),
    );
  }

  String buildSummary() {
    final parts = <String>[
      _buildCloudLabel(),
      '风向$windDirection',
      _buildWindSpeedLabel(),
      precipitationType.label,
    ];

    return parts.where((item) => item.isNotEmpty).join(' · ');
  }

  String _buildCloudLabel() {
    if (cloudCover == null) {
      return weatherType.label;
    }
    return '云量$cloudCover%';
  }

  String _buildWindSpeedLabel() {
    if (windSpeedLevel == null) {
      return '风速未知';
    }
    return '$windSpeedLevel级风';
  }
}

DateTime _parseForecastDate(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.length != 8) {
    return DateTime.now();
  }
  final year = int.tryParse(raw.substring(0, 4)) ?? DateTime.now().year;
  final month = int.tryParse(raw.substring(4, 6)) ?? DateTime.now().month;
  final day = int.tryParse(raw.substring(6, 8)) ?? DateTime.now().day;
  return DateTime(year, month, day);
}

int _parseTemperatureValue(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed == -9999) {
    return 0;
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

int? _parsePercentScale(Object? value) {
  final parsed = _parseIntValue(value);
  if (parsed == null) {
    return null;
  }

  const mapping = {
    -4: 0,
    -3: 5,
    -2: 10,
    -1: 15,
    0: 20,
    1: 25,
    2: 35,
    3: 45,
    4: 55,
    5: 65,
    6: 75,
    7: 80,
    8: 85,
    9: 90,
    10: 92,
    11: 94,
    12: 96,
    13: 97,
    14: 98,
    15: 99,
    16: 100,
  };

  return mapping[parsed] ?? (parsed.clamp(1, 9) * 10);
}

enum SevenTimerPrecipitationType { none, rain, snow, freezingRain, icePellets }

extension SevenTimerPrecipitationTypePresentation
    on SevenTimerPrecipitationType {
  String get label {
    return switch (this) {
      SevenTimerPrecipitationType.none => '无降水',
      SevenTimerPrecipitationType.rain => '降雨',
      SevenTimerPrecipitationType.snow => '降雪',
      SevenTimerPrecipitationType.freezingRain => '冻雨',
      SevenTimerPrecipitationType.icePellets => '冰粒',
    };
  }
}

extension SevenTimerPrecipitationTypeParser on SevenTimerPrecipitationType {
  static SevenTimerPrecipitationType fromApiValue(String value) {
    return switch (value.toLowerCase()) {
      'rain' => SevenTimerPrecipitationType.rain,
      'snow' => SevenTimerPrecipitationType.snow,
      'frzr' => SevenTimerPrecipitationType.freezingRain,
      'icep' => SevenTimerPrecipitationType.icePellets,
      _ => SevenTimerPrecipitationType.none,
    };
  }
}

enum SevenTimerWeatherCode {
  clearDay,
  clearNight,
  partlyCloudyDay,
  partlyCloudyNight,
  mostlyCloudyDay,
  mostlyCloudyNight,
  cloudyDay,
  cloudyNight,
  humidDay,
  humidNight,
  lightRainDay,
  lightRainNight,
  occasionalShowerDay,
  occasionalShowerNight,
  isolatedShowerDay,
  isolatedShowerNight,
  lightSnowDay,
  lightSnowNight,
  rainDay,
  rainNight,
  snowDay,
  snowNight,
  rainSnowDay,
  rainSnowNight,
  thunderstormDay,
  thunderstormNight,
  thunderRainDay,
  thunderRainNight,
  unknown,
}

extension SevenTimerWeatherCodeMapper on SevenTimerWeatherCode {
  static SevenTimerWeatherCode fromApiValue(String value) {
    return switch (value.toLowerCase()) {
      'clearday' => SevenTimerWeatherCode.clearDay,
      'clearnight' => SevenTimerWeatherCode.clearNight,
      'pcloudyday' => SevenTimerWeatherCode.partlyCloudyDay,
      'pcloudynight' => SevenTimerWeatherCode.partlyCloudyNight,
      'mcloudyday' => SevenTimerWeatherCode.mostlyCloudyDay,
      'mcloudynight' => SevenTimerWeatherCode.mostlyCloudyNight,
      'cloudyday' => SevenTimerWeatherCode.cloudyDay,
      'cloudynight' => SevenTimerWeatherCode.cloudyNight,
      'humidday' => SevenTimerWeatherCode.humidDay,
      'humidnight' => SevenTimerWeatherCode.humidNight,
      'lightrainday' => SevenTimerWeatherCode.lightRainDay,
      'lightrainnight' => SevenTimerWeatherCode.lightRainNight,
      'oshowerday' => SevenTimerWeatherCode.occasionalShowerDay,
      'oshowernight' => SevenTimerWeatherCode.occasionalShowerNight,
      'ishowerday' => SevenTimerWeatherCode.isolatedShowerDay,
      'ishowernight' => SevenTimerWeatherCode.isolatedShowerNight,
      'lightsnowday' => SevenTimerWeatherCode.lightSnowDay,
      'lightsnownight' => SevenTimerWeatherCode.lightSnowNight,
      'rainday' => SevenTimerWeatherCode.rainDay,
      'rainnight' => SevenTimerWeatherCode.rainNight,
      'snowday' => SevenTimerWeatherCode.snowDay,
      'snownight' => SevenTimerWeatherCode.snowNight,
      'rainsnowday' => SevenTimerWeatherCode.rainSnowDay,
      'rainsnownight' => SevenTimerWeatherCode.rainSnowNight,
      'tsday' => SevenTimerWeatherCode.thunderstormDay,
      'tsnight' => SevenTimerWeatherCode.thunderstormNight,
      'tsrainday' => SevenTimerWeatherCode.thunderRainDay,
      'tsrainnight' => SevenTimerWeatherCode.thunderRainNight,
      _ => SevenTimerWeatherCode.unknown,
    };
  }

  String get label {
    return switch (this) {
      SevenTimerWeatherCode.clearDay ||
      SevenTimerWeatherCode.clearNight => '晴朗',
      SevenTimerWeatherCode.partlyCloudyDay ||
      SevenTimerWeatherCode.partlyCloudyNight => '多云',
      SevenTimerWeatherCode.mostlyCloudyDay ||
      SevenTimerWeatherCode.mostlyCloudyNight ||
      SevenTimerWeatherCode.cloudyDay ||
      SevenTimerWeatherCode.cloudyNight => '阴天',
      SevenTimerWeatherCode.humidDay ||
      SevenTimerWeatherCode.humidNight => '潮湿',
      SevenTimerWeatherCode.lightRainDay ||
      SevenTimerWeatherCode.lightRainNight ||
      SevenTimerWeatherCode.occasionalShowerDay ||
      SevenTimerWeatherCode.occasionalShowerNight ||
      SevenTimerWeatherCode.isolatedShowerDay ||
      SevenTimerWeatherCode.isolatedShowerNight ||
      SevenTimerWeatherCode.rainDay ||
      SevenTimerWeatherCode.rainNight => '降雨',
      SevenTimerWeatherCode.lightSnowDay ||
      SevenTimerWeatherCode.lightSnowNight ||
      SevenTimerWeatherCode.snowDay ||
      SevenTimerWeatherCode.snowNight ||
      SevenTimerWeatherCode.rainSnowDay ||
      SevenTimerWeatherCode.rainSnowNight => '降雪',
      SevenTimerWeatherCode.thunderstormDay ||
      SevenTimerWeatherCode.thunderstormNight ||
      SevenTimerWeatherCode.thunderRainDay ||
      SevenTimerWeatherCode.thunderRainNight => '雷暴',
      SevenTimerWeatherCode.unknown => '未知天气',
    };
  }

  WeatherType toWidgetWeatherType() {
    return switch (this) {
      SevenTimerWeatherCode.clearDay ||
      SevenTimerWeatherCode.clearNight => WeatherType.sunny,
      SevenTimerWeatherCode.partlyCloudyDay ||
      SevenTimerWeatherCode.partlyCloudyNight => WeatherType.partlyCloudy,
      SevenTimerWeatherCode.mostlyCloudyDay ||
      SevenTimerWeatherCode.mostlyCloudyNight ||
      SevenTimerWeatherCode.cloudyDay ||
      SevenTimerWeatherCode.cloudyNight ||
      SevenTimerWeatherCode.humidDay ||
      SevenTimerWeatherCode.humidNight => WeatherType.cloudy,
      SevenTimerWeatherCode.lightRainDay ||
      SevenTimerWeatherCode.lightRainNight ||
      SevenTimerWeatherCode.occasionalShowerDay ||
      SevenTimerWeatherCode.occasionalShowerNight ||
      SevenTimerWeatherCode.isolatedShowerDay ||
      SevenTimerWeatherCode.isolatedShowerNight ||
      SevenTimerWeatherCode.rainDay ||
      SevenTimerWeatherCode.rainNight => WeatherType.rainy,
      SevenTimerWeatherCode.lightSnowDay ||
      SevenTimerWeatherCode.lightSnowNight ||
      SevenTimerWeatherCode.snowDay ||
      SevenTimerWeatherCode.snowNight ||
      SevenTimerWeatherCode.rainSnowDay ||
      SevenTimerWeatherCode.rainSnowNight => WeatherType.snowy,
      SevenTimerWeatherCode.thunderstormDay ||
      SevenTimerWeatherCode.thunderstormNight ||
      SevenTimerWeatherCode.thunderRainDay ||
      SevenTimerWeatherCode.thunderRainNight => WeatherType.thunder,
      SevenTimerWeatherCode.unknown => WeatherType.cloudy,
    };
  }
}

/// 控制桌面天气小组件的数据加载与刷新状态，后续可直接接Riverpod Provider。
class WeatherWidgetController extends ChangeNotifier {
  WeatherWidgetController({required WeatherRepository repository})
    : _repository = repository;

  final WeatherRepository _repository;

  WeatherWidgetState _state = const WeatherWidgetState(isLoading: true);

  WeatherWidgetState get state => _state;

  Future<void> loadWeather() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final data = await _repository.fetchWeather();
      _state = WeatherWidgetState(data: data, isLoading: false);
    } catch (_) {
      _state = _state.copyWith(isLoading: false, errorMessage: '天气加载失败，点击重试');
    }
    notifyListeners();
  }
}

class WeatherWidgetCard extends StatelessWidget {
  const WeatherWidgetCard({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  final WeatherWidgetState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final data = state.data;

    if (state.isLoading && data == null) {
      return FrostPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '正在加载天气...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && data == null) {
      return FrostPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: palette.primaryText,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    final weather = data!;
    final brightness = Theme.of(context).brightness;
    final accentColors = weather.weatherType.colorsFor(brightness);

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onOpenDetail,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: accentColors,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: accentColors.last.withValues(alpha: 0.26),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    weather.weatherType.icon,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              weather.cityName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Text(
                            weather.updatedLabel(DateTime.now()),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${weather.currentTemperatureCelsius}°',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: palette.primaryText,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                ),
                          ),
                          Text(
                            weather.weatherType.label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: palette.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weather.highTemperatureCelsius}° / ${weather.lowTemperatureCelsius}° · ${weather.summary}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.secondaryText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WeatherInfoChip(
                    icon: Icons.thermostat_rounded,
                    label: weather.feelsLikeLabel,
                    accentColor: accentColors.first,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WeatherInfoChip(
                    icon: Icons.touch_app_rounded,
                    label: '点击查看详情',
                    accentColor: accentColors.last,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: state.isLoading ? null : onRefresh,
                    child: Ink(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.chipBackground,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.borderColor),
                      ),
                      child: state.isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColors.last,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: palette.primaryText,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: palette.secondaryText,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeatherInfoChip extends StatelessWidget {
  const _WeatherInfoChip({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, color: accentColor, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.item});

  final _AppIconData item;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(item.icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          item.label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.primaryText),
        ),
      ],
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.item});

  final _AppIconData item;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: palette.iconSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(item.icon, color: palette.primaryText, size: 26),
    );
  }
}

class _AppIconData {
  const _AppIconData(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class FrostPanel extends StatelessWidget {
  const FrostPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 32,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: palette.panelBackground,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: palette.borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HomePalette {
  const HomePalette({
    required this.backgroundGradient,
    required this.panelBackground,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
    required this.iconSurface,
    required this.chipBackground,
  });

  final List<Color> backgroundGradient;
  final Color panelBackground;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;
  final Color iconSurface;
  final Color chipBackground;

  /// 根据深浅色模式统一返回桌面所需配色，保证天气卡片与图标区视觉一致。
  static HomePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const HomePalette(
        backgroundGradient: [
          Color(0xFF2A1630),
          Color(0xFF171126),
          Color(0xFF0E1322),
        ],
        panelBackground: Color(0x1FFFFFFF),
        borderColor: Color(0x2EFFFFFF),
        primaryText: Colors.white,
        secondaryText: Color(0xCCFFFFFF),
        iconSurface: Color(0x19FFFFFF),
        chipBackground: Color(0x14FFFFFF),
      );
    }

    return const HomePalette(
      backgroundGradient: [
        Color(0xFFFFF1F4),
        Color(0xFFF7F2FB),
        Color(0xFFEFF4FF),
      ],
      panelBackground: Color(0xCCFFFFFF),
      borderColor: Color(0x1F6B4B73),
      primaryText: Color(0xFF2D2238),
      secondaryText: Color(0xFF6A6078),
      iconSurface: Color(0xE8FFFFFF),
      chipBackground: Color(0xF5FFFFFF),
    );
  }
}
