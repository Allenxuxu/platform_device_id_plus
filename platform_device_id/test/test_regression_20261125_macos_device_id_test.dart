import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_id_plus/platform_device_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('com.di1shuai.flutter/platform_device_id');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('macOS delegates native registration to its existing platform package',
      () {
    final File packageConfigFile = File('.dart_tool/package_config.json');
    final Map<String, Object?> packageConfig =
        jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, Object?>;
    final List<Map<String, Object?>> packages =
        (packageConfig['packages']! as List<Object?>)
            .cast<Map<String, Object?>>();
    final Map<String, Object?> package = packages.firstWhere(
      (Map<String, Object?> entry) => entry['name'] == 'platform_device_id_plus',
    );
    final Uri packageUri = packageConfigFile.absolute.uri
        .resolve('${package['rootUri']! as String}/');

    final String manifest =
        File.fromUri(packageUri.resolve('pubspec.yaml')).readAsStringSync();
    expect(
      manifest,
      matches(RegExp(
        r'macos:\s*\n\s+default_package:\s*platform_device_id_macos\s*\n',
      )),
    );

    final Map<String, Object?> macosPackage = packages.firstWhere(
      (Map<String, Object?> entry) => entry['name'] == 'platform_device_id_macos',
    );
    final Uri macosPackageUri = packageConfigFile.absolute.uri
        .resolve('${macosPackage['rootUri']! as String}/');
    expect(
      File.fromUri(macosPackageUri
              .resolve('macos/platform_device_id_macos.podspec'))
          .existsSync(),
      isTrue,
    );
  });

  test('macOS device ID uses the existing method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      expect(call.method, 'getDeviceId');
      return 'regression-device-id';
    });

    expect(await PlatformDeviceId.getDeviceId, 'regression-device-id');
  }, skip: !Platform.isMacOS);

  test('macOS null device ID remains null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);

    expect(await PlatformDeviceId.getDeviceId, isNull);
  }, skip: !Platform.isMacOS);

  test('macOS platform exception retains the existing empty device ID result',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(code: 'device_id_unavailable');
    });

    expect(await PlatformDeviceId.getDeviceId, isEmpty);
  }, skip: !Platform.isMacOS);
}
