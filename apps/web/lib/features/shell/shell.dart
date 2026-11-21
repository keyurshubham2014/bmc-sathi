import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class _Nav {
  const _Nav(this.key, this.icon, this.path, this.matches);
  final String key;
  final IconData icon;
  final String path;
  final bool Function(String location) matches;
}

List<_Nav> _items(Session s) {
  final ward = '/ward/${wardSlug(s.wardCode ?? 'E')}';
  return [
    _Nav('nav.overview', Icons.dashboard_outlined, s.isAuditor ? '/city' : ward,
        (l) => l.startsWith('/city') || (l.startsWith('/ward') && !l.contains('tab=plan'))),
    if (s.canSeeFlags) _Nav('nav.flags', Icons.flag_outlined, '/flags', (l) => l.startsWith('/flags')),
    _Nav('nav.contractors', Icons.engineering_outlined, '/contractors', (l) => l.startsWith('/contractors')),
    _Nav('nav.plan', Icons.route_outlined, '$ward?tab=plan', (l) => l.contains('tab=plan')),
    _Nav('nav.trail', Icons.timeline_outlined, '/trail', (l) => l.startsWith('/trail')),
    if (s.isOfficer) _Nav('nav.intake', Icons.add_box_outlined, '/intake', (l) => l.startsWith('/intake')),
    if (s.isAuditor) _Nav('nav.settings', Icons.tune_outlined, '/settings', (l) => l.startsWith('/settings')),
  ];
}

/// Header plus navigation: a labelled rail when wide, icons when medium, a bottom bar when narrow.
class Shell extends ConsumerWidget {
  const Shell({super.key, required this.location, required this.child, this.notice});
  final String location;
  final Widget child;
  final String? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 720, wide = width >= 1200;
    final items = _items(s);
    final selected = items.indexWhere((i) => i.matches(location)).clamp(0, items.length - 1);

    final body = Column(children: [
      if (notice == 'notAllowed')
        Container(
          width: double.infinity,
          color: c.infoTint,
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
          child: Text(t('state.notAllowed'), style: TextStyle(color: c.info)),
        ),
      Expanded(child: child),
    ]);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(57),
        child: Container(
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: SafeArea(
            child: Row(children: [
              Icon(Icons.account_balance_outlined, color: c.primary),
              const SizedBox(width: Gap.sm),
              Text(t('app.name'), style: Theme.of(context).textTheme.titleLarge!.copyWith(color: c.primary)),
              if (!narrow) Text('  ·  ${t('app.module')}', style: Theme.of(context).textTheme.titleMedium!.copyWith(color: c.textSecondary)),
              const SizedBox(width: Gap.md),
              const Flexible(child: SyntheticTag()),
              const Spacer(),
              const LangToggle(),
              const ThemeToggle(),
              _AccountMenu(s),
            ]),
          ),
        ),
      ),
      body: narrow
          ? body
          : Row(children: [
              NavigationRail(
                extended: wide,
                minExtendedWidth: 200,
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(items[i].path),
                labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [for (final i in items) NavigationRailDestination(icon: Icon(i.icon), label: Text(t(i.key)))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ]),
      bottomNavigationBar: narrow
          ? NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(items[i].path),
              destinations: [for (final i in items) NavigationDestination(icon: Icon(i.icon), label: t(i.key))],
            )
          : null,
    );
  }
}

class LangToggle extends ConsumerWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return Semantics(
      label: ref.watch(stringsProvider)('lang.label'),
      child: TextButton(
        onPressed: () => ref.read(langProvider.notifier).set(lang == 'en' ? 'mr' : 'en'),
        // Shows the language you will switch to.
        child: Text(lang == 'en' ? 'मराठी' : 'English'),
      ),
    );
  }
}

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mode = ref.watch(themeModeProvider);
    const icons = {ThemeMode.system: Icons.brightness_auto_outlined, ThemeMode.light: Icons.light_mode_outlined, ThemeMode.dark: Icons.dark_mode_outlined};
    return PopupMenuButton<ThemeMode>(
      tooltip: t('theme.label'),
      icon: Icon(icons[mode]),
      onSelected: ref.read(themeModeProvider.notifier).set,
      itemBuilder: (_) => [
        for (final m in ThemeMode.values)
          PopupMenuItem(value: m, child: Row(children: [Icon(icons[m], size: 18), const SizedBox(width: Gap.sm), Text(t('theme.${m.name}')), if (m == mode) ...[const Spacer(), const Icon(Icons.check, size: 18)]])),
      ],
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu(this.s);
  final Session s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      tooltip: s.name,
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (_) => ref.read(sessionProvider.notifier).signOut(),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: tt.labelLarge),
            Text(t('role.${s.role}'), style: tt.bodySmall),
            const SizedBox(height: Gap.sm),
            SizedBox(width: 240, child: Text(t('app.disclaimer'), style: tt.bodySmall)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'out', child: Row(children: [const Icon(Icons.logout, size: 18), const SizedBox(width: Gap.sm), Text(t('action.signOut'))])),
      ],
    );
  }
}
