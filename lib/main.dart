import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await AppContainer.create();
  runApp(App(container: container));
}