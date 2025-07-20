import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/execution_controller.dart';

class ExecutionPanel extends StatelessWidget {
  const ExecutionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ExecutionController execCtrl = Get.find();

    return Container(
      height: 200,
      color: Colors.black,
      child: Obx(() {
        return ListView(
          padding: const EdgeInsets.all(8),
          children: execCtrl.log
              .map((line) => Text(
                    line,
                    style: const TextStyle(color: Colors.greenAccent),
                  ))
              .toList(),
        );
      }),
    );
  }
}
