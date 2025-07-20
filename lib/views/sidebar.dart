import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  final List<String> tools = const [
    'FastQC',
    'Trimmomatic',
    'BWA',
    'GATK',
    'FreeBayes',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.grey[200],
      child: ListView(
        children: tools.map((tool) {
          return Draggable<String>(
            data: tool,
            feedback: Material(
              child: Chip(label: Text(tool)),
            ),
            child: ListTile(
              title: Text(tool),
            ),
          );
        }).toList(),
      ),
    );
  }
}
