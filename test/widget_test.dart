// Smoke test: verify the app can boot with all required GetX controllers
// registered, and that the main scaffold renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:Ricochet/controllers/docker_controller.dart';
import 'package:Ricochet/controllers/docker_search_controller.dart';
import 'package:Ricochet/controllers/execution_controller.dart';
import 'package:Ricochet/controllers/home_controller.dart';
import 'package:Ricochet/controllers/pipeline_controller.dart';
import 'package:Ricochet/controllers/pipeline_tabs_controller.dart';
import 'package:Ricochet/main.dart';

void main() {
  setUp(() {
    // Register all controllers the same way main() does.
    Get.put(HomeController());
    Get.put(PipelineController());
    Get.put(ExecutionController());
    Get.put(DockerSearchController());
    Get.put(DockerController());
    Get.put(PipelineTabsController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('App boots and renders a Scaffold', (WidgetTester tester) async {
    // Use a realistic desktop resolution to avoid AppBar overflow at the default
    // 800×600 test canvas size.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());
    // The app must render without throwing.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
