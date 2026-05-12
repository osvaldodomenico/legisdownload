import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../theme/mech_theme.dart';
import '../widgets/mech_button.dart';
import '../widgets/url_input.dart';
import '../widgets/video_preview.dart';
import '../widgets/format_selector.dart';
import '../widgets/history_list.dart';
import '../widgets/platform_tabs.dart';
import 'download_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  VideoInfo? _info;
  bool _loadingInfo = false;
  String? _infoError;
  String? _selectedFormat;
  bool _noWatermark = false;
  bool _startingDownload = false;
  String? _currentUrl;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadHistory();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _info = null;
        _infoError = null;
        _selectedFormat = null;
      });
    }
  }

  Future<void> _loadHistory() async {
    final h = await HistoryService.load();
    setState(() => _history = h);
  }

  Future<void> _fetchInfo(String url) async {
    _currentUrl = url;
    setState(() {
      _loadingInfo = true;
      _infoError = null;
      _info = null;
      _selectedFormat = null;
    });
    try {
      final info = await ApiService.getInfo(url);
      setState(() {
        _info = info;
        _selectedFormat =
            info.formats.isNotEmpty ? info.formats.first.id : null;
      });
    } catch (e) {
      setState(
          () => _infoError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loadingInfo = false);
    }
  }

  Future<void> _startDownload() async {
    final info = _info;
    final format = _selectedFormat;
    if (info == null || format == null) return;
    setState(() => _startingDownload = true);
    try {
      final jobId =
          await ApiService.startDownload(_currentUrl!, format, noWatermark: _noWatermark);
      final formatLabel = info.formats
          .firstWhere((f) => f.id == format,
              orElse: () => info.formats.first)
          .label;
      await HistoryService.add(HistoryEntry(
          platform: info.platform,
          title: info.title,
          format: formatLabel,
          downloadedAt: DateTime.now()));
      await _loadHistory();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DownloadScreen(
              jobId: jobId,
              platform: info.platform,
              title: info.title,
              formatLabel: formatLabel,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: MechColors.error),
        );
      }
    } finally {
      setState(() => _startingDownload = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: MechColors.background,
      appBar: AppBar(
        backgroundColor: MechColors.background,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHiFT//DOWNLOADS',
                style: TextStyle(
                    color: MechColors.accentYellow,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0)),
            Text('MEDIA EXTRACTION SYSTEM',
                style: TextStyle(
                    color: MechColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 2.0)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: platformTabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(5, (i) => _buildTab(i, isWide)),
      ),
    );
  }

  Widget _buildTab(int tabIndex, bool isWide) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UrlInput(
          platformHint: platformHint(tabIndex),
          onSubmit: _fetchInfo,
          loading: _loadingInfo,
        ),
        if (_infoError != null) ...[
          const SizedBox(height: 8),
          Text(_infoError!,
              style: const TextStyle(color: MechColors.error, fontSize: 11)),
        ],
        if (_info != null) ...[
          const SizedBox(height: 12),
          VideoPreview(info: _info!),
          const SizedBox(height: 12),
          FormatSelector(
            formats: _info!.formats,
            showNoWatermark: _info!.noWatermark,
            selectedId: _selectedFormat,
            noWatermark: _noWatermark,
            onSelect: (id) => setState(() => _selectedFormat = id),
            onNoWatermarkToggle: (v) => setState(() => _noWatermark = v),
          ),
          const SizedBox(height: 12),
          MechButton(
            label: '⬇ DOWNLOAD',
            onPressed: _startingDownload ? null : _startDownload,
            loading: _startingDownload,
          ),
        ],
        const SizedBox(height: 20),
        HistoryList(entries: _history),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20), child: content)),
          Container(width: 1, color: MechColors.border),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: HistoryList(entries: _history))),
        ],
      );
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: content);
  }
}
