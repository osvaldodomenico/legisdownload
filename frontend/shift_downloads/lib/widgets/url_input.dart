import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';
import 'mech_button.dart';

class UrlInput extends StatefulWidget {
  final String platformHint;
  final void Function(String url) onSubmit;
  final bool loading;

  const UrlInput({super.key, required this.platformHint,
      required this.onSubmit, this.loading = false});

  @override
  State<UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<UrlInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isNotEmpty) widget.onSubmit(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: MechColors.surface,
            border: Border(left: BorderSide(color: MechColors.accentCyan, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(color: MechColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'URL://${widget.platformHint}',
                    hintStyle: const TextStyle(color: MechColors.textMuted, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (widget.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MechColors.accentCyan)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MechButton(
          label: '⬇ EXECUTE DOWNLOAD',
          onPressed: widget.loading ? null : _submit,
          loading: widget.loading,
        ),
      ],
    );
  }
}
