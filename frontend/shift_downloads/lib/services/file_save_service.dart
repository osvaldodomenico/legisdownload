import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class FileSaveService {
  /// Saves the file to device.
  /// - Web: opens download URL directly in browser
  /// - iOS/macOS: downloads and opens native share sheet
  /// - Desktop: downloads and saves to Downloads folder
  static Future<void> save(String fileUrl, String filename) async {
    if (kIsWeb) {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar arquivo: ${response.statusCode}');
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'ShiftDownloads');
      return;
    }

    // Desktop (Windows, Linux, macOS fallback)
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
  }
}
