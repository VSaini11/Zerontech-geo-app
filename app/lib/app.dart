import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/employee/employee_shell.dart';
import 'state/app_controller.dart';

class GeoApp extends StatelessWidget {
  final AppController controller;
  const GeoApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Attendance',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          switch (controller.phase) {
            case Phase.booting:
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            case Phase.loggedOut:
              return LoginScreen(controller: controller);
            case Phase.ready:
              return controller.user!.isAdmin ? AdminShell(controller: controller) : EmployeeShell(controller: controller);
          }
        },
      ),
    );
  }
}
