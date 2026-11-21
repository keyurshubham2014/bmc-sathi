import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

// Reads the client instead of watching it: saving a record refreshes every other figure in the app,
// and the form (with its result) must survive that.
final intakeOptionsProvider = FutureProvider<Map<String, dynamic>>(
    (ref) async => Map<String, dynamic>.from((await ref.read(dioProvider).get('/intake/options')).data));

// The channels found in the complaint data; the API defaults to a walk-in.
const _channels = ['Ward Office Walk-in', '1916 Helpline', 'MyBMC App', 'MyBMC Web Portal'];

/// A ward officer types in a new work order or complaint; the live rules judge it at once.
class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});
  @override
  ConsumerState<IntakeScreen> createState() => _IntakeState();
}

class _IntakeState extends ConsumerState<IntakeScreen> {
  String _tab = 'wo';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final ward = ref.watch(sessionProvider)?.wardCode ?? 'E';
    return SetTopBar(
      title: t('intake.title'),
      titleSuffix: t('ward.label', {'code': ward}),
      child: AsyncView(
        value: ref.watch(intakeOptionsProvider),
        onRetry: () => ref.invalidate(intakeOptionsProvider),
        lines: 8,
        builder: (o) => PageBody(children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeader(t('intake.title')),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('intake.lede', {'ward': ward}), style: Tok.nav.copyWith(color: Tok.text2)),
                    const SizedBox(height: 12),
                    SegmentedTabs<String>(
                      items: [for (final k in ['wo', 'complaint']) TabItem(k, t('intake.tab.$k'))],
                      value: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Pill(t('intake.scope'), tone: Tone.info, icon: Icons.lock_outline),
              ]),
            ]),
          ),
          if (_tab == 'wo') _WorkOrderForm(o, ward) else _ComplaintForm(o, ward),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------
// Form pieces
// ---------------------------------------------------------------------------------------------------

/// Caps label with a rule running to the right, between form sections.
Widget _section(String label, {bool first = false}) => Padding(
      padding: EdgeInsets.only(top: first ? 0 : 20, bottom: 12),
      child: Row(children: [Caps(label), const SizedBox(width: 10), const Expanded(child: Divider(color: Tok.lineInset))]),
    );

/// Label above the control, as on the board.
Widget _field(String label, Widget control, {Widget? trailing}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: Tok.body.copyWith(fontWeight: FontWeight.w500, height: 18 / 13))),
            ?trailing,
          ]),
        ),
        control,
      ],
    );

final _inputText = Tok.emph.copyWith(fontWeight: FontWeight.w400);

Widget _pick(String label, String? value, Map<String, String> items, ValueChanged<String?> onChanged, {String? help}) => _field(
      label,
      DropdownButtonFormField<String>(
        key: ValueKey('$label-$value-${items.length}'),
        initialValue: value,
        isExpanded: true,
        style: _inputText,
        icon: const Icon(Ico.chevronDown, size: 16, color: Tok.text3),
        decoration: InputDecoration(helperText: help),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    );

/// Runs a save, reporting failures in the form.
mixin _Submit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  // True right after a save, until the form is edited again: the button then reads "Saved".
  bool fresh = false;
  String? error;
  Map<String, dynamic>? result;

  void edited() => setState(() => fresh = false);

  Future<void> submit(String path, Map<String, dynamic> body) async {
    final t = ref.read(stringsProvider);
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final res = await ref.read(dioProvider).post(path, data: body);
      // Every figure in the app may have moved.
      ref.invalidate(dioProvider);
      if (mounted) {
        setState(() {
          result = Map<String, dynamic>.from(res.data);
          fresh = true;
        });
      }
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => error = err.code == 'network' ? t('err.network') : err.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Save (or "Saved"), Clear form, and who saved what; the error line below.
  Widget footer({required bool ready, required VoidCallback onSave, required VoidCallback onClear, String? savedId}) {
    final t = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (fresh)
            Semantics(
              label: t('intake.savedBtn'),
              child: Container(
                height: Tok.controlH,
                padding: const EdgeInsets.fromLTRB(13, 0, 16, 0),
                decoration: BoxDecoration(
                  color: Tok.tealTint,
                  borderRadius: BorderRadius.circular(Tok.rControl),
                  border: Border.all(color: Tok.tealLine),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Ico.check, size: 14, color: Tok.tealDark),
                  const SizedBox(width: 7),
                  Text(t('intake.savedBtn'), style: Tok.body.copyWith(fontWeight: FontWeight.w600, color: Tok.tealDark)),
                ]),
              ),
            )
          else
            AppButton.primary(t('intake.submit'), icon: Ico.check, onPressed: busy || !ready ? null : onSave),
          const SizedBox(width: 8),
          AppButton.quiet(t('intake.clear'), trailingIcon: null, onPressed: busy ? null : onClear),
          const Spacer(),
          if (savedId != null)
            Text(t('intake.savedBy', {'id': savedId, 'name': ref.watch(sessionProvider)?.name ?? ''}), style: Tok.sub),
        ]),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: Tok.red),
                const SizedBox(width: 6),
                Expanded(child: Text(error!, style: Tok.body.copyWith(color: Tok.red))),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Form panel on the left (3), result column on the right (2).
