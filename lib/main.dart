import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/pipeline_controller.dart';
import 'controllers/execution_controller.dart';
import 'views/modern_canvas.dart';
import 'views/modern_sidebar.dart';

void main() {
  Get.put(PipelineController());
  Get.put(ExecutionController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();

    return GetMaterialApp(
      title: 'Pipeline Designer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.biotech, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'BioFlow',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: execCtrl.runPipeline,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Execute'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: IconButton(
                onPressed: () => Get.find<PipelineController>().clearAll(),
                icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                tooltip: 'Reset Canvas',
              ),
            ),
          ],
        ),
        body: const Row(
          children: [
            ModernSidebar(),
            Expanded(
              child: ModernCanvas(),
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}