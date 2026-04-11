import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() async {
  final file = File('C:\\Users\\bhage\\OneDrive\\Documents\\Ricochet\\exports\\Ricochet-export_2026-04-11T10-38-29.zip');
  print(await file.exists());
}
