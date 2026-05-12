import 'dart:convert';
import 'package:http/http.dart' as http;

const String _baseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:8000');

class VideoInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String platform;
  final List<FormatOption> formats;
  final bool noWatermark;

  VideoInfo({required this.title, this.thumbnail, this.duration,
      required this.platform, required this.formats, required this.noWatermark});

  factory VideoInfo.fromJson(Map<String, dynamic> j) => VideoInfo(
        title: j['title'],
        thumbnail: j['thumbnail'],
        duration: j['duration'],
        platform: j['platform'],
        formats: (j['formats'] as List).map((f) => FormatOption.fromJson(f)).toList(),
        noWatermark: j['no_watermark'] ?? false,
      );
}

class FormatOption {
  final String id;
  final String label;
  final String ext;
  final String resolution;

  FormatOption({required this.id, required this.label,
      required this.ext, required this.resolution});

  factory FormatOption.fromJson(Map<String, dynamic> j) =>
      FormatOption(id: j['id'], label: j['label'], ext: j['ext'], resolution: j['resolution']);
}

class JobStatus {
  final String jobId;
  final String status;
  final double progress;
  final String? filename;
  final double? filesizeMb;
  final String? error;

  JobStatus({required this.jobId, required this.status,
      required this.progress, this.filename, this.filesizeMb, this.error});

  factory JobStatus.fromJson(Map<String, dynamic> j) => JobStatus(
        jobId: j['job_id'],
        status: j['status'],
        progress: (j['progress'] as num).toDouble(),
        filename: j['filename'],
        filesizeMb: j['filesize_mb'] != null ? (j['filesize_mb'] as num).toDouble() : null,
        error: j['error'],
      );
}

class ApiService {
  static Future<VideoInfo> getInfo(String url) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/info'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['detail'] ?? 'Erro ao buscar informações');
    }
    return VideoInfo.fromJson(jsonDecode(resp.body));
  }

  static Future<String> startDownload(String url, String formatId,
      {bool noWatermark = false}) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/download/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url, 'format_id': formatId, 'no_watermark': noWatermark}),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Falha ao iniciar download');
    return jsonDecode(resp.body)['job_id'] as String;
  }

  static Future<JobStatus> getStatus(String jobId) async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/status/$jobId'),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 404) throw Exception('job_not_found');
    if (resp.statusCode != 200) throw Exception('Erro ao verificar status');
    return JobStatus.fromJson(jsonDecode(resp.body));
  }

  static String fileUrl(String jobId) => '$_baseUrl/file/$jobId';

  static Future<void> cancelJob(String jobId) async {
    await http.post(Uri.parse('$_baseUrl/job/$jobId/cancel'))
        .timeout(const Duration(seconds: 10));
  }

  static Future<void> deleteJob(String jobId) async {
    await http.delete(Uri.parse('$_baseUrl/job/$jobId'))
        .timeout(const Duration(seconds: 10));
  }
}
