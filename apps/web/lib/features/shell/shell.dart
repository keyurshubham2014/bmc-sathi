import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../flags/flag_queue.dart' show openFlagCount;

/// The app shell from 03-ward-money-trail.html: ground, one rounded shell, 232 px sidebar, content column
/// with the top bar. Pages set the top bar with `SetTopBar` and open the right panel with `showDetail`
/// or `DetailPanelLayout` (see widgets.dart).
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, required this.location, required this.child, this.notice});
  final String location;
  final Widget child;
  final String? notice;

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void didUpdateWidget(Shell old) {
    super.didUpdateWidget(old);
    // A panel opened with showDetail belongs to the page it was opened on.
    if (old.location == widget.location) return;
    Future.microtask(() {
      if (mounted) ref.read(detailProvider.notifier).close();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final t = ref.watch(stringsProvider);
    final nav = _nav(context, s);
    final selected = [
      for (final i in nav) ...[i, ...i.children],
    ].where((i) => i.selected).firstOrNull;
    final detail = ref.watch(detailProvider);
    void focusSearch() => _searchFocus.requestFocus();

    return Scaffold(
      backgroundColor: Tok.ground,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): focusSearch,
        },
        child: Focus(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Tok.shell,
                borderRadius: BorderRadius.circular(Tok.rShell),
                border: Border.all(color: Colors.white),
                boxShadow: Tok.shadowShell,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: Tok.sidebarW,
                    child: _Sidebar(nav: nav, search: _search, searchFocus: _searchFocus),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(fallbackTitle: selected?.label ?? t('app.name')),
                          const SizedBox(height: Tok.gapPanels),
                          if (widget.notice == 'notAllowed') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Tok.inset,
                                borderRadius: BorderRadius.circular(Tok.rCard),
                                border: Border.all(color: Tok.lineInset),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Ico.info, size: 15, color: Tok.text3),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(t('state.notAllowed'), style: Tok.body.copyWith(color: Tok.text2)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Tok.gapPanels),
                          ],
                          Expanded(
                            child: DetailPanelLayout(
                              main: widget.child,
                              onClose: ref.read(detailProvider.notifier).close,
                              panel: detail == null
                                  ? null
                                  : DetailPanel(
                                      title: detail.title,
                                      onClose: ref.read(detailProvider.notifier).close,
                                      scroll: false,
                                      child: detail.child,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Role differences as in DESIGN.md: officer sees New record and Flags; auditor sees City overview, Wards,
  /// Flags and Rule settings; citizens see no Flags.
  List<_Item> _nav(BuildContext context, Session s) {
    final t = ref.watch(stringsProvider);
    final uri = Uri.parse(widget.location);
    final path = uri.path;
    final onWard = path.startsWith('/ward/');
    final tab = uri.queryParameters['tab'] ?? 'money';
    final ward = onWard ? wardFromSlug(path.split('/')[2]) : (s.wardCode ?? 'E');
    final base = '/ward/${wardSlug(ward)}';
    final kids = [
      _Item(t('nav.moneyTrail'), Ico.budget, base, selected: onWard && tab == 'money'),
      _Item(t('nav.plan'), Icons.format_list_numbered, '$base?tab=plan', selected: onWard && tab == 'plan'),
      _Item(t('nav.scorecard'), Icons.fact_check_outlined, '$base?tab=scorecard', selected: onWard && tab == 'scorecard'),
    ];
    return [
      if (s.isAuditor) ...[
        _Item(t('nav.cityOverview'), Ico.home, '/city', selected: path.startsWith('/city')),
        _Item(t('nav.wards'), Ico.grid, base, children: onWard ? kids : const []),
      ] else
        _Item(t('nav.wardOverview', {'code': ward}), Ico.home, base, children: kids),
      if (s.canSeeFlags) _Item(t('nav.flags'), Ico.flag, '/flags', selected: path.startsWith('/flags'), badge: _openFlags(s)),
      _Item(t('nav.contractors'), Ico.contractor, '/contractors', selected: path.startsWith('/contractors')),
      _Item(t('nav.trail'), Ico.trail, '/trail', selected: path.startsWith('/trail')),
      if (s.isOfficer) _Item(t('nav.intake'), Ico.newRecord, '/intake', selected: path.startsWith('/intake')),
      if (s.isAuditor) _Item(t('nav.ruleSettings'), Ico.filter, '/settings', selected: path.startsWith('/settings')),
    ];
  }

  int? _openFlags(Session s) => openFlagCount(ref, s.isOfficer ? s.wardCode : null);
}

class _Item {
  const _Item(this.label, this.icon, this.path, {this.selected = false, this.badge, this.children = const []});
  final String label, path;
  final IconData icon;
  final bool selected;
  final int? badge;
  final List<_Item> children;
}

// ---------------------------------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------------------------------

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({required this.nav, required this.search, required this.searchFocus});
  final List<_Item> nav;
  final TextEditingController search;
  final FocusNode searchFocus;
  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  bool _expanded = true;

  void _info(String titleKey, String bodyKey) {
    final t = ref.read(stringsProvider);
    showDetail(
      context,
      title: t(titleKey),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        children: [
          Text(t(bodyKey), style: Tok.body.copyWith(color: Tok.text2)),
          const SizedBox(height: 12),
          Text(t('app.disclaimer'), style: Tok.sub),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget group(String key) => Padding(padding: const EdgeInsets.fromLTRB(10, 16, 10, 6), child: Caps(t(key)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 10, 14),
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // logo mark + name
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                  child: SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        const _LogoMark(),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(t('app.name'), style: Tok.pageTitle, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 7),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(t('app.module'), style: Tok.sub.copyWith(color: Tok.text3)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SearchField(controller: widget.search, focus: widget.searchFocus),
                group('nav.mainMenu'),
                for (final i in widget.nav) ...[
                  if (i.children.isEmpty)
                    _NavRow(i)
                  else ...[
                    _NavRow(i, parent: true, expanded: _expanded, onToggle: () => setState(() => _expanded = !_expanded)),
                    if (_expanded) _Tree(i.children),
                  ],
                ],
                group('nav.support'),
                _NavRow(_Item(t('nav.aboutData'), Ico.data, ''), onTap: () => _info('nav.aboutData', 'about.body')),
                _NavRow(_Item(t('nav.help'), Ico.question, ''), onTap: () => _info('nav.help', 'help.body')),
                const Spacer(),
                const SizedBox(height: 16),
                _PrototypeCard(onAbout: () => _info('nav.aboutData', 'about.body')),
                const SizedBox(height: 10),
                const _SettingsRow(),
                SizedBox(
                  height: 34,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Ico.darkMode, size: 16, color: Tok.text2),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(t('nav.darkMode'), style: Tok.nav.copyWith(color: Tok.text2)),
                        ),
                        _MiniSwitch(
                          value: dark,
                          label: t('nav.darkMode'),
                          onChanged: (v) => ref.read(themeModeProvider.notifier).set(v ? ThemeMode.dark : ThemeMode.light),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(7)),
    child: const CustomPaint(painter: _RoadMarkPainter()),
  );
}

/// Two road edges meeting in the distance with a centre line: a plain mark, not a civic emblem.
class _RoadMarkPainter extends CustomPainter {
  const _RoadMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(8, 20), const Offset(11.5, 6), p);
    canvas.drawLine(const Offset(18, 20), const Offset(14.5, 6), p);
    p
      ..strokeWidth = 1.7
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawLine(const Offset(13, 18.5), const Offset(13, 15.5), p);
    canvas.drawLine(const Offset(13, 12), const Offset(13, 9.5), p);
  }

  @override
  bool shouldRepaint(_RoadMarkPainter oldDelegate) => false;
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.controller, required this.focus});
  final TextEditingController controller;
  final FocusNode focus;
  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
      decoration: BoxDecoration(
        color: Tok.panel,
        borderRadius: BorderRadius.circular(Tok.rControl),
        border: Border.all(color: widget.focus.hasFocus ? Tok.teal : Tok.line),
        boxShadow: widget.focus.hasFocus
            ? const [BoxShadow(color: Tok.teal, spreadRadius: 4), BoxShadow(color: Colors.white, spreadRadius: 2)]
            : Tok.shadowControl,
      ),
      child: Row(
        children: [
          const Icon(Ico.search, size: 15, color: Tok.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focus,
              style: Tok.body,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: Tok.teal,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                constraints: const BoxConstraints(),
                hintText: t('nav.search'),
                hintStyle: Tok.body.copyWith(color: Tok.text3),
                semanticCounterText: '',
              ),
              onSubmitted: (v) {
                final q = v.trim();
                // shortcut: hands the text to Trail search as ?q=; the Trail screen decides what to do with it.
                context.go(q.isEmpty ? '/trail' : '/trail?q=${Uri.encodeQueryComponent(q)}');
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Tok.line),
            ),
            child: Text('Ctrl K', style: Tok.caps.copyWith(color: Tok.text2, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

/// One sidebar item. Selected = white raised pill, teal icon and label.
class _NavRow extends StatelessWidget {
  const _NavRow(this.item, {this.parent = false, this.expanded = true, this.onToggle, this.onTap});
  final _Item item;
  final bool parent, expanded;
  final VoidCallback? onToggle, onTap;

  @override
  Widget build(BuildContext context) {
    final sel = item.selected;
    final fg = sel ? Tok.tealDark : (parent ? Tok.ink : Tok.text2);
    return Pressable(
      onTap: onTap ?? () => context.go(item.path),
      radius: 9,
      selected: sel,
      semanticLabel: item.badge == null ? null : '${item.label}, ${item.badge}',
      builder: (_, hover) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? Tok.panel : (hover ? const Color(0x0815181B) : null),
          borderRadius: BorderRadius.circular(9),
          border: sel ? Border.all(color: Tok.line) : null,
          boxShadow: sel ? const [BoxShadow(color: Color(0x0F14181C), offset: Offset(0, 1), blurRadius: 2)] : null,
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 16, color: sel ? Tok.teal : fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: Tok.nav.copyWith(color: fg, fontWeight: sel ? FontWeight.w600 : (parent ? FontWeight.w500 : FontWeight.w400)),
              ),
            ),
            if (item.badge != null) CountBadge(item.badge!),
            if (parent)
              Pressable(
                onTap: onToggle,
                radius: 6,
                semanticLabel: MaterialLocalizations.of(context).expandedIconTapHint,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(expanded ? Ico.chevronDown : Ico.chevronRight, size: 14, color: Tok.text3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ward pages under the ward item, joined by a thin tree line. The selected page becomes the full-width pill.
class _Tree extends StatelessWidget {
  const _Tree(this.items);
  final List<_Item> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 4),
    child: Stack(
      children: [
        const Positioned(
          left: 18,
          top: 0,
          bottom: 0,
          child: SizedBox(width: 1, child: ColoredBox(color: Tok.treeLine)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, k) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 2),
              Pressable(
                onTap: () => context.go(k.path),
                radius: 9,
                selected: k.selected,
                builder: (_, hover) => Container(
                  height: k.selected ? 34 : 32,
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  decoration: k.selected
                      ? BoxDecoration(
                          color: Tok.panel,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Tok.line),
                          boxShadow: const [BoxShadow(color: Color(0x0F14181C), offset: Offset(0, 1), blurRadius: 2)],
                        )
                      : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: k.selected
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(k.icon, size: 16, color: Tok.teal),
                              )
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          k.label,
                          style: k.selected
                              ? Tok.nav.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w600)
                              : Tok.nav.copyWith(color: hover ? Tok.ink : Tok.text2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _PrototypeCard extends ConsumerWidget {
  const _PrototypeCard({required this.onAbout});
  final VoidCallback onAbout;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Tok.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Tok.line),
        boxShadow: const [BoxShadow(color: Color(0x0D14181C), offset: Offset(0, 1), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 58,
            color: Tok.tealTint,
            padding: const EdgeInsets.only(left: 12, top: 14),
            alignment: Alignment.topLeft,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Ico.synthetic, size: 16, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('sidebar.prototype'), style: Tok.nav.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(t('sidebar.prototypeBody'), style: Tok.sub),
                const SizedBox(height: 8),
                Pressable(
                  onTap: onAbout,
                  radius: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          t('nav.aboutData'),
                          style: Tok.sub.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: Tok.tealDark),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Ico.arrowRight, size: 13, color: Tok.tealDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Settings" opens the theme choice (System / Light / Dark), as the old theme button did.
class _SettingsRow extends ConsumerWidget {
  const _SettingsRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mode = ref.watch(themeModeProvider);
    return MenuAnchor(
      menuChildren: [
        for (final m in ThemeMode.values)
          MenuItemButton(
            onPressed: () => ref.read(themeModeProvider.notifier).set(m),
            trailingIcon: m == mode ? const Icon(Ico.check, size: 16) : null,
            child: Text('${t('theme.label')}: ${t('theme.${m.name}')}', style: Tok.body),
          ),
      ],
      builder: (context, ctl, _) => _NavRow(_Item(t('nav.settings'), Ico.settings, ''), onTap: () => ctl.isOpen ? ctl.close() : ctl.open()),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: Pressable(
      onTap: () => onChanged(!value),
      radius: Tok.rPill,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 18,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: value ? Tok.teal : Tok.neutralLine, borderRadius: BorderRadius.circular(Tok.rPill)),
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 2)],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.fallbackTitle});
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final spec = ref.watch(topBarProvider);
    final s = ref.watch(sessionProvider)!;

    Widget title;
    if (spec != null && spec.crumbs.isNotEmpty) {
      title = Row(
        children: [
          for (final (i, c) in spec.crumbs.indexed) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: Tok.pageTitle.copyWith(color: Tok.sep, fontWeight: FontWeight.w400),
                ),
              ),
            if (i < spec.crumbs.length - 1)
              Pressable(
                onTap: c.onTap,
                radius: 6,
                child: Text(
                  c.label,
                  style: Tok.pageTitle.copyWith(color: Tok.text2, fontWeight: FontWeight.w400),
                ),
              )
            else
              Flexible(
                child: Text(c.label, overflow: TextOverflow.ellipsis, style: Tok.pageTitle),
              ),
          ],
        ],
      );
    } else {
      title = Text.rich(
        TextSpan(
          style: Tok.pageTitle,
          children: [
            TextSpan(text: spec?.title ?? fallbackTitle),
            if (spec?.titleSuffix != null) ...[
              TextSpan(
                text: ' · ',
                style: Tok.pageTitle.copyWith(color: Tok.sep, fontWeight: FontWeight.w400),
              ),
              TextSpan(text: spec!.titleSuffix),
            ],
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
      if (spec?.onTitleTap != null) {
        title = Pressable(
          onTap: spec!.onTitleTap,
          radius: 7,
          semanticLabel: spec.titleTapLabel ?? t('topbar.changeWard'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: title),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Tok.panel,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Tok.line),
                ),
                child: const Icon(Ico.chevronDown, size: 14, color: Tok.text2),
              ),
            ],
          ),
        );
      }
    }

    return SizedBox(
      height: Tok.controlH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
        child: Row(
          children: [
            if (spec?.onBack != null) ...[
              // v2: 26 px back button, radius 8, grey 14 px chevron.
              Pressable(
                onTap: spec!.onBack,
                radius: 8,
                tooltip: t('action.back'),
                semanticLabel: t('action.back'),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Tok.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Tok.line),
                    boxShadow: Tok.shadowControl,
                  ),
                  child: const Icon(Ico.chevronLeft, size: 14, color: Tok.text2),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Align(alignment: Alignment.centerLeft, child: title),
              ),
            ),
            const SizedBox(width: 8),
            const SyntheticTag(),
            const SizedBox(width: 8),
            const LangToggle(),
            const SizedBox(width: 8),
            _AccountButton(s),
            if (spec?.action != null) ...[const SizedBox(width: 8), spec!.action!],
          ],
        ),
      ),
    );
  }
}

/// "EN | मराठी" segmented toggle.
class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: ref.watch(stringsProvider)('lang.label'),
    child: SegmentedTabs<String>(
      items: const [TabItem('en', 'EN'), TabItem('mr', 'मराठी')],
      value: ref.watch(langProvider),
      onChanged: ref.read(langProvider.notifier).set,
    ),
  );
}

/// System / light / dark menu (used on sign-in).
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mode = ref.watch(themeModeProvider);
    const icons = {
      ThemeMode.system: Icons.brightness_auto_outlined,
      ThemeMode.light: Icons.light_mode_outlined,
      ThemeMode.dark: Icons.dark_mode_outlined,
    };
    return PopupMenuButton<ThemeMode>(
      tooltip: t('theme.label'),
      icon: Icon(icons[mode], size: 16),
      onSelected: ref.read(themeModeProvider.notifier).set,
      itemBuilder: (_) => [
        for (final m in ThemeMode.values)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(icons[m], size: 16),
                const SizedBox(width: Gap.sm),
                Text(t('theme.${m.name}')),
                if (m == mode) ...[const Spacer(), const Icon(Icons.check, size: 16)],
              ],
            ),
          ),
      ],
    );
  }
}

/// Initials, name and role; opens a menu with the disclaimer and Sign out.
class _AccountButton extends ConsumerWidget {
  const _AccountButton(this.s);
  final Session s;

