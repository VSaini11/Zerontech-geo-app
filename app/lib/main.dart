import 'package:flutter/material.dart';
import 'app.dart';
import 'background/background_hub.dart';
import 'background/notifier.dart';
import 'background/scheduler.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('*** FLUTTER ERROR CAUGHT ***: ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };
  await Notifier.init();
  await Scheduler.init(callbackDispatcher);
  final controller = AppController();
  runApp(GeoApp(controller: controller));
  controller.init();
}
