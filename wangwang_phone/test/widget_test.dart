import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wangwang_phone/main.dart';

class _FakeWeatherRepository extends WeatherRepository {
  _FakeWeatherRepository(this.report);

  final WeatherReport report;

  @override
  Future<WeatherReport> fetchWeather() async {
    return report;
  }
}

WeatherReport _buildFakeReport() {
  final startDate = DateTime(2026, 3, 21);
  return WeatherReport(
    location: const WeatherLocationConfig(
      latitude: 22.5431,
      longitude: 114.0579,
      cityName: '深圳市',
    ),
    updatedAt: DateTime(2026, 3, 21, 10, 30),
    dailyForecasts: List.generate(7, (index) {
      return SevenTimerDailyForecast(
        date: startDate.add(Duration(days: index)),
        weatherType: switch (index) {
          0 => SevenTimerWeatherCode.clearDay,
          1 => SevenTimerWeatherCode.partlyCloudyDay,
          2 => SevenTimerWeatherCode.rainDay,
          3 => SevenTimerWeatherCode.cloudyDay,
          4 => SevenTimerWeatherCode.clearDay,
          5 => SevenTimerWeatherCode.thunderRainDay,
          _ => SevenTimerWeatherCode.lightSnowDay,
        },
        maxTemperature: 28 - index,
        minTemperature: 21 - index,
        cloudCover: 30 + index * 5,
        relativeHumidity: 65 + index,
        windDirection: 'NE',
        windSpeedLevel: 3 + (index % 2),
        precipitationType: switch (index) {
          2 => SevenTimerPrecipitationType.rain,
          5 => SevenTimerPrecipitationType.rain,
          6 => SevenTimerPrecipitationType.snow,
          _ => SevenTimerPrecipitationType.none,
        },
      );
    }),
  );
}

WangWangApp _buildTestApp({MemoryWeatherSettingsStore? settingsStore}) {
  return WangWangApp(
    weatherRepository: _FakeWeatherRepository(_buildFakeReport()),
    weatherSettingsStore: settingsStore ?? MemoryWeatherSettingsStore(),
  );
}

void main() {
  test('7timer天气类型映射正确', () {
    expect(
      SevenTimerWeatherCodeMapper.fromApiValue(
        'clearday',
      ).toWidgetWeatherType(),
      WeatherType.sunny,
    );
    expect(
      SevenTimerWeatherCodeMapper.fromApiValue(
        'pcloudyday',
      ).toWidgetWeatherType(),
      WeatherType.partlyCloudy,
    );
    expect(
      SevenTimerWeatherCodeMapper.fromApiValue(
        'rainnight',
      ).toWidgetWeatherType(),
      WeatherType.rainy,
    );
    expect(
      SevenTimerWeatherCodeMapper.fromApiValue('snowday').toWidgetWeatherType(),
      WeatherType.snowy,
    );
    expect(
      SevenTimerWeatherCodeMapper.fromApiValue('tsday').toWidgetWeatherType(),
      WeatherType.thunder,
    );
  });

  testWidgets('桌面展示天气小组件与应用图标', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('深圳市'), findsOneWidget);
    expect(find.textContaining('°'), findsWidgets);
    expect(find.text('点击查看详情'), findsOneWidget);
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('天气'), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
  });

  testWidgets('桌面天气小组件初始展示加载状态', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.text('正在加载天气...'), findsOneWidget);
  });

  testWidgets('点击天气图标后进入天气应用详情页', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('天气'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weather_detail_scroll')), findsOneWidget);
    expect(find.text('天气'), findsWidgets);

    await tester.drag(
      find.byKey(const Key('weather_detail_scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(find.text('温度走势'), findsOneWidget);
    expect(find.text('今日细节'), findsOneWidget);
  });

  testWidgets('点击桌面天气卡片后进入天气详情页', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('点击查看详情'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weather_detail_scroll')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('weather_detail_scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(find.text('温度走势'), findsOneWidget);
  });

  testWidgets('点击微信图标后进入聊天应用并显示四个Tab', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('微信'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_app_page')), findsOneWidget);
    expect(find.text('聊天'), findsWidgets);
    expect(find.text('联系人'), findsOneWidget);
    expect(find.text('朋友圈'), findsOneWidget);
    expect(find.text('我'), findsOneWidget);
    expect(find.text('阿梨'), findsOneWidget);
  });

  testWidgets('聊天应用支持发送文字并收到角色回复', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('微信'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_thread_ari')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_input_field')),
      '今天会议好多，我有点累',
    );
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();

    expect(find.text('今天会议好多，我有点累'), findsOneWidget);
    expect(find.byKey(const Key('chat_typing_indicator')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.textContaining('先抱抱你一下'), findsOneWidget);
  });

  testWidgets('切换华氏度后桌面与天气详情同步更新', (WidgetTester tester) async {
    final settingsStore = MemoryWeatherSettingsStore();

    await tester.pumpWidget(_buildTestApp(settingsStore: settingsStore));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('25°C'), findsOneWidget);

    await tester.tap(find.text('天气'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('temperature_unit_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('temperature_unit_fahrenheit')));
    await tester.pumpAndSettle();

    expect(find.text('77°F'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('77°F'), findsOneWidget);
  });
}
