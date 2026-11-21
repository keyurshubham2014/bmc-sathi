import 'dart:convert';

import 'package:bmc_sathi/core/app_state.dart';
import 'package:bmc_sathi/core/theme.dart';
import 'package:bmc_sathi/core/widgets.dart';
import 'package:bmc_sathi/features/flags/flag_queue.dart';
import 'package:bmc_sathi/features/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every shared component on one page inside the shell, at desktop width: catches layout errors.
class _Gallery extends StatelessWidget {
  const _Gallery();
  @override
  Widget build(BuildContext context) => SetTopBar(
    title: 'Ward E',
    titleSuffix: 'Byculla',
    onTitleTap: () {},
    action: AppButton.primary('Review 12 flags', icon: Ico.flag, onPressed: () {}),
    child: DetailPanelLayout(
      onClose: () {},
      panel: DetailPanel(
        eyebrow: 'Flag',
        eyebrowIcon: Ico.flag,
        title: 'Possible double billing',
        subtitle: 'WO25-02461',
        onClose: () {},
        footer: const Text('footer'),
        child: Column(
          children: [
            const RangeStrip(ratio: 1.7),
            EvidencePair(
              leftTitle: 'Earlier job',
              rightTitle: 'Second job',
              rightNote: '(flagged)',
              rows: const [
                EvidenceRow('Road', left: Text('Clare Road'), right: Text('Clare Road')),
                EvidenceRow('Cost', left: Text('₹62,186'), right: Text('₹64,531'), matches: false),
                EvidenceRow('Assigned', left: Text('29 Jul'), right: Text('2 Aug'), tag: '4 days apart', tagIcon: Ico.calendar),
              ],
            ),
          ],
        ),
      ),
      main: PageBody(
        children: [
          Panel(
            title: 'Ward overview',
            trailing: const Text('Last updated'),
            child: Column(
              children: const [
                StatRow(
                  children: [
                    StatBlock(label: 'Budget', value: '₹53.0 L', icon: Ico.budget, sub: '118 work orders'),
                    StatBlock(label: 'Over by', value: '₹10.2 L', tone: StatTone.red, subLead: 'Over budget', sub: 'past ₹53.0 L'),
                    StatBlock(label: 'In open flags', value: '₹7.3 L', tone: StatTone.amber, unit: 'at stake'),
                  ],
                ),
                MiniStat(icon: Ico.reopened, label: 'Re-opened in 30 days', value: '₹18.4 L', sub: '37 jobs'),
                BudgetBar(budget: 5300000, spent: 6320000),
                BudgetBar(budget: 5300000, spent: 4000000),
                ProgressBar(0.38),
                CompareBars(
                  caption: 'Re-opened',
                  bars: [CompareBar('This contractor', .39, '39%'), CompareBar('Similar jobs', .47, '47%', hatched: true)],
                ),
              ],
            ),
          ),
          InsetCard(
            child: SubCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const StatusPill('No DLP'),
                  const FlagPill('4 open flags'),
                  for (final d in ['open', 'needs_explanation', 'confirmed', 'not_an_issue', 'watch']) DecisionChip(d),
                  for (final b in ['well_above', 'above', 'similar', 'typical', 'below', 'well_below', 'too_few', 'review']) BandChip(b),
                  const Pill('Held', tone: Tone.success, icon: Ico.check),
                  AppButton.outlined('Filter', icon: Ico.filter, trailingIcon: Ico.chevronDown, onPressed: () {}),
                  AppButton.quiet('About the data', onPressed: () {}),
                  AppIconButton(Ico.more, tooltip: 'More', onPressed: () {}),
                  SegmentedTabs(
                    items: const [TabItem(0, 'Over-billed', count: 4), TabItem(1, 'Watch', count: 1)],
                    value: 0,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
          UnderlineTabs(items: const [TabItem('m', 'Money trail'), TabItem('f', 'Flags', count: 12)], value: 'm', onChanged: (_) {}),
          const TrailStepper(
            steps: [
              TrailStep('Complaints', 'None', node: TrailNode.missing),
              TrailStep('Issue', 'Choked drain'),
              TrailStep('Work order', '₹88,502'),
              TrailStep('Road', 'Bellasis Road'),
              TrailStep('Outcome', 'Re-opened', node: TrailNode.flagged),
            ],
          ),
          const BudgetLine('Budget runs out here', sub: '₹7.9 L left', above: 'Above: fits', below: 'Below: not funded yet'),
          WorksTable(
            columns: const [
              WorksColumn('Work order'),
              WorksColumn('Billed', numeric: true, sorted: true),
              WorksColumn('Decision', flex: 2),
            ],
            rows: const [
              [Text('WO25-00008'), Text('₹1,02,000'), DecisionChip('needs_explanation')],
              [Text('WO25-00056'), Text('₹64,531'), DecisionChip('open')],
            ],
            selected: 0,
            onRowTap: (_) {},
          ),
          const EmptyState('Nothing is waiting for a decision.', lead: 'No open flags on this road.'),
          const LoadingSkeleton(),
        ],
      ),
    ),
  );
}

Future<void> _loadFonts() async {
  // Real Geist metrics, so overflow checks match the browser.
  final geist = FontLoader('Geist');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    geist.addFont(rootBundle.load('assets/fonts/Geist-$w.ttf'));
  }
  final noto = FontLoader('NotoSansDevanagari')..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'));
  await Future.wait([geist.load(), noto.load()]);
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'session': jsonEncode(const Session(token: 't', name: 'R. Kulkarni', role: 'ward_officer', wardCode: 'E').toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        flagSummaryProvider.overrideWith(
          (ref, ward) async => [
            {'flag_type': 'overbilled', 'tier': 'flag', 'decision': 'open', 'count': 11},
            {'flag_type': 'overbilled', 'tier': 'watch', 'decision': 'open', 'count': 1},
            {'flag_type': 'dlp', 'tier': 'flag', 'decision': 'confirmed', 'count': 3},
          ],
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(SathiColors.light),
        home: const Shell(location: '/ward/E?tab=money', child: _Gallery()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('shell and every shared component lay out at desktop width', (tester) async {
    await _pumpShell(tester, const Size(1440, 1400));

    expect(tester.takeException(), isNull);
    expect(find.text('Ward E overview'), findsOneWidget);
    expect(find.text('12'), findsWidgets); // open flags badge from the summary, not hard-coded
    expect(find.text('Synthetic data'), findsOneWidget);
    expect(find.text('Review 12 flags'), findsOneWidget); // primary action set through SetTopBar
    expect(find.text('New record'), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);

    // showDetail opens the shell's right panel; closeDetail shuts it.
    showDetail(tester.element(find.byType(_Gallery)), title: 'About', child: const Text('panel body'));
    await tester.pumpAndSettle();
    expect(find.text('panel body'), findsOneWidget);
    closeDetail(tester.element(find.byType(_Gallery)));
    await tester.pumpAndSettle();
    expect(find.text('panel body'), findsNothing);
  });

  testWidgets('phone width: sidebar moves to a drawer, the detail panel covers the page', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('New record'), findsNothing); // sidebar is in the closed drawer
    expect(find.text('Synthetic data'), findsNothing);
    expect(find.text('Review 12 flags'), findsOneWidget); // page action on its own row

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('New record'), findsOneWidget);

    // About opens the detail panel and closes the drawer; the panel takes the page's place.
    await tester.tap(find.text('About the data').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New record'), findsNothing);
    expect(find.text('Possible double billing'), findsNothing); // page under the panel is offstage
  });
}
