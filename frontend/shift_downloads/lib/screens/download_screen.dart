import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/file_save_service.dart';
import '../theme/mech_theme.dart';
import '../widgets/mech_button.dart';
import '../widgets/progress_bar.dart';

class DownloadScreen extends StatefulWidget {
  final String jobId;
  final String platform;
  final String title;
  final String formatLabel;

  const DownloadScreen({
    super.key,
    required this.jobId,
    required this.platform,
    required this.title,
    required this.formatLabel,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  JobStatus? _status;
  Timer? _timer;
  int _pollCount = 0;
  static const _maxPolls = 300; // 10 min at 2s intervals
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _timer?.cancel();
      setState(() => _status = JobStatus(
          jobId: widget.jobId,
          status: 'error',
          progress: 0,
          error: 'Timeout — tente novamente'));
      return;
    }
    try {
      final status = await ApiService.getStatus(widget.jobId);
      setState(() => _status = status);
      if (status.status == 'complete' ||
          status.status == 'error' ||
          status.status == 'cancelled') {
        _timer?.cancel();
      }
    } catch (e) {
      if (e.toString().contains('job_not_found')) {
        _timer?.cancel();
        setState(() => _status = JobStatus(
            jobId: widget.jobId,
            status: 'error',
            progress: 0,
            error: 'Job não encontrado (servidor reiniciado?)'));
      }
    }
  }

  Future<void> _abort() async {
    _timer?.cancel();
    await ApiService.cancelJob(widget.jobId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final url = ApiService.fileUrl(widget.jobId);
      await FileSaveService.save(url, _status!.filename!);
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: MechColors.background,
      appBar: AppBar(
        backgroundColor: MechColors.background,
        title: Text(
          widget.title,
          style: const TextStyle(
              color: MechColors.accentYellow, fontSize: 13, letterSpacing: 1.0),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: MechColors.accentCyan),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: status == null
            ? const Center(
                child: CircularProgressIndicator(color: MechColors.accentCyan))
            : _buildBody(status),
      ),
    );
  }

  Widget _buildBody(JobStatus status) {
    if (status.status == 'complete') return _buildComplete(status);
    if (status.status == 'error') {
      return _buildError(status.error ?? 'Erro desconhecido');
    }
    if (status.status == 'cancelled') {
      return _buildError('Download cancelado');
    }
    return MechProgressBar(
      progress: status.progress,
      filename: status.filename,
      filesizeMb: status.filesizeMb,
      onAbort: _abort,
    );
  }

  Widget _buildComplete(JobStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: MechColors.surface,
              border: Border.all(color: MechColors.accentCyanDim)),
          child: Column(children: [
            const Text('✓ COMPLETE',
                style: TextStyle(
                    color: MechColors.accentCyan, fontSize: 12, letterSpacing: 2.0)),
            const SizedBox(height: 8),
            Text(status.filename ?? '',
                style: const TextStyle(color: MechColors.textPrimary, fontSize: 12),
                textAlign: TextAlign.center),
            if (status.filesizeMb != null)
              Text('${status.filesizeMb!.toStringAsFixed(1)} MB',
                  style: const TextStyle(
                      color: MechColors.textMuted, fontSize: 10)),
          ]),
        ),
        const SizedBox(height: 16),
        MechButton(
          label: _saving ? '...' : '⬇ SALVAR NO DISPOSITIVO',
          onPressed: _saving ? null : _save,
          loading: _saving,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(_saveError!,
              style: const TextStyle(color: MechColors.error, fontSize: 11)),
        ],
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('✕ ERRO',
            style: TextStyle(
                color: MechColors.error, fontSize: 14, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(
                color: MechColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        MechButton(
            label: '← VOLTAR',
            onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
