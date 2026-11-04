import 'package:flutter/material.dart';
import '../app.dart';
import '../domain/curriculum.dart';
import 'art.dart';
import 'lesson.dart';
import 'parent.dart';

const friendNames = ['きつね','うさぎ','ねこ','いぬ','くま','あひる','かえる','ふくろう','ぺんぎん','らいおん','りす'];

void message(BuildContext context, String text) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class AppShell extends StatefulWidget {
  final AppController controller;
  const AppShell({super.key, required this.controller});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int page = 0;
  AppController get app => widget.controller;
  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: app, builder: (context, _) {
      if (!app.state.setup) return SetupScreen(app: app);
      return Scaffold(body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 16, 8), child: Row(children: [
          const Icon(Icons.explore_rounded, color: ink, size: 34),
          const SizedBox(width: 10),
          const Expanded(child: Text('おとのぼうけん', maxLines: 1,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink))),
          Semantics(label: 'スター ${app.state.stars}こ', child: Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF2B541), size: 36),
            Text('${app.state.stars}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
          ])),
          const SizedBox(width: 10),
          IconButton(key: const Key('parent-settings'), tooltip: 'おうちのひとへ',
            onPressed: () => openParent(context, app), icon: const Icon(Icons.lock_outline_rounded, size: 28)),
        ])),
        Expanded(child: [
          HomeScreen(app: app, onMap: () => setState(() => page = 1)),
          MapScreen(app: app), FriendsScreen(app: app), DictionaryScreen(app: app),
        ][page]),
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
          for (var i = 0; i < 4; i++) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _NavigationButton(key: Key(['nav-home','nav-map','nav-friends','nav-sounds'][i]),
              selected: page == i, label: ['ホーム','ちず','なかま','おと'][i],
              icon: [Icons.cottage_rounded,Icons.explore_rounded,Icons.pets_rounded,Icons.volume_up_rounded][i],
              color: [const Color(0xFFF0DBA5),const Color(0xFFB9DBD2),const Color(0xFFF3C3AF),const Color(0xFFCFCEF0)][i],
              onTap: () => setState(() => page = i)),
          )),
        ])),
      ])));
    });
}

class _NavigationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NavigationButton({super.key, required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => Semantics(button: true, selected: selected,
    child: Material(color: selected ? color : paper, borderRadius: BorderRadius.circular(24),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        decoration: BoxDecoration(border: Border.all(color: selected ? ink : const Color(0xFFE7E4D7), width: selected ? 3 : 1),
          borderRadius: BorderRadius.circular(24)),
        child: LayoutBuilder(builder: (context, c) => c.maxWidth >= 155
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 34, color: ink),
              const SizedBox(width: 10), Text(label, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: ink))])
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 32, color: ink),
              Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink))])),
      ))));
}

