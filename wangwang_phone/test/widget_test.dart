import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wangwang_phone/main.dart';

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
    await tester.pumpWidget(const WangWangApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
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
    await tester.pumpWidget(const WangWangApp());

    expect(find.text('正在加载天气...'), findsOneWidget);
  });
}