  static String initials(String name) {
    final parts = name.split(RegExp(r'[\s.]+')).where((p) => p.isNotEmpty).toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final role = t('role.${s.role}');
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                Text(role, style: Tok.sub),
                const SizedBox(height: 8),
                Text(t('app.disclaimer'), style: Tok.sub),
              ],
            ),
          ),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Ico.logout, size: 16),
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          child: Text(t('action.signOut'), style: Tok.body),
        ),
      ],
      builder: (context, ctl, _) => Pressable(
        onTap: () => ctl.isOpen ? ctl.close() : ctl.open(),
        semanticLabel: '${t('topbar.account')}: ${s.name}, $role',
        builder: (_, hover) => Container(
          height: Tok.controlH,
          padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
          decoration: BoxDecoration(
            color: hover ? Tok.inset : Tok.panel,
            borderRadius: BorderRadius.circular(Tok.rControl),
            border: Border.all(color: Tok.line),
            boxShadow: Tok.shadowControl,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Tok.tealTint, shape: BoxShape.circle),
                child: Text(
                  initials(s.name),
                  style: Tok.caps.copyWith(fontSize: 11, letterSpacing: 0.2, color: Tok.tealDark, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 7),
              Text(s.name, style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
              Text(' · $role', style: Tok.body.copyWith(color: Tok.text3)),
              const SizedBox(width: 7),
              const Icon(Ico.chevronDown, size: 14, color: Tok.text3),
            ],
          ),
        ),
      ),
    );
  }
}
