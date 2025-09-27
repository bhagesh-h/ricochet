// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import '../../controllers/pipeline_controller.dart';
// import '../../models/pipeline_node.dart';

// class ParameterPanel extends StatelessWidget {
//   final String nodeId;

//   const ParameterPanel({Key? key, required this.nodeId}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.find<PipelineController>();
//     final node = controller.nodes.firstWhereOrNull((n) => n.id == nodeId);

//     if (node == null) return const SizedBox();

//     return Container(
//       width: 320,
//       constraints: const BoxConstraints(maxHeight: 600),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: node.categoryColor.withOpacity(0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               gradient: node.gradient,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(16),
//                 topRight: Radius.circular(16),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Icon(node.icon, color: Colors.white, size: 20),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     node.title,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () => controller.selectedNode.value = null,
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: const Icon(Icons.close, color: Colors.white, size: 16),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Parameters
//           if (node.parameters.isEmpty)
//             const Padding(
//               padding: EdgeInsets.all(20),
//               child: Text(
//                 'No parameters available for this block.',
//                 style: TextStyle(color: Colors.grey),
//               ),
//             )
//           else
//             Flexible(
//               child: ListView.builder(
//                 shrinkWrap: true,
//                 padding: const EdgeInsets.all(20),
//                 itemCount: node.parameters.length,
//                 itemBuilder: (context, index) {
//                   final param = node.parameters[index];
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 16),
//                     child: _buildParameterWidget(param, node),
//                   );
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildParameterWidget(BlockParameter param, PipelineNode node) {
//     final controller = Get.find<PipelineController>();

//     switch (param.type) {
//       case ParameterType.text:
//         return _buildTextParameter(param, node, controller);
//       case ParameterType.numeric:
//         return _buildNumericParameter(param, node, controller);
//       case ParameterType.dropdown:
//         return _buildDropdownParameter(param, node, controller);
//       case ParameterType.toggle:
//         return _buildToggleParameter(param, node, controller);
//       case ParameterType.file:
//         return _buildFileParameter(param, node, controller);
//     }
//   }

//   Widget _buildTextParameter(BlockParameter param, PipelineNode node, PipelineController controller) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           param.label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 8),
//         TextFormField(
//           initialValue: param.value?.toString() ?? '',
//           decoration: InputDecoration(
//             hintText: param.placeholder ?? 'Enter ${param.label.toLowerCase()}',
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: node.categoryColor),
//             ),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           onChanged: (value) {
//             controller.updateNodeParameter(node.id, param.key, value);
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildNumericParameter(BlockParameter param, PipelineNode node, PipelineController controller) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           param.label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 8),
//         TextFormField(
//           initialValue: param.value?.toString() ?? '',
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           decoration: InputDecoration(
//             hintText: 'Enter number',
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: node.categoryColor),
//             ),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           onChanged: (value) {
//             final numValue = int.tryParse(value);
//             controller.updateNodeParameter(node.id, param.key, numValue);
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildDropdownParameter(BlockParameter param, PipelineNode node, PipelineController controller) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           param.label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           value: param.value?.toString(),
//           decoration: InputDecoration(
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide(color: node.categoryColor),
//             ),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           items: param.options?.map((option) {
//             return DropdownMenuItem<String>(
//               value: option,
//               child: Text(option),
//             );
//           }).toList(),
//           onChanged: (value) {
//             controller.updateNodeParameter(node.id, param.key, value);
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildToggleParameter(BlockParameter param, PipelineNode node, PipelineController controller) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           param.label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         Switch(
//           value: param.value == true,
//           activeColor: node.categoryColor,
//           onChanged: (value) {
//             controller.updateNodeParameter(node.id, param.key, value);
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildFileParameter(BlockParameter param, PipelineNode node, PipelineController controller) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           param.label,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 8),
//         GestureDetector(
//           onTap: () {
//             // Simulate file picker
//             _showFilePickerDialog(param, node, controller);
//           },
//           child: Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey[300]!),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.file_upload, color: node.categoryColor, size: 20),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     param.value?.toString() ?? param.placeholder ?? 'Select file...',
//                     style: TextStyle(
//                       color: param.value != null ? Colors.black87 : Colors.grey[600],
//                     ),
//                   ),
//                 ),
//                 Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   void _showFilePickerDialog(BlockParameter param, PipelineNode node, PipelineController controller) {
//     final sampleFiles = [
//       'sample_data.fasta',
//       'genome_reference.fa',
//       'reads_R1.fastq',
//       'reads_R2.fastq',
//       'variants.vcf',
//       'alignment.bam',
//       'quality_report.csv',
//     ];

//     Get.dialog(
//       AlertDialog(
//         title: Text('Select ${param.label}'),
//         content: SizedBox(
//           width: 300,
//           height: 300,
//           child: ListView.builder(
//             itemCount: sampleFiles.length,
//             itemBuilder: (context, index) {
//               final file = sampleFiles[index];
//               return ListTile(
//                 leading: Icon(Icons.insert_drive_file, color: node.categoryColor),
//                 title: Text(file),
//                 onTap: () {
//                   controller.updateNodeParameter(node.id, param.key, file);
//                   Get.back();
//                 },
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Get.back(),
//             child: const Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }
// }