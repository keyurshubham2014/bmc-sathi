import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'flag_detail.dart';

/// The four tabs: (key, flag type, tier, URL slug). Routes use the slug (/flags/double-billing/WO25-02461);
/// API type names in older links (/flags/duplicate/...) still resolve.
const flagTabs = [
  ('overbilled', 'overbilled', 'flag', 'over-billed'),
  ('duplicate', 'duplicate', 'flag', 'double-billing'),
  ('dlp', 'dlp', 'flag', 'dlp'),
  ('watch', 'overbilled', 'watch', 'watch'),
];

int _tabOf(String slug) {
  final i = flagTabs.indexWhere((x) => x.$4 == slug || (x.$3 == 'flag' && x.$2 == slug));
  return i < 0 ? 0 : i;
}

typedef FlagQuery = ({String type, String tier, String? decision, String? ward});

final flagsProvider = FutureProvider.family<Map<String, dynamic>, FlagQuery>((ref, q) =>
    apiGet(ref, '/flags', {'type': q.type, 'tier': q.tier, 'decision': q.decision, 'ward_code': q.ward, 'limit': 200}));

final flagSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, ward) async =>
    List<Map<String, dynamic>>.from((await apiGet(ref, '/flags/summary', {'ward_code': ward}))['items']));

/// Queue filters live outside the page so they survive opening and closing a flag (each is its own route).
/// contractor '' = all.
typedef _Ui = ({int tab, String decision, String contractor, String search});

class _UiCtrl extends Notifier<_Ui> {
  @override
  _Ui build() => (tab: 0, decision: 'open', contractor: '', search: '');
  void upd({int? tab, String? decision, String? contractor, String? search}) => state = (
        tab: tab ?? state.tab,
        decision: decision ?? state.decision,
        contractor: contractor ?? state.contractor,
        search: search ?? state.search,
      );
}

final _uiProvider = NotifierProvider<_UiCtrl, _Ui>(_UiCtrl.new);

/// One plain sentence saying what the data shows, built from the evidence so it reads the same every time.
String flagReason(Strings t, Map<String, dynamic> f) {
  final e = Map<String, dynamic>.from(f['evidence']);
  if (f['tier'] == 'watch') return t('flags.reason.watch', {'ratio': fmt.ratio(e['ratio'])});
  return switch (f['flag_type']) {
    'overbilled' => t('flags.reason.overbilled', {'ratio': fmt.ratio(e['ratio']), 'method': e['method']}),
    'duplicate' => t('flags.reason.duplicate', {'earlier': e['earlier_work_order_id'], 'days': fmt.ratio(e['days_apart'])}),
    _ => t('flags.reason.dlp'),
  };
}

/// Contractor name as stored, with the "(synthetic)" tail in grey.
Widget contractorText(String name, {TextStyle? style}) {
  const tail = ' (synthetic)';
  if (!name.endsWith(tail)) return Text(name, style: style);
  return Text.rich(TextSpan(style: style, children: [
    TextSpan(text: name.substring(0, name.length - tail.length)),
    const TextSpan(text: tail, style: TextStyle(color: Tok.text3, fontWeight: FontWeight.w400)),
  ]));
}

/// /flags shows the queue; /flags/:slug/:id ([slug], [id]) shows the queue with that flag in the right panel.
class FlagQueueScreen extends ConsumerStatefulWidget {
  const FlagQueueScreen({super.key, this.slug, this.id});
  final String? slug, id;
  @override
  ConsumerState<FlagQueueScreen> createState() => _QueueState();
}

