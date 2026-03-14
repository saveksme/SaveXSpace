import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceId {
  static DeviceId? _instance;
  static const _hwidKey = 'device_hwid';

  String? _cachedHwid;
  String? _cachedDeviceOs;
  String? _cachedOsVersion;
  String? _cachedDeviceModel;
  bool _initialized = false;

  DeviceId._internal();

  factory DeviceId() {
    _instance ??= DeviceId._internal();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _cachedHwid = prefs.getString(_hwidKey);

    if (_cachedHwid == null || _cachedHwid!.isEmpty) {
      _cachedHwid = await _generateHwid();
      await prefs.setString(_hwidKey, _cachedHwid!);
    }

    await _collectDeviceInfo();
    _initialized = true;
  }

  String get hwid => _cachedHwid ?? '';
  String get deviceOs => _cachedDeviceOs ?? Platform.operatingSystem;
  String get osVersion => _cachedOsVersion ?? '';
  String get deviceModel => _cachedDeviceModel ?? '';

  Future<String> _generateHwid() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final id = info.id;
        if (id.isNotEmpty) return id;
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        final id = info.deviceId;
        if (id.isNotEmpty) return id;
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        final id = info.systemGUID ?? '';
        if (id.isNotEmpty) return id;
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        final id = info.machineId ?? '';
        if (id.isNotEmpty) return id;
      }
    } catch (e) {
      commonPrint.log('Failed to get platform HWID: $e');
    }
    return utils.uuidV4;
  }

  Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _cachedDeviceOs = 'Android';
        _cachedOsVersion = info.version.release;
        _cachedDeviceModel = '${info.brand} ${info.model}';
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        _cachedDeviceOs = 'Windows';
        _cachedOsVersion =
            '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
        _cachedDeviceModel = info.productName;
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        _cachedDeviceOs = 'macOS';
        _cachedOsVersion =
            '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
        _cachedDeviceModel = info.model;
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        _cachedDeviceOs = 'Linux';
        _cachedOsVersion = info.versionId ?? '';
        _cachedDeviceModel = info.prettyName;
      }
    } catch (e) {
      commonPrint.log('Failed to collect device info: $e');
      _cachedDeviceOs = Platform.operatingSystem;
      _cachedOsVersion = Platform.operatingSystemVersion;
      _cachedDeviceModel = 'Unknown';
    }
  }

  Map<String, String> get headers => {
        'x-hwid': hwid,
        'x-device-os': deviceOs,
        'x-ver-os': osVersion,
        'x-device-model': deviceModel,
      };
}

final deviceId = DeviceId();
