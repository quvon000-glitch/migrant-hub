import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Files picked or recorded on the device. On the web the "path" is a blob: URL, so everything
/// goes through bytes / network images instead of dart:io.

Future<Uint8List> readBytes(String path) => XFile(path).readAsBytes();

/// JPEG for upload: resized and compressed on phones; on the web the picker already limits the size.
Future<Uint8List> jpegForUpload(String path, {int maxSide = 1600, int quality = 82}) async {
  final bytes = await readBytes(path);
  if (kIsWeb) return bytes;
  try {
    return await FlutterImageCompress.compressWithList(bytes, minWidth: maxSide, minHeight: maxSide, quality: quality);
  } catch (_) {
    return bytes;
  }
}

Widget localImage(String path, {BoxFit? fit}) => kIsWeb ? Image.network(path, fit: fit) : Image.file(File(path), fit: fit);
