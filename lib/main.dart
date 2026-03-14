import 'dart:async';
import 'dart:io';

import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final version = await system.version;
    await deviceId.init();
    final container = await globalState.init(version);
    HttpOverrides.global = SaveXSpaceHttpOverrides();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const Application(),
      ),
    );
  } catch (e, s) {
    return runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
