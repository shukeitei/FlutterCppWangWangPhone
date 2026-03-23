import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wangwang_phone/app/weather/weather_repository.dart';
import 'package:wangwang_phone/app/weather/weather_types.dart';

void main() {
  test('SevenTimerWeatherRepository 能解析 civil JSON 并聚合成日级预报', () async {
    final requestedUris = <Uri>[];
    final repository = SevenTimerWeatherRepository(
      client: MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response(jsonEncode(_sampleCivilResponse), 200);
      }),
      locationProvider: const _FakeWeatherLocationProvider(),
    );

    final report = await repository.fetchWeather();

    expect(requestedUris.single.host, 'www.7timer.info');
    expect(requestedUris.single.path, '/bin/api.pl');
    expect(requestedUris.single.queryParameters['product'], 'civil');
    expect(requestedUris.single.queryParameters['output'], 'json');
    expect(requestedUris.single.queryParameters['lon'], '121.47');
    expect(requestedUris.single.queryParameters['lat'], '31.23');

    expect(report.cityName, '当前位置');
    expect(report.currentTemperatureCelsius, 30);
    expect(report.weatherType, WeatherType.cloudy);
    expect(report.dailyForecasts.length, 3);

    final firstDay = report.dailyForecasts[0];
    expect(firstDay.date, DateTime(2099, 3, 22));
    expect(firstDay.maxTemperature, 30);
    expect(firstDay.minTemperature, 25);
    expect(firstDay.weatherType, SevenTimerWeatherCode.cloudyDay);
    expect(firstDay.relativeHumidity, 54);
    expect(firstDay.cloudCover, 78);

    final secondDay = report.dailyForecasts[1];
    expect(secondDay.date, DateTime(2099, 3, 23));
    expect(secondDay.maxTemperature, 32);
    expect(secondDay.minTemperature, 24);
    expect(secondDay.weatherType, SevenTimerWeatherCode.clearDay);
  });
}

class _FakeWeatherLocationProvider extends WeatherLocationProvider {
  const _FakeWeatherLocationProvider();

  @override
  Future<WeatherLocationConfig> resolveLocation() async {
    return const WeatherLocationConfig(
      latitude: 31.23,
      longitude: 121.47,
      cityName: '当前位置',
    );
  }
}

const _sampleCivilResponse = {
  'product': 'civil',
  'init': '2099032206',
  'dataseries': [
    {
      'timepoint': 3,
      'cloudcover': 9,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 30,
      'rh2m': '46%',
      'wind10m': {'direction': 'S', 'speed': 3},
      'weather': 'cloudyday',
    },
    {
      'timepoint': 6,
      'cloudcover': 9,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 28,
      'rh2m': '52%',
      'wind10m': {'direction': 'S', 'speed': 3},
      'weather': 'cloudynight',
    },
    {
      'timepoint': 12,
      'cloudcover': 5,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 25,
      'rh2m': '65%',
      'wind10m': {'direction': 'S', 'speed': 2},
      'weather': 'pcloudynight',
    },
    {
      'timepoint': 18,
      'cloudcover': 1,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 24,
      'rh2m': '70%',
      'wind10m': {'direction': 'SE', 'speed': 2},
      'weather': 'clearday',
    },
    {
      'timepoint': 24,
      'cloudcover': 1,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 31,
      'rh2m': '35%',
      'wind10m': {'direction': 'S', 'speed': 3},
      'weather': 'clearday',
    },
    {
      'timepoint': 27,
      'cloudcover': 1,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 32,
      'rh2m': '35%',
      'wind10m': {'direction': 'SE', 'speed': 3},
      'weather': 'clearday',
    },
    {
      'timepoint': 45,
      'cloudcover': 9,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 26,
      'rh2m': '60%',
      'wind10m': {'direction': 'S', 'speed': 3},
      'weather': 'cloudyday',
    },
    {
      'timepoint': 48,
      'cloudcover': 9,
      'lifted_index': 2,
      'prec_type': 'none',
      'prec_amount': 0,
      'temp2m': 27,
      'rh2m': '52%',
      'wind10m': {'direction': 'S', 'speed': 3},
      'weather': 'cloudyday',
    },
  ],
};