Widget _split(Widget form, List<Widget> side) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 3, child: form),
      const SizedBox(width: Tok.gapPanels),
      Expanded(
        flex: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in side.indexed) ...[if (i > 0) const SizedBox(height: Tok.gapPanels), w],
        ]),
      ),
    ]);

// ---------------------------------------------------------------------------------------------------
// Result pieces
// ---------------------------------------------------------------------------------------------------

/// Teal-headed "Saved: id" panel.
class _SavedPanel extends StatelessWidget {
  const _SavedPanel({required this.title, required this.sub, required this.children});
  final String title, sub;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Tok.panel,
          borderRadius: BorderRadius.circular(Tok.rPanel),
          border: Border.all(color: Tok.tealLine),
          boxShadow: Tok.shadowPanel,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: Tok.tealTint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(Tok.rPanel - 1)),
              border: Border(bottom: BorderSide(color: Tok.tealLine)),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Tok.teal, shape: BoxShape.circle),
                child: const Icon(Ico.check, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Tok.section),
                  const SizedBox(height: 1),
                  Text(sub, style: Tok.sub.copyWith(fontSize: 12.5, color: const Color(0xFF3F454C))),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ]),
      );
}

/// Bordered grid of caps label, value and sub-line; one list per row.
Widget _facts(List<List<(String, String, String?)>> rows) => Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.line)),
      child: Column(children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, color: Tok.lineInset),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (j, (label, value, sub)) in row.indexed) ...[
                if (j > 0) const VerticalDivider(width: 1, color: Tok.lineInset),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Caps(label),
                      const SizedBox(height: 3),
                      Text(value, style: Tok.body.copyWith(fontWeight: FontWeight.w500, height: 18 / 13)),
                      if (sub != null) Text(sub, style: Tok.sub.copyWith(fontSize: 12.5)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );

/// Teal text link with an arrow.
Widget _link(String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      radius: 6,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: Tok.tealDark)),
        const SizedBox(width: 5),
        const Icon(Ico.arrowRight, size: 13, color: Tok.tealDark),
      ]),
    );

/// Grey row: icon, text, link on the right.
Widget _linkRow(IconData icon, Widget text, Widget link) => Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.lineInset)),
      child: Row(children: [
        Icon(icon, size: 15, color: Tok.text3),
        const SizedBox(width: 10),
        Expanded(child: text),
        const SizedBox(width: 10),
        link,
      ]),
    );

/// Grey note with an info icon.
Widget _note(String text) => InsetCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.line)),
          child: const Icon(Ico.info, size: 16, color: Tok.text2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Tok.sub.copyWith(fontSize: 12.5, height: 18 / 12.5))),
      ]),
    );

