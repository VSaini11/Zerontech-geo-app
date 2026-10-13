import 'package:flutter/material.dart';
import 'app.dart';
import 'background/background_hub.dart';
import 'background/notifier.dart';
import 'background/scheduler.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  await Scheduler.init(callbackDispatcher);
  final controller = AppController();
  runApp(GeoApp(controller: controller));
  controller.init();
}
