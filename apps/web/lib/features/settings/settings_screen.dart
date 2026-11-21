import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

final settingsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/settings'))['items']));

// (key, unit shown in the box, display scale). The area tolerance is stored as a share and shown as a percent.
const _groups = [
  ('billing', [('overbill_ratio', '×', 1), ('overbill_watch_ratio', '×', 1), ('dup_window_days', 'days', 1), ('dup_area_tolerance', '%', 100)]),
  ('comparison', [('band_min_jobs', '', 1), ('band_z', '', 1), ('band_z_strong', '', 1)]),
  ('risk', [('low_lying_cutoff', '', 1), ('rain_moderate_mm', 'mm', 1), ('rain_heavy_mm', 'mm', 1), ('high_risk_score', '', 1), ('hotspot_radius_m', 'm', 1)]),
];
const _weights = ['w_severity', 'w_access', 'w_safety', 'w_traffic', 'w_flood', 'w_demand'];
const _weightsKey = 'weights';

/// Thresholds and risk weights. Each threshold saves on its own; the six weights save together.
/// Saving re-computes flags, scorecards and the plan at once.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  final _edits = <String, String>{}; // key -> text as typed, in display units
  final _errors = <String, String>{}; // row key (or 'weights') -> server message
  String? _busy, _saved, _last; // row being saved, row just saved, row edited last (the one primary button)

  Future<void> _save(String rowKey, Map<String, double> values) async {
    final t = ref.read(stringsProvider);
    setState(() {
      _busy = rowKey;
      _errors.remove(rowKey);
      _saved = null;
    });
    try {
      await ref.read(dioProvider).put('/settings', data: {'values': values});
      values.keys.forEach(_edits.remove);
      // Every figure in the app can depend on a setting, so reload everything.
      ref.invalidate(dioProvider);
      ref.invalidate(settingsProvider);
      if (mounted) setState(() => _saved = rowKey);
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => _errors[rowKey] = err.code == 'network' ? t('err.network') : err.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _edit(String key, String rowKey, String v) => setState(() {
        _edits[key] = v.trim();
        _last = rowKey;
        if (_saved == rowKey) _saved = null;
      });

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return SetTopBar(
      title: t('settings.title'),
      child: AsyncView(
        value: ref.watch(settingsProvider),
        onRetry: () => ref.invalidate(settingsProvider),
        lines: 10,
        builder: (items) {
          final byKey = {for (final s in items) '${s['key']}': s};
          final count = _groups.fold<int>(0, (n, g) => n + g.$2.where((r) => byKey.containsKey(r.$1)).length);
          final phone = isPhone(context);
          final side = [
            _weightsPanel(t, byKey),
            const SizedBox(height: Tok.gapPanels),
            _whatPanel(t),
          ];
          final thresholds = Panel(
            title: t('settings.thresholds'),
            sub: t('settings.thresholdsSub', {'n': count}),
            // Phone: the value column header has no column to sit over.
            trailing: phone ? null : Padding(padding: const EdgeInsets.only(right: 76), child: Caps(t('settings.value'))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, (group, rows)) in _groups.indexed) ...[
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 14, bottom: 4),
                  child: Row(children: [
                    Caps(t('settings.group.$group')),
                    const SizedBox(width: 10),
                    const Expanded(child: Divider(color: Tok.lineInset)),
                    const SizedBox(width: 10),
                    Text(t('settings.groupCount', {'n': rows.length}), style: Tok.sub),
                  ]),
                ),
                for (final (key, unit, scale) in rows)
                  if (byKey[key] case final s?) _row(t, s, unit == 'days' ? t('settings.unit.days') : unit, scale.toDouble(), phone),
              ],
            ]),
          );
          return PageBody(children: [
            Panel(
              // Wrap: on a phone the two pills drop under the title.
              child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: Text(t('settings.title'), style: Tok.section)),
                Pill(t('settings.recalc'), tone: Tone.success, icon: Ico.info),
                Pill(t('settings.auditorOnly'), icon: Icons.lock_outline),
              ]),
            ),
            if (phone) ...[thresholds, ...side]
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: thresholds),
                const SizedBox(width: Tok.gapPanels),
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
              ]),
          ]);
        },
      ),
    );
  }

  Widget _whatPanel(Strings t) => Panel(
      title: t('settings.what'),
      child: Column(children: [
        for (final (i, (icon, k)) in [(Ico.flag, 'flags'), (Ico.contractor, 'score'), (Icons.format_list_numbered, 'plan')].indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          InsetCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(7), border: Border.all(color: Tok.line)),
                child: Icon(icon, size: 14, color: Tok.text2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(style: Tok.body, children: [
                  TextSpan(text: t('settings.what.$k'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' ${t('settings.what.${k}Sub')}'),
                ])),
              ),
            ]),
          ),
        ],
      ]),
    );

  /// One threshold: name, what it does, the value box and its own Save.
  Widget _row(Strings t, Map<String, dynamic> s, String unit, double scale, bool phone) {
    final key = '${s['key']}';
    final stored = (s['value'] as num) * scale;
    final typed = _edits[key];
    final parsed = typed == null ? null : double.tryParse(typed);
    final invalid = typed != null && (parsed == null || parsed / scale < 0 || parsed / scale > 1000);
    final dirty = typed != null && !invalid && (parsed! - stored).abs() > 1e-9;
    final error = _errors[key];
    final status = invalid
        ? _status(Icons.error_outline, t('settings.invalid'), Tok.red)
        : error != null
            ? _status(Icons.error_outline, error, Tok.red)
            : dirty
                ? Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Tok.teal, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(t('settings.changed'), style: Tok.sub.copyWith(fontWeight: FontWeight.w600, color: Tok.ink)),
                    Text(' · ${t('settings.was', {'v': fmt.ratio(stored)})}', style: Tok.sub),
                  ])
                : _saved == key
                    ? _status(Icons.check_circle_outline, t('settings.savedRow'), Tok.tealDark)
                    : null;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('settings.k.$key'), style: Tok.emph.copyWith(fontWeight: FontWeight.w600)),
      Text('${s['description']}', style: Tok.body.copyWith(color: Tok.text2)),
      if (status != null) ...[const SizedBox(height: 2), status],
    ]);
    return Container(
      margin: EdgeInsets.symmetric(vertical: dirty ? 2 : 0),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: dirty
          ? BoxDecoration(color: const Color(0xFFF1F8F6), borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.tealZone))
          : const BoxDecoration(border: Border(bottom: BorderSide(color: Tok.lineSoft))),
      // Phone: the value box and Save go under the text instead of beside it.
      child: Flex(direction: phone ? Axis.vertical : Axis.horizontal, crossAxisAlignment: phone ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        if (phone) text else Expanded(child: text),
        SizedBox(width: 12, height: phone ? 8 : 0),
        Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 104, child: _box(key, fmt.ratio(stored), unit, invalid, (v) => _edit(key, key, v), s['value'])),
          const SizedBox(width: 12),
          _saveBtn(dirty && _last == key, t('action.save'), dirty && _busy == null ? () => _save(key, {key: parsed / scale}) : null),
        ]),
      ]),
    );
  }

  // Only the row edited last gets the primary style, so the screen never shows two primary buttons.
  Widget _saveBtn(bool primary, String label, VoidCallback? onPressed) =>
      primary ? AppButton.primary(label, onPressed: onPressed) : AppButton.outlined(label, onPressed: onPressed);

  Widget _status(IconData icon, String text, Color color) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Tok.sub.copyWith(fontWeight: FontWeight.w600, color: color))),
      ]);

  /// Compact right-aligned number box with a unit; red border when the text is not a usable number.
  Widget _box(String key, String initial, String unit, bool invalid, ValueChanged<String> onChanged, Object? stored) {
    final r = BorderRadius.circular(Tok.rControl);
    return TextFormField(
      key: ValueKey('$key-$stored'),
      initialValue: initial,
      textAlign: TextAlign.end,
      style: Tok.emph.copyWith(fontWeight: FontWeight.w500),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        constraints: const BoxConstraints(maxHeight: 36),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixText: unit.isEmpty ? null : ' $unit',
        suffixStyle: Tok.sub.copyWith(color: Tok.text3),
        enabledBorder: invalid ? OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: Tok.red)) : null,
      ),
      onChanged: onChanged,
    );
  }

  Widget _weightsPanel(Strings t, Map<String, Map<String, dynamic>> byKey) {
    final present = _weights.where(byKey.containsKey).toList();
    double value(String k) => double.tryParse(_edits[k] ?? '') ?? (byKey[k]!['value'] as num).toDouble();
    final values = {for (final k in present) k: value(k)};
    final total = values.values.fold<double>(0, (a, b) => a + b);
    final maxW = values.values.fold<double>(1, (a, b) => b > a ? b : a);
    final ok = (total - 100).abs() < 0.001;
    final allNumbers = present.every((k) => _edits[k] == null || double.tryParse(_edits[k]!) != null);
    final dirty = present.any((k) => _edits[k] != null && (value(k) - (byKey[k]!['value'] as num)).abs() > 1e-9);
    final canSave = ok && allNumbers && dirty && _busy == null;
    final save = _saveBtn(canSave && _last == _weightsKey, t('action.save'), canSave ? () => _save(_weightsKey, values) : null);
    final error = _errors[_weightsKey];

    return Panel(
      title: t('settings.weightsTitle'),
      sub: t('settings.mustTotal'),
      trailing: Caps(t('settings.points')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final k in present)
          Container(
            height: 45,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Tok.lineSoft))),
            child: Row(children: [
              SizedBox(width: 126, child: Text(t('settings.k.$k'), style: Tok.emph.copyWith(fontWeight: FontWeight.w600))),
              Expanded(child: ProgressBar((values[k]! / maxW).clamp(0, 1).toDouble())),
              const SizedBox(width: 14),
              SizedBox(width: 60, child: _box(k, fmt.ratio(byKey[k]!['value']), '', _edits[k] != null && double.tryParse(_edits[k]!) == null, (v) => _edit(k, _weightsKey, v), byKey[k]!['value'])),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(t('settings.share'), style: Tok.sub)),
          Text(t('settings.pointsN', {'n': fmt.ratio(total)}), style: Tok.sub),
        ]),
        const SizedBox(height: 6),
        // Stacked share of the score: every weight is a teal segment, its points printed on it.
        Row(children: [
          for (final (i, k) in present.indexed)
            if (values[k]! > 0)
              Expanded(
                flex: (values[k]! * 10).round(),
                child: Container(
                  height: 22,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == 0 ? Tok.tealDark : Tok.teal, borderRadius: BorderRadius.circular(4)),
                  child: Text(fmt.ratio(values[k]), style: Tok.caps.copyWith(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0)),
                ),
              ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 18, runSpacing: 4, children: [
          for (final k in present)
            SizedBox(
              width: 132,
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Expanded(child: Text(t('settings.k.$k'), style: Tok.sub, overflow: TextOverflow.ellipsis)),
                Text(fmt.ratio(values[k]), style: Tok.sub.copyWith(fontWeight: FontWeight.w600, color: Tok.ink)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: ok ? Tok.inset : Tok.redTint,
            borderRadius: BorderRadius.circular(Tok.rCard),
            border: Border.all(color: ok ? Tok.lineInset : Tok.redLine),
          ),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_outline : Ico.alert, size: 16, color: ok ? Tok.tealDark : Tok.red),
            const SizedBox(width: 8),
            Expanded(
              child: ok
                  ? Text.rich(TextSpan(children: [
                      TextSpan(text: t('settings.total', {'n': fmt.ratio(total)}), style: Tok.emph.copyWith(fontWeight: FontWeight.w600, color: Tok.tealDark)),
                      TextSpan(text: '  ${t(dirty ? 'settings.unsaved' : 'settings.noChanges')}', style: Tok.sub),
                    ]))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('settings.total', {'n': fmt.ratio(total)}), style: Tok.emph.copyWith(fontWeight: FontWeight.w600, color: Tok.red)),
                      Text(t('settings.totalBad'), style: Tok.sub.copyWith(color: Tok.ink)),
                    ]),
            ),
            const SizedBox(width: 8),
            save,
          ]),
        ),
        if (error != null) ...[const SizedBox(height: 8), _status(Icons.error_outline, error, Tok.red)],
        if (_saved == _weightsKey) ...[const SizedBox(height: 8), _status(Icons.check_circle_outline, t('settings.savedRow'), Tok.tealDark)],
      ]),
    );
  }
}