class HomeScreen extends StatelessWidget {
  final AppController app;
  final VoidCallback onMap;
  const HomeScreen({super.key, required this.app, required this.onMap});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: ClipRRect(borderRadius: BorderRadius.circular(32), child: LayoutBuilder(builder: (context, c) {
      final roomy = c.maxWidth > 720;
      return Stack(fit: StackFit.expand, children: [
        const AdventureScene(showCompanion: false),
        // A soft scrim keeps the single action readable against the illustrated landscape.
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft,
          end: Alignment.centerRight, colors: [paper.withValues(alpha: .06), paper.withValues(alpha: .87)]))),
        Positioned(top: 18, left: 22, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(color: paper.withValues(alpha: .9), borderRadius: BorderRadius.circular(30)),
          child: Text('しま ${app.state.nextLesson ~/ 7 + 1}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink)))),
        if (roomy) Row(children: [
          Expanded(flex: 5, child: Center(child: Animal(species: app.state.companion, size: c.maxHeight.clamp(180, 370).toDouble()))),
          Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(24), child: _homeAction(context))),
        ]) else Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 55),
            child: Center(child: Animal(species: app.state.companion, size: 210)))),
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 20), child: _homeAction(context, compact: true)),
        ]),
        Positioned(top: 12, right: 12, child: IconButton.filledTonal(tooltip: 'ちずを みる',
          onPressed: onMap, iconSize: 32, icon: const Icon(Icons.map_rounded))),
      ]);
    })));
  Widget _homeAction(BuildContext context, {bool compact = false}) => Column(mainAxisSize: MainAxisSize.min, children: [
    if (!compact) ...[
      const Text('あそぼう！', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 24),
    ],
    SizedBox(width: 350, child: FilledButton.icon(key: const Key('adventure-start'),
      style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink,
        minimumSize: const Size(180, 92), elevation: 4, shadowColor: ink.withValues(alpha: .3)),
      onPressed: () => startLesson(context, app, app.state.nextLesson),
      icon: const Icon(Icons.play_arrow_rounded, size: 44),
      label: const Text('しゅっぱつ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)))),
  ]);
}

class MapScreen extends StatelessWidget {
  final AppController app;
  const MapScreen({super.key, required this.app});
  @override Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), itemCount: 10,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 285,
      mainAxisExtent: 238, crossAxisSpacing: 16, mainAxisSpacing: 18),
    itemBuilder: (context, i) {
      final island = app.curriculum.islands[i];
      final open = app.state.unlocked(i * 7);
      final current = app.state.nextLesson ~/ 7 == i;
      final completed = app.state.completed.where((l) => l ~/ 7 == i).length;
      return Semantics(label: 'しま ${i + 1}、${open ? 'あそべる' : 'まだ'}', button: open,
        child: Material(color: open ? Color(island.color).withValues(alpha: .19) : const Color(0xFFE8E9E3),
          borderRadius: BorderRadius.circular(30), child: InkWell(key: Key('island-$i'),
            borderRadius: BorderRadius.circular(30), onTap: open ? () => _lessons(context, i) : null,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
              border: Border.all(color: current ? ink : Colors.transparent, width: 4)),
              child: Stack(children: [
                Center(child: Opacity(opacity: open ? 1 : .22, child: Animal(species: i + 1, size: 150))),
                Positioned(top: 12, left: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 36,
                  fontWeight: FontWeight.w900, color: ink))),
                Positioned(top: 14, right: 14, child: Icon(open ? (current ? Icons.play_circle_fill_rounded : Icons.check_circle_rounded)
                  : Icons.lock_rounded, size: 32, color: current ? ink : muted)),
                Positioned(bottom: 12, left: 12, right: 12, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var star = 0; star < 7; star++) Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(star < completed ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 23, color: star < completed ? const Color(0xFFD79D32) : muted)),
                ])),
              ])),
          )));
    });
  void _lessons(BuildContext context, int island) => showModalBottomSheet<void>(context: context,
    isScrollControlled: true, showDragHandle: true,
    builder: (sheetContext) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Text('しま ${island + 1}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
          children: app.curriculum.lessons.where((l) => l.island == island).map((l) {
            final open = app.state.unlocked(l.index), done = app.state.completed.contains(l.index);
            return SizedBox(width: 112, height: 112, child: FilledButton(
              key: Key('lesson-select-${l.index}'),
              style: FilledButton.styleFrom(backgroundColor: done ? const Color(0xFFF4D78E) : open ? ink : const Color(0xFFE2E4DD),
                foregroundColor: done ? ink : paper, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
              onPressed: !open ? null : () {
                Navigator.pop(sheetContext);
                startLesson(context, app, l.index);
              },
              child: done ? const Icon(Icons.star_rounded, size: 50) : !open ? const Icon(Icons.lock_rounded, size: 36)
                : l.checkpoint ? const Icon(Icons.emoji_events_rounded, size: 45)
                : Text('${l.index % 7 + 1}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900))));
          }).toList()),
      ]))));
}

