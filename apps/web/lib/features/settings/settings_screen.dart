import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

final settingsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/settings'))['items']));

/// Thresholds and risk weights. Saving re-computes flags, scorecards and the plan at once.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  final _edits = <String, String>{}; // key -> text as typed
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final t = ref.read(stringsProvider);
    final values = {for (final e in _edits.entries) e.key: double.tryParse(e.value)};
    if (values.values.any((v) => v == null)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).put('/settings', data: {'values': values});
      _edits.clear();
      // Every figure in the app can depend on a setting, so reload everything.
      ref.invalidate(dioProvider);
      ref.invalidate(settingsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('settings.saved'))));
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
    return AsyncView(
      value: ref.watch(settingsProvider),
      onRetry: () => ref.invalidate(settingsProvider),
      lines: 10,
      builder: (items) {
        num value(Map<String, dynamic> s) => double.tryParse(_edits['${s['key']}'] ?? '') ?? (s['value'] as num);
        final total = items.where((s) => '${s['key']}'.startsWith('w_')).fold<num>(0, (a, s) => a + value(s));
        final weightsOk = (total - 100).abs() < 0.001;
        final allNumbers = _edits.values.every((v) => double.tryParse(v) != null);
        return PageBody(children: [
          Text(t('settings.title'), style: tt.titleLarge),
          Text(t('settings.note'), style: tt.bodyMedium!.copyWith(color: c.textSecondary)),
          SectionCard(
            child: Column(children: [
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['description']}', style: tt.bodyMedium),
                        Text('${s['key']}', style: tt.bodySmall),
                      ]),
                    ),
                    const SizedBox(width: Gap.md),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        key: ValueKey('${s['key']}-${s['value']}'),
                        initialValue: fmt.ratio(s['value']),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.end,
                        decoration: InputDecoration(labelText: t('settings.value'), errorText: double.tryParse(_edits['${s['key']}'] ?? '0') == null ? '0–1000' : null),
                        onChanged: (v) => setState(() => _edits['${s['key']}'] = v.trim()),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          Wrap(spacing: Gap.lg, runSpacing: Gap.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Pill(t('settings.weights', {'n': fmt.ratio(total)}), tone: weightsOk ? Tone.success : Tone.error, icon: weightsOk ? Icons.check : Icons.error_outline),
            FilledButton(onPressed: _busy || _edits.isEmpty || !weightsOk || !allNumbers ? null : _save, child: Text(t('action.save'))),
            if (_error != null) Text(_error!, style: TextStyle(color: c.error)),
          ]),
        ]);
      },
    );
  }
}