// ---------------------------------------------------------------------------------------------------
// Work order
// ---------------------------------------------------------------------------------------------------

class _WorkOrderForm extends ConsumerStatefulWidget {
  const _WorkOrderForm(this.o, this.ward);
  final Map<String, dynamic> o;
  final String ward;
  @override
  ConsumerState<_WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends ConsumerState<_WorkOrderForm> with _Submit {
  String? _road, _type, _method, _contractor;
  final _area = TextEditingController(), _cost = TextEditingController();

  @override
  void dispose() {
    _area.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _road = _type = _method = _contractor = null;
        _area.clear();
        _cost.clear();
        result = null;
        error = null;
        fresh = false;
      });

  void _set(VoidCallback f) {
    setState(f);
    edited();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final methods = List<Map<String, dynamic>>.from(widget.o['methods']);
    final roads = {for (final r in widget.o['roads']) '${r['road_id']}': Map<String, dynamic>.from(r)};
    final area = double.tryParse(_area.text), cost = int.tryParse(_cost.text);
    final m = methods.where((x) => x['work_type'] == _type && x['repair_method'] == _method).firstOrNull;
    final expected = m == null ? null : (m['unit'] == 'per sqm' ? (area == null ? null : (m['standard_rate_inr'] as num) * area) : m['standard_rate_inr'] as num);
    final ready = _road != null && m != null && _contractor != null && area != null && area > 0 && cost != null && cost > 0;
    final wo = result?['work_order'];
    final flags = List<Map<String, dynamic>>.from(result?['flags'] ?? const []);
    final road = roads[_road] ?? (wo == null ? null : roads['${wo['road_id']}']);
    String? positive(TextEditingController c) => c.text.isNotEmpty && !((num.tryParse(c.text) ?? 0) > 0) ? t('intake.positive') : null;

    final form = Panel(
      title: t('intake.tab.wo'),
      trailing: Text(ready ? t('intake.allFilled') : t('intake.required'), style: Tok.sub.copyWith(fontSize: 12.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        _section(t('intake.sec.where'), first: true),
        _pick(
          t('intake.road'),
          _road,
          {for (final r in roads.values) '${r['road_id']}': '${r['road_name']} · ${t('intake.segment', {'n': r['segment_no']})} (${r['road_id']})'},
          (v) => _set(() => _road = v),
          help: t('intake.roadHelp'),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _pick(t('intake.workType'), _type, {for (final x in methods) '${x['work_type']}': '${x['work_type']}'}, (v) => _set(() {
                  _type = v;
                  _method = null;
                })),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _pick(
              t('intake.method'),
              _method,
              {for (final x in methods.where((x) => x['work_type'] == _type)) '${x['repair_method']}': '${x['repair_method']}'},
              (v) => _set(() => _method = v),
              help: t('intake.methodHelp'),
            ),
          ),
        ]),
        _section(t('intake.sec.who')),
        _pick(t('intake.contractor'), _contractor, {for (final x in widget.o['contractors']) '${x['contractor_id']}': '${x['contractor_name']}'}, (v) => _set(() => _contractor = v)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _field(
              t('intake.area'),
              TextField(
                controller: _area,
                style: _inputText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(errorText: positive(_area), suffixText: 'sqm', suffixStyle: Tok.body.copyWith(color: Tok.text3)),
                onChanged: (_) => _set(() {}),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _field(
                t('intake.cost'),
                TextField(
                  controller: _cost,
                  style: _inputText,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(errorText: positive(_cost), prefixText: '₹  ', prefixStyle: _inputText.copyWith(color: Tok.text2)),
                  onChanged: (_) => _set(() {}),
                ),
              ),
              if (expected != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                  decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.lineInset)),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      cost == null || expected == 0
                          ? t('intake.rate', {'amount': fmt.money(expected)})
                          : t('intake.expectedLine', {'amount': fmt.rupees(expected), 'ratio': fmt.ratio(cost / expected)}),
                      style: Tok.body.copyWith(fontSize: 12.5),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
        footer(
          ready: ready,
          onClear: _clear,
          savedId: wo == null ? null : '${wo['work_order_id']}',
          onSave: () => submit('/intake/work-orders', {'road_id': _road, 'work_type': _type, 'repair_method': _method, 'contractor_id': _contractor, 'area_sqm': area, 'cost_inr': cost}),
        ),
      ]),
    );

    return _split(form, [
      if (road != null)
        Panel(
          padding: const EdgeInsets.all(6),
          child: InsetCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Caps(t('intake.chosenRoad')),
                  const SizedBox(height: 3),
                  Text('${road['road_name']}', style: Tok.cardTitle.copyWith(height: 19 / 15)),
                ]),
              ),
              SubCard(
                child: Row(children: [
                  Expanded(child: Text(t('intake.segment', {'n': road['segment_no']}), style: Tok.body.copyWith(fontWeight: FontWeight.w600))),
                  Text('${road['road_id']} · ${t('ward.label', {'code': widget.ward})}', style: Tok.body.copyWith(color: Tok.text2)),
                ]),
              ),
            ]),
          ),
        ),
      if (wo != null)
        _SavedPanel(
          title: t('intake.savedTitle', {'id': wo['work_order_id']}),
          sub: t('intake.woSavedSub', {'ward': widget.ward}),
          children: [
            _facts([
              [
                (t('intake.f.road'), '${wo['road_name']}', road == null ? '${wo['road_id']}' : '${t('intake.segment', {'n': road['segment_no']})} · ${wo['road_id']}'),
                (t('intake.f.work'), '${wo['work_type']}', t('wo.area', {'area': fmt.ratio(wo['area_sqm'])})),
              ],
              [
                (t('intake.f.contractor'), '${wo['contractor_name']}', null),
                (t('intake.f.cost'), fmt.rupees(wo['cost_inr']), t('intake.ofExpected', {'ratio': fmt.ratio(wo['cost_ratio'])})),
              ],
            ]),
            const SizedBox(height: 18),
            if (flags.isEmpty)
              Align(alignment: Alignment.centerLeft, child: Pill(t('intake.noFlags'), tone: Tone.success, icon: Ico.check))
            else ...[
              Row(children: [
                Caps(t('intake.flagsRaised')),
                const SizedBox(width: 8),
                Pill('${flags.length}', tone: Tone.flag),
                const Spacer(),
                Text(t('intake.unreviewed'), style: Tok.sub),
              ]),
              for (final f in flags) ...[const SizedBox(height: 8), _FlagCard(f, '${wo['work_order_id']}')],
            ],
            const SizedBox(height: 18),
            Caps(t('intake.alsoUpdated')),
            const SizedBox(height: 8),
            _linkRow(
              Ico.receipt,
              Text.rich(TextSpan(style: Tok.body.copyWith(height: 18 / 13), children: [
                TextSpan(text: '${t('intake.spendUpdated', {'ward': widget.ward})} '),
                TextSpan(text: t('intake.seeMoney'), style: const TextStyle(color: Tok.text2)),
              ])),
              _link(t('intake.openWard'), () => context.goWard(widget.ward)),
            ),
            const SizedBox(height: 6),
            _linkRow(
              Ico.contractor,
              Text(t('intake.scoreUpdated'), style: Tok.body.copyWith(height: 18 / 13)),
              _link(t('intake.openScorecard'), () => context.go('/contractors/${wo['contractor_id']}')),
            ),
            const SizedBox(height: 16),
            Pressable(
              onTap: () => context.go('/trail/work-order/${wo['work_order_id']}'),
              builder: (_, hover) => Container(
                height: Tok.inputH,
                padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
                decoration: BoxDecoration(
                  color: hover ? Tok.inset : Tok.panel,
                  borderRadius: BorderRadius.circular(Tok.rControl),
                  border: Border.all(color: Tok.line),
                  boxShadow: Tok.shadowControl,
                ),
                child: Row(children: [
                  const Icon(Ico.trail, size: 15, color: Tok.tealDark),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(t('intake.openTrailFor', {'id': wo['work_order_id']}),
                        style: Tok.body.copyWith(fontWeight: FontWeight.w600, color: Tok.tealDark)),
                  ),
                  const Icon(Ico.arrowRight, size: 13, color: Tok.tealDark),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.quiet(
                t('intake.undo'),
                icon: Icons.undo,
                trailingIcon: null,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(dioProvider).delete('/intake/work-orders/${wo['work_order_id']}');
                  ref.invalidate(dioProvider);
                  if (mounted) {
                    setState(() {
                      result = null;
                      fresh = false;
                    });
                  }
                  messenger.showSnackBar(SnackBar(content: Text(t('intake.removed'))));
                },
              ),
            ),
          ],
        ),
      _note(t('intake.woNote')),
    ]);
  }
}