class FriendsScreen extends StatefulWidget {
  final AppController app;
  const FriendsScreen({super.key, required this.app});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String? reaction;
  bool busy = false;
  AppController get app => widget.app;
  Future<void> _feed() async {
    if (busy || app.state.food == 0) return;
    setState(() => busy = true);
    try {
      await app.change((s) => s.feed());
      if (mounted) setState(() => reaction = 'おいしい！');
    } catch (_) {
      if (mounted) message(context, 'もういちど');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> _choose(int i) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await app.change((s) => s.companion = i);
      if (mounted) setState(() => reaction = null);
    } catch (_) {
      if (mounted) message(context, 'もういちど');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(18),
    child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFFE5EDDB), borderRadius: BorderRadius.circular(32)),
        child: LayoutBuilder(builder: (context, c) {
          final portrait = Column(mainAxisSize: MainAxisSize.min, children: [
            Animal(species: app.state.companion, size: c.maxWidth < 500 ? 180 : 260),
            if (reaction != null) Text(reaction!, key: const Key('companion-reaction'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink)),
          ]);
          final actions = Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendNames[app.state.companion], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink)),
            const SizedBox(height: 18),
            FilledButton.icon(key: const Key('feed-companion'),
              onPressed: busy || app.state.food == 0 ? null : _feed,
              style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
              icon: const Icon(Icons.restaurant_rounded, size: 34), label: Text('ごはん ${app.state.food}')),
            const SizedBox(height: 14),
            OutlinedButton.icon(key: const Key('pet-companion'),
              onPressed: () => setState(() => reaction = 'うれしい！'),
              icon: const Icon(Icons.favorite_rounded, color: Color(0xFFD87971), size: 34), label: const Text('なでる')),
          ]);
          return c.maxWidth >= 620
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [portrait, const SizedBox(width: 80), actions])
            : Column(children: [portrait, const SizedBox(height: 16), actions]);
        })),
      const SizedBox(height: 22),
      Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: List.generate(11, (i) {
        final unlocked = i < app.state.unlockedAnimals, selected = i == app.state.companion;
        return Semantics(label: '${friendNames[i]}、${unlocked ? 'なかま' : 'まだ'}', selected: selected,
          child: SizedBox(width: 132, height: 144, child: Material(color: selected ? const Color(0xFFF5D995) : paper,
            borderRadius: BorderRadius.circular(28), child: InkWell(key: Key('companion-$i'),
              onTap: !unlocked || busy ? null : () => _choose(i), borderRadius: BorderRadius.circular(28),
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                border: Border.all(color: selected ? ink : const Color(0xFFE3E4D8), width: selected ? 3 : 1)),
                child: unlocked ? Stack(alignment: Alignment.center, children: [Animal(species: i, size: 110),
                  if (selected) const Positioned(top: 5, right: 5, child: Icon(Icons.check_circle_rounded, color: ink))])
                  : const Icon(Icons.lock_rounded, size: 40, color: muted)),
            ))));
      })),
    ]));
}

