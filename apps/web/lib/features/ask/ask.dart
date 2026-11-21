import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Opens the Ask panel for one ward or contractor.
class AskButton extends ConsumerWidget {
  const AskButton(this.scopeType, this.scopeId, {super.key});
  final String scopeType, scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return OutlinedButton.icon(
      onPressed: () => showDetail(context, title: t('ask.title'), child: _AskPanel(scopeType, scopeId)),
      icon: const Icon(Icons.forum_outlined, size: 18),
      label: Text(t('ask.button')),
    );
  }
}

class _AskPanel extends ConsumerStatefulWidget {
  const _AskPanel(this.scopeType, this.scopeId);
  final String scopeType, scopeId;
  @override
  ConsumerState<_AskPanel> createState() => _AskState();
}

class _AskState extends ConsumerState<_AskPanel> {
  final _box = TextEditingController();
  bool _busy = false;
  String? _answer, _error;

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    if (preset != null) _box.text = preset;
    final q = _box.text.trim();
    if (q.length < 3 || _busy) return;
    final t = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = _answer = null;
    });
    try {
      final res = await ref.read(dioProvider).post('/ask',
          data: {'question': q, 'scope_type': widget.scopeType, 'scope_id': widget.scopeId, 'lang': ref.read(langProvider)});
      if (mounted) setState(() => _answer = '${res.data['answer']}');
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => _error = err.code == 'network' ? t('err.network') : err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final presets = [for (var n = 1; n <= (widget.scopeType == 'ward' ? 3 : 2); n++) t('ask.q.${widget.scopeType}$n')];
    return ListView(padding: const EdgeInsets.all(Gap.lg), children: [
      Text(t('ask.note'), style: tt.bodySmall),
      const SizedBox(height: Gap.md),
      Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [for (final p in presets) ActionChip(label: Text(p), onPressed: _busy ? null : () => _ask(p))]),
      const SizedBox(height: Gap.md),
      TextField(
        controller: _box,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: t('ask.hint')),
        onSubmitted: (_) => _ask(),
      ),
      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: _busy ? null : _ask, child: Text(t('ask.send')))),
      const SizedBox(height: Gap.lg),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(color: c.errorTint, borderRadius: BorderRadius.circular(kRadius)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, size: 18, color: c.error),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(_error!, style: TextStyle(color: c.textPrimary))),
          ]),
        ),
      if (_answer != null) SectionCard(child: SelectableText(_answer!, style: tt.bodyLarge)),
    ]);
  }
}