class _QueueState extends ConsumerState<FlagQueueScreen> {
  late final _search = TextEditingController(text: ref.read(_uiProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider)!;
    final ui = ref.watch(_uiProvider);
    final uiCtl = ref.read(_uiProvider.notifier);
    // An officer is always limited to their ward by the server; an auditor may arrive filtered from a ward page.
    final ward = session.isOfficer ? session.wardCode : GoRouterState.of(context).uri.queryParameters['ward'];
    final tab = widget.slug == null ? ui.tab : _tabOf(widget.slug!);
    final (key, type, tier, slug) = flagTabs[tab];
    final watch = tier == 'watch';
    final query = (type: type, tier: tier, decision: null, ward: ward);
    final summary = ref.watch(flagSummaryProvider(ward)).value ?? const [];

    num agg(bool Function(Map<String, dynamic>) where, String field) =>
        summary.where(where).fold<num>(0, (a, s) => a + (s[field] as num));
    num tabOpen(int i) => agg((s) => s['flag_type'] == flagTabs[i].$2 && s['tier'] == flagTabs[i].$3 && s['decision'] == 'open', 'count');
    final openAll = agg((s) => s['decision'] == 'open', 'count');

    String withWard(String path) => session.isOfficer || ward == null ? path : '$path?ward=$ward';
    void close() {
      uiCtl.upd(tab: tab);
      context.go(withWard('/flags'));
    }

    void switchTab(int i) {
      uiCtl.upd(tab: i);
      if (widget.id != null) context.go(withWard('/flags'));
    }

    final stats = Panel(
      title: t('flags.review'),
      child: StatRow(children: [
        StatBlock(
          icon: Ico.flag,
          label: t('flags.stat.open'),
          value: fmt.count(openAll),
          unit: t('flags.stat.openUnit'),
          sub: t('flags.stat.openSub'),
        ),
        StatBlock(
          icon: Ico.alert,
          label: t('flags.stat.amount'),
          value: fmt.money(agg((s) => s['decision'] == 'open', 'amount')),
          unit: t('flags.stat.amountUnit'),
          tone: StatTone.amber,
          subLead: t('flags.stat.amountLead'),
          sub: t('flags.stat.amountSub', {'n': fmt.count(openAll)}),
        ),
        StatBlock(
          icon: Ico.check,
          label: t('flags.stat.decided'),
          value: fmt.count(agg((s) => s['decision'] != 'open', 'count')),
          unit: t('flags.stat.decidedUnit'),
          sub: t('flags.stat.decidedSub'),
        ),
      ]),
    );

    Widget table(List<Map<String, dynamic>> rows) {
      final sel = rows.indexWhere((f) => f['work_order_id'] == widget.id);
      return WorksTable(
        columns: [
          WorksColumn(t('flags.col.wo'), width: 112),
          WorksColumn(t('flags.col.road'), flex: 4),
          WorksColumn(t('flags.col.contractor'), flex: 4),
          WorksColumn(t('flags.atStake'), width: 96, numeric: true),
          WorksColumn(t('flags.col.reason'), flex: 6),
          WorksColumn(t('flags.col.decision'), width: 172),
        ],
        selected: sel < 0 ? null : sel,
        onRowTap: (i) {
          uiCtl.upd(tab: tab);
          context.go(withWard('/flags/$slug/${rows[i]['work_order_id']}'));
        },
        rows: [
          for (final (i, f) in rows.indexed)
            [
              Text('${f['work_order_id']}', style: Tok.body.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w600)),
              Text('${f['road_name']}', style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
              contractorText('${f['contractor_name']}'),
              Text(fmt.rupees(f['amount_at_stake'])),
              Text(flagReason(t, f), style: Tok.sub.copyWith(fontSize: 12.5, height: 18 / 12.5)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                DecisionChip(watch ? 'watch' : '${f['decision']}'),
                if (i == sel) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t('flags.openInPanel'), style: Tok.sub.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 5),
                    const Icon(Ico.arrowRight, size: 12, color: Tok.tealDark),
                  ]),
                ] else if (f['decided_at'] != null) ...[
                  const SizedBox(height: 5),
                  Text(t('flags.decidedOn', {'when': fmt.date(f['decided_at'])}), style: Tok.sub),
                ],
              ]),
            ],
        ],
      );
    }

    final list = AsyncView(
      value: ref.watch(flagsProvider(query)),
      onRetry: () => ref.invalidate(flagsProvider(query)),
      lines: 8,
      builder: (data) {
        var items = List<Map<String, dynamic>>.from(data['items']);
        final contractors = {for (final f in items) '${f['contractor_name']}'}.toList()..sort();
        final q = ui.search.trim().toLowerCase();
        items = items
            .where((f) =>
                (ui.contractor.isEmpty || f['contractor_name'] == ui.contractor) &&
                (q.isEmpty || '${f['work_order_id']} ${f['road_name']}'.toLowerCase().contains(q)))
            .toList();
        final open = items.where((f) => f['decision'] == 'open').toList();
        final decided = items.where((f) => f['decision'] != 'open').toList();
        final shown = watch ? items : switch (ui.decision) {'decided' => decided, 'all' => items, _ => open};
        final showDecided = !watch && ui.decision == 'open' && decided.isNotEmpty;
        final next = (tab + 1) % flagTabs.length;
        final sub = Tok.sub.copyWith(fontSize: 12.5, height: 18 / 12.5);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _Menu(
              label: t('flags.filter.contractor'),
              value: ui.contractor.isEmpty ? t('flags.filter.all') : ui.contractor,
              options: [('', t('flags.filter.all')), for (final c in contractors) (c, c)],
              onSelected: (v) => uiCtl.upd(contractor: v),
            ),
            const SizedBox(width: 8),
            _Menu(
              label: t('flags.filter.decision'),
              value: watch ? t('flags.filter.notUsed') : t('flags.filter.${ui.decision}'),
              options: watch ? null : [for (final k in ['open', 'decided', 'all']) (k, t('flags.filter.$k'))],
              onSelected: (v) => uiCtl.upd(decision: v),
            ),
            const Spacer(),
            SizedBox(
              width: 230,
              child: TextField(
                controller: _search,
                onChanged: (v) => uiCtl.upd(search: v),
                style: Tok.body,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Tok.panel,
                  hintText: t('flags.search'),
                  hintStyle: Tok.body.copyWith(color: Tok.text3),
                  prefixIcon: const Icon(Ico.search, size: 15, color: Tok.text3),
                  prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.teal, width: 2)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (shown.isEmpty) EmptyState(t('flags.empty')) else table(shown),
          if (showDecided) ...[
            const SizedBox(height: 14),
            Row(children: [
              Caps(t('flags.decidedHere')),
              const SizedBox(width: 10),
              Text(t('flags.nDecided', {'n': decided.length}), style: Tok.sub),
              const SizedBox(width: 10),
              const Expanded(child: Divider(height: 1, color: Tok.line)),
            ]),
            const SizedBox(height: 8),
            table(decided),
          ],
          const SizedBox(height: 28),
          Column(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(10), border: Border.all(color: Tok.lineInset)),
              child: const Icon(Ico.check, size: 16, color: Tok.text2),
            ),
            const SizedBox(height: 10),
            Text(t('flags.end.title'), style: Tok.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              t(watch ? 'flags.end.watch' : 'flags.end.flag', {
                'open': open.length,
                'decided': decided.length,
                'rest': fmt.count(openAll - tabOpen(tab)),
              }),
              style: sub,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            AppButton.outlined(
              t('flags.next', {'tab': t('flags.tab.${flagTabs[next].$1}'), 'n': fmt.count(tabOpen(next))}),
              trailingIcon: Ico.arrowRight,
              onPressed: () => switchTab(next),
            ),
          ]),
          const SizedBox(height: 28),
          InsetCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: Tok.line)),
                child: const Icon(Ico.reopened, size: 16, color: Tok.text2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('flags.how.title'), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(t('flags.how.$key'), style: sub),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Text(t('flags.foot.count', {'open': open.length, 'decided': decided.length}), style: sub),
              const Spacer(),
              Text(t('flags.foot.sort'), style: sub),
            ]),
          ),
        ]);
      },
    );

    final queue = Panel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedTabs<int>(
            items: [for (final (i, x) in flagTabs.indexed) TabItem(i, t('flags.tab.${x.$1}'), count: tabOpen(i).toInt())],
            value: tab,
            onChanged: switchTab,
          ),
        ),
        const SizedBox(height: 10),
        list,
      ]),
    );

    // shortcut: always the 1440 desktop layout (queue + 440 px panel); add a narrow single-column layout if phones matter.
    return SetTopBar(
      title: t('flags.title'),
      titleSuffix: ward == null ? null : t('ward.label', {'code': ward}),
      child: DetailPanelLayout(
        main: PageBody(children: [stats, queue]),
        panel: widget.id == null ? null : FlagDetail(type, widget.id!, watch: watch, onClose: close, key: ValueKey((type, widget.id))),
        onClose: close,
      ),
    );
  }
}

/// Outlined "Label: Value ⌄" filter button with a menu. [options] null = disabled (grey).
class _Menu extends StatelessWidget {
  const _Menu({required this.label, required this.value, required this.options, required this.onSelected});
  final String label, value;
  final List<(String, String)>? options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final off = options == null;
    final box = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: off ? Tok.inset : Tok.panel,
        borderRadius: BorderRadius.circular(Tok.rControl),
        border: Border.all(color: Tok.line),
        boxShadow: off ? null : Tok.shadowControl,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Tok.body.copyWith(color: Tok.text2)),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(value, overflow: TextOverflow.ellipsis, style: Tok.body.copyWith(fontWeight: FontWeight.w500, color: off ? Tok.text2 : Tok.ink)),
        ),
        const SizedBox(width: 6),
        const Icon(Ico.chevronDown, size: 13, color: Tok.text3),
      ]),
    );
    if (off) return box;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final (v, l) in options!) PopupMenuItem(value: v, child: Text(l, style: Tok.body))],
      child: box,
    );
  }
}