/// Amber card for one flag raised on save: what, how much, and a way to the evidence.
class _FlagCard extends ConsumerWidget {
  const _FlagCard(this.f, this.woId);
  final Map<String, dynamic> f;
  final String woId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final isFlag = f['tier'] == 'flag';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Tok.amberFill, borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.amberLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Ico.flag, size: 15, color: Tok.amberIcon)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('flags.tab.${isFlag ? f['flag_type'] : 'watch'}'),
                  style: Tok.emph.copyWith(fontWeight: FontWeight.w600, color: Tok.amberText, height: 19 / 14)),
              const SizedBox(height: 2),
              Text(t('intake.atStake', {'amount': fmt.money(f['amount_at_stake'])}), style: Tok.body.copyWith(color: Tok.amberText, height: 18 / 13)),
            ]),
          ),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Tok.amberNode)),
        Row(children: [
          Expanded(child: Text(t('intake.prompt'), style: Tok.sub.copyWith(color: Tok.amberText))),
          if (isFlag)
            Pressable(
              onTap: () => context.go('/flags/${f['flag_type']}/$woId'),
              radius: 9,
              builder: (_, hover) => Container(
                height: 30,
                padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
                decoration: BoxDecoration(
                  color: hover ? Tok.amberFill : Tok.panel,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Tok.amberNode),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('intake.openFlag'), style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tok.amberText)),
                  const SizedBox(width: 6),
                  const Icon(Ico.arrowRight, size: 13, color: Tok.amberText),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------
// Complaint
// ---------------------------------------------------------------------------------------------------

class _ComplaintForm extends ConsumerStatefulWidget {
  const _ComplaintForm(this.o, this.ward);
  final Map<String, dynamic> o;
  final String ward;
  @override
  ConsumerState<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends ConsumerState<_ComplaintForm> with _Submit {
  static const _maxText = 1000;
  String? _category;
  String _channel = _channels.first;
  final _locality = TextEditingController(), _text = TextEditingController();

  @override
  void dispose() {
    _locality.dispose();
    _text.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _category = null;
        _channel = _channels.first;
        _locality.clear();
        _text.clear();
        result = null;
        error = null;
        fresh = false;
      });

  void _set(VoidCallback f) {
    setState(f);
    edited();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final len = _text.text.trim().length;
    final ready = _category != null && len >= 5;
    final r = result;
    final c = r == null ? null : Map<String, dynamic>.from(r['complaint']);
    final issue = r == null ? null : Map<String, dynamic>.from(r['issue']);
    final joined = r?['joined_existing'] == true;

    final form = Panel(
      title: t('intake.tab.complaint'),
      trailing: Text(ready ? t('intake.allFilled') : t('intake.required'), style: Tok.sub.copyWith(fontSize: 12.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        _section(t('intake.sec.reported'), first: true),
        _field(
          t('intake.description'),
          trailing: Text(t('intake.counter', {'n': _text.text.length, 'max': _maxText}), style: Tok.sub.copyWith(fontSize: 12.5)),
          TextField(
            controller: _text,
            style: _inputText,
            maxLength: _maxText,
            minLines: 5,
            maxLines: 5,
            decoration: InputDecoration(
              counterText: '',
              helperText: t('intake.descHelp'),
              errorText: len > 0 && len < 5 ? t('intake.minChars') : null,
            ),
            onChanged: (_) => _set(() {}),
          ),
        ),
        const SizedBox(height: 16),
        _pick(t('intake.category'), _category, {for (final x in widget.o['categories']) '$x': '$x'}, (v) => _set(() => _category = v)),
        _section(t('intake.sec.place')),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _field(
              t('intake.locality'),
              TextField(
                controller: _locality,
                style: _inputText,
                maxLength: 120,
                decoration: InputDecoration(
                  counterText: '',
                  helperText: t('intake.localityHelp'),
                  prefixIcon: const Icon(Ico.search, size: 15),
                  prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                ),
                onChanged: (_) => edited(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _field(
              t('intake.ward'),
              TextFormField(
                initialValue: t('ward.label', {'code': widget.ward}),
                enabled: false,
                style: _inputText.copyWith(color: Tok.text2),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Tok.inset,
                  helperText: t('intake.wardHelp'),
                  suffixIcon: const Icon(Icons.lock_outline, size: 15, color: Tok.text3),
                ),
              ),
            ),
          ),
        ]),
        _section(t('intake.sec.channel')),
        _pick(t('intake.channel'), _channel, {for (final x in _channels) x: x}, (v) => _set(() => _channel = v ?? _channels.first), help: _channels.join(', ')),
        footer(
          ready: ready,
          onClear: _clear,
          savedId: c == null ? null : '${c['complaint_id']}',
          onSave: () => submit('/intake/complaints', {
            'description': _text.text.trim(),
            'category_reported': _category,
            'channel': _channel,
            if (_locality.text.trim().isNotEmpty) 'locality_text': _locality.text.trim(),
          }),
        ),
      ]),
    );

    final road = r?['road'];
    return _split(form, [
      if (c != null && issue != null)
        _SavedPanel(
          title: t('intake.savedTitle', {'id': c['complaint_id']}),
          sub: t('intake.cSavedSub', {'ward': widget.ward}),
          children: [
            _facts([
              [
                (t('intake.f.category'), '${c['category_reported']}', null),
                (t('intake.f.locality'), '${c['locality_text'] ?? '–'}', null),
                (t('intake.f.channel'), '${c['channel']}', null),
              ],
              [(t('intake.f.desc'), '${c['description']}', null)],
            ]),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.call_merge, size: 15, color: Tok.tealDark),
              const SizedBox(width: 8),
              Expanded(child: Text(t(joined ? 'intake.joinedTitle' : 'intake.newTitle'), style: Tok.emph.copyWith(fontWeight: FontWeight.w600))),
              if (joined) Text(t('intake.noNewIssue'), style: Tok.sub),
            ]),
            const SizedBox(height: 8),
            _linkRow(
              Ico.trail,
              Text.rich(TextSpan(style: Tok.body.copyWith(height: 18 / 13), children: [
                TextSpan(text: '${issue['category']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' · ${road == null ? '–' : road['road_name']} · ${t('plan.complaints', {'n': issue['complaint_count']})}'),
              ])),
              _link(t('intake.openTrail'), () => context.go('/trail/issue/${issue['issue_id']}')),
            ),
            if (r!['plan'] != null) ...[
              const SizedBox(height: 10),
              Text(t('intake.rank', {'rank': r['plan']['rank'], 'score': (r['plan']['risk_score'] as num).round()}), style: Tok.body.copyWith(color: Tok.text2)),
            ],
          ],
        ),
      _note(t('intake.cNote')),
    ]);
  }
}
