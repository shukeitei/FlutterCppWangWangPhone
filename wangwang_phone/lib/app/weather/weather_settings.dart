import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_types.dart';

const _temperatureUnitPreferenceKey = 'weather_temperature_unit';

WeatherSettingsStore buildDefaultWeatherSettingsStore() {
  return const SharedPreferencesWeatherSettingsStore();
}

abstract class WeatherSettingsStore {
  const WeatherSettingsStore();

  Future<TemperatureUnit> loadTemperatureUnit();

  Future<void> saveTemperatureUnit(TemperatureUnit unit);
}

class SharedPreferencesWeatherSettingsStore extends WeatherSettingsStore {
  const SharedPreferencesWeatherSettingsStore();

  @override
  Future<TemperatureUnit> loadTemperatureUnit() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_temperatureUnitPreferenceKey);
    return TemperatureUnitCodec.fromPreference(rawValue);
  }

  @override
  Future<void> saveTemperatureUnit(TemperatureUnit unit) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _temperatureUnitPreferenceKey,
      unit.preferenceValue,
    );
  }
}

class MemoryWeatherSettingsStore extends WeatherSettingsStore {
  MemoryWeatherSettingsStore({
    TemperatureUnit initialUnit = TemperatureUnit.celsius,
  }) : _unit = initialUnit;

  TemperatureUnit _unit;

  @override
  Future<TemperatureUnit> loadTemperatureUnit() async {
    return _unit;
  }

  @override
  Future<void> saveTemperatureUnit(TemperatureUnit unit) async {
    _unit = unit;
  }
}

class TemperatureUnitController extends ChangeNotifier {
  TemperatureUnitController({required WeatherSettingsStore store})
    : _store = store;

  final WeatherSettingsStore _store;

  TemperatureUnit _unit = TemperatureUnit.celsius;

  TemperatureUnit get unit => _unit;

  /// 启动时读取本地偏好，让桌面小组件和天气详情页使用同一套温标。
  Future<void> load() async {
    final storedUnit = await _store.loadTemperatureUnit();
    if (storedUnit == _unit) {
      return;
    }

    _unit = storedUnit;
    notifyListeners();
  }

  /// 更新温标后立刻刷新界面，再异步写回本地，保证交互反馈足够直接。
  Future<void> selectUnit(TemperatureUnit nextUnit) async {
    if (nextUnit == _unit) {
      return;
    }

    _unit = nextUnit;
    notifyListeners();
    await _store.saveTemperatureUnit(nextUnit);
  }
}