class DictionaryScreen extends StatefulWidget {
  final AppController app;
  const DictionaryScreen({super.key, required this.app});
  @override State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  bool alphabet = false;
  AppController get app => widget.app;
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 14), child: SegmentedButton<bool>(
      segments: const [ButtonSegment(value: false, icon: Icon(Icons.volume_up_rounded), label: Text('おと')),
        ButtonSegment(value: true, icon: Icon(Icons.abc_rounded), label: Text('ABC'))],
      selected: {alphabet}, onSelectionChanged: (s) => setState(() => alphabet = s.first))),
    Expanded(child: alphabet ? _alphabet(context) : _sounds(context)),
  ]);
  Widget _sounds(BuildContext context) {
    final sounds = app.curriculum.sounds.where((s) => !s.id.startsWith('mix') && s.id != 'review').toList();
    return GridView.builder(key: const Key('sound-grid'), padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      itemCount: sounds.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 185,
        mainAxisExtent: 166, crossAxisSpacing: 14, mainAxisSpacing: 14),
      itemBuilder: (context, i) {
        final s = sounds[i];
        return Material(color: [const Color(0xFFE5EEDB),const Color(0xFFDEEDEA),const Color(0xFFF5E7D4),const Color(0xFFEBE5F2)][i % 4],
          borderRadius: BorderRadius.circular(28), child: InkWell(key: Key('sound-${s.id}'),
            borderRadius: BorderRadius.circular(28), onTap: () => showSound(context, app, s),
            child: Semantics(label: '${s.label} のおと', button: true, child: Stack(alignment: Alignment.center, children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(app.state.showIpa ? s.ipa : s.label, style: TextStyle(fontSize: s.label.length > 2 ? 48 : 60,
                  height: 1.1, fontWeight: FontWeight.w900, color: ink)),
                if (app.state.showIpa) Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(s.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: muted))),
              ]),
              const Positioned(right: 9, bottom: 9, child: Icon(Icons.volume_up_rounded, size: 25, color: ink)),
            ]))));
      });
  }
  Widget _alphabet(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), itemCount: 26,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 185,
      mainAxisExtent: 155, crossAxisSpacing: 14, mainAxisSpacing: 14),
    itemBuilder: (context, i) {
      final letter = String.fromCharCode(97 + i);
      return Material(color: paper, borderRadius: BorderRadius.circular(28), child: InkWell(
        borderRadius: BorderRadius.circular(28), onTap: () => _showLetter(context, letter),
        child: Center(child: Text('${letter.toUpperCase()}$letter',
          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: ink)))));
    });
  void _showLetter(BuildContext context, String letter) {
    app.play('assets/audio/name_$letter.wav').catchError((Object _) {
      if (context.mounted) message(context, 'もういちど');
    });
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Center(child: Text('${letter.toUpperCase()} $letter', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: ink))),
      content: Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
        FilledButton.icon(onPressed: () => app.play('assets/audio/name_$letter.wav').catchError((Object _) {
          if (dialogContext.mounted) message(dialogContext, 'もういちど');
        }), icon: const Icon(Icons.abc_rounded), label: const Text('なまえ')),
        OutlinedButton.icon(onPressed: () => showSound(dialogContext, app, app.curriculum.sound(letter == 'q' ? 'qu' : letter)),
          icon: const Icon(Icons.volume_up_rounded), label: const Text('おと')),
      ]),
      actions: [IconButton(tooltip: 'とじる', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded, size: 32))],
    ));
  }
}

Future<void> showSound(BuildContext context, AppController app, Sound sound) async {
  // One tap on the sound card plays the sound; reading a paragraph is never required.
  app.play(sound.audio).catchError((Object _) { if (context.mounted) message(context, 'もういちど'); });
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    insetPadding: const EdgeInsets.all(18),
    title: Row(children: [Expanded(child: Wrap(spacing: 18, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(sound.label, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: ink)),
      if (app.state.showIpa) Text('/${sound.ipa}/', style: const TextStyle(fontSize: 40, color: muted)),
    ])), IconButton(tooltip: 'とじる', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded, size: 32))]),
    content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 125, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Animal(species: app.state.companion, size: 120), const SizedBox(width: 24), MouthDiagram(ipa: sound.ipa),
      ])),
      const SizedBox(height: 22),
      Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
        FilledButton.icon(key: Key('sound-play-${sound.id}'), onPressed: () => app.play(sound.audio).catchError((Object _) {
          if (dialogContext.mounted) message(dialogContext, 'もういちど');
        }), icon: const Icon(Icons.volume_up_rounded, size: 36), label: const Text('きく')),
        OutlinedButton.icon(key: Key('word-play-${sound.id}'), onPressed: () => app.play('assets/audio/word_${sound.example}.wav').catchError((Object _) {
          if (dialogContext.mounted) message(dialogContext, 'もういちど');
        }), icon: const Icon(Icons.chat_bubble_rounded, size: 32), label: const Text('ことば')),
      ]),
      const SizedBox(height: 12),
      ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('ヒント'), children: [
        Text(sound.hint, style: const TextStyle(fontSize: 24, height: 1.5)),
        const SizedBox(height: 12), Text(sound.example, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ink)),
      ]),
    ]))),
  ));
}
