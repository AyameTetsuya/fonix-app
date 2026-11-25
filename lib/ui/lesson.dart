import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app.dart';
import '../domain/curriculum.dart';
import '../domain/learning.dart';
import '../platform/device.dart';
import 'art.dart';
import 'shell.dart' show message;

const _teal = Color(0xFF208B80);
const _coral = Color(0xFFF47C55);
const _mint = Color(0xFFE5F3EB);

Future<void> startLesson(BuildContext context, AppController app, int index) async {
  await Navigator.push<void>(context, MaterialPageRoute(
    builder: (_) => LessonScreen(app: app, lesson: app.curriculum.lessons[index]),
  ));
}

class LessonScreen extends StatefulWidget {
  final AppController app;
  final Lesson lesson;
  const LessonScreen({super.key, required this.app, required this.lesson});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with WidgetsBindingObserver {
  late final List<Question> questions;
  late final String session;
  late final bool firstCompletion;
  int step = -1;
  bool busy = false, done = false;
  final elapsed = Stopwatch();
  AppController get app => widget.app;

  @override
  void initState() {
    super.initState();
    firstCompletion = !app.state.completed.contains(widget.lesson.index);
    WidgetsBinding.instance.addObserver(this);
    elapsed.start();
    session = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    questions = QuestionFactory(app.curriculum).forLesson(widget.lesson,
      reviews: app.state.reviews(DateTime.now(), widget.lesson.index, app.curriculum));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    elapsed.stop();
    app.device.stop();
    app.device.discard();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !done) {
      elapsed.start();
    } else {
      elapsed.stop();
    }
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await app.change((s) => s.finish(widget.lesson.index, session,
        seconds: elapsed.elapsed.inSeconds));
      await app.device.discard();
      elapsed.stop();
      if (mounted) setState(() => done = true);
    } catch (_) {
      if (mounted) message(context, 'ほぞんできなかったよ。もういちど おためしください。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exit() async {
    final exit = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('ひとやすみ？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('つづける')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('もどる')),
      ],
    ));
    if (exit == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sound = app.curriculum.sound(widget.lesson.skill);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.checkpoint ? 'たからさがし' : 'おとの ぼうけん'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leadingWidth: 80,
        leading: IconButton(tooltip: 'ぼうけんに もどる', iconSize: 34,
          onPressed: _exit, icon: const Icon(Icons.close_rounded)),
      ),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Row(children: [
          Expanded(child: LinearProgressIndicator(
            value: done ? 1 : (step + 1) / (questions.length + 2), minHeight: 12,
            backgroundColor: ink.withValues(alpha: .08), color: _teal,
            borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 12),
          Icon(Icons.star_rounded, size: 34, color: done ? _coral : const Color(0xFFE6C56C)),
        ])),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: done ? _complete() : step < 0 ? _intro(sound) : step < questions.length
            ? QuestionView(key: ValueKey(step), app: app, question: questions[step],
                onAnswered: (correct, helped) async {
                  await app.change((s) => s.record(Attempt(questions[step].skill,
                    questions[step].id, correct, helped, DateTime.now(),
                    direction: questions[step].kind == QuestionKind.read ? 'textToSound' : 'soundToText')));
                  if (mounted) setState(() => step++);
                })
            : PronunciationPractice(app: app, sound: sound,
                word: app.curriculum.examples(widget.lesson).firstOrNull,
                onComplete: finish, busy: busy),
        ))),
      ])),
    );
  }

  Widget _intro(Sound sound) {
    final word = app.curriculum.examples(widget.lesson).firstOrNull;
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Column(children: [
        _TitleRow(title: 'きいてみよう', onHelp: () => _soundHelp(context, app, sound, word)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: _stageDecoration(),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Animal(species: app.state.companion, size: compact ? 130 : 210),
              SizedBox(width: compact ? 18 : 56),
              Flexible(child: Column(children: [
                FittedBox(child: Text(sound.label,
                  style: TextStyle(fontSize: compact ? 86 : 110, height: 1.05,
                    fontWeight: FontWeight.w900, color: ink))),
                if (app.state.showIpa) Text('/${sound.ipa}/',
                  style: const TextStyle(fontSize: 28, color: _teal, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                _ListenButton(onPressed: () => _play(sound.audio), label: 'きく'),
              ])),
            ]),
          );
        }),
        const SizedBox(height: 20),
        _GoButton(key: const Key('lesson-start'), label: 'やってみる',
          onPressed: () => setState(() => step = 0)),
      ]));
  }

  Future<void> _play(String asset) async {
    try {
      await app.play(asset);
    } catch (_) {
      if (mounted) message(context, 'おとを さいせいできなかったよ。');
    }
  }

  Widget _complete() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
    child: Column(children: [
      const Text('やったね！', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 10),
      Stack(alignment: Alignment.center, children: [
        Container(width: 270, height: 270, decoration: BoxDecoration(
          shape: BoxShape.circle, gradient: RadialGradient(colors: [
            const Color(0xFFFFE8AE), const Color(0xFFFFE8AE).withValues(alpha: 0),
          ]))),
        Animal(species: app.state.companion, size: 230),
        const Positioned(top: 16, left: 8, child: Icon(Icons.auto_awesome_rounded, color: _coral, size: 48)),
        const Positioned(right: 0, bottom: 35, child: Icon(Icons.star_rounded, color: Color(0xFFE5B343), size: 54)),
      ]),
      Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(30)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.restaurant_rounded, color: _teal, size: 30), SizedBox(width: 12),
          Text('ごはん +1', style: TextStyle(fontSize: 26, color: ink, fontWeight: FontWeight.w800)),
        ])),
      if (widget.lesson.checkpoint && firstCompletion)
        const Padding(padding: EdgeInsets.only(top: 14), child: Text('なかまが ふえたよ！',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink))),
      const SizedBox(height: 22),
      _GoButton(key: const Key('lesson-done'), label: 'もどる',
        onPressed: () => Navigator.pop(context)),
    ]),
  );
}

typedef AnswerCallback = Future<void> Function(bool? correct, bool helped);

class QuestionView extends StatefulWidget {
  final AppController app;
  final Question question;
  final AnswerCallback onAnswered;
  const QuestionView({super.key, required this.app, required this.question, required this.onAnswered});
  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  String? chosen;
  bool? correct;
  bool busy = false;
  final List<int> selected = [];
  late final List<String> letters;
  Question get q => widget.question;
  bool get caseMatch => q.kind == QuestionKind.read && q.word == null;
  String get guide => 'assets/audio/guide_${caseMatch ? 'case' : q.kind == QuestionKind.read ? 'read' : q.kind == QuestionKind.build ? 'build' : 'listen'}.wav';

  @override
  void initState() {
    super.initState();
    letters = q.answer.split('')..shuffle(Random(q.id.hashCode));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) play(q.kind == QuestionKind.read ? guide : q.audio ?? guide);
    });
  }

  Future<void> advance({bool skip = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onAnswered(skip ? null : correct, correct == false);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        message(context, 'ほぞんできなかったよ。もういちど おためしください。');
      }
    }
  }

  Future<void> play(String asset) async {
    try {
      await widget.app.play(asset);
    } catch (_) {
      if (mounted) message(context, 'おとを さいせいできなかったよ。');
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
    child: Column(children: [
      _TitleRow(title: q.kind == QuestionKind.build ? 'つなげよう' :
        q.kind == QuestionKind.fill ? 'どれが はいる？' : caseMatch ? 'おなじ もじは？' :
        q.kind == QuestionKind.read ? 'どの おとかな？' : 'どれかな？',
        onHelp: () => play(guide), helpIcon: Icons.hearing_rounded, helpLabel: 'あそびかたを きく'),
      const SizedBox(height: 18),
      if (q.kind == QuestionKind.read)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
          q.word?.text ?? q.answer.toLowerCase(),
          style: const TextStyle(fontSize: 76, height: 1.15, fontWeight: FontWeight.w900, color: ink)))
      else if (q.audio != null)
        _ListenButton(key: const Key('question-listen'), onPressed: () => play(q.audio!), label: 'きく'),
      const SizedBox(height: 20),
      AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: chosen != null
        ? _feedback()
        : Column(key: const Key('question-choices'), children: [
            if (q.kind == QuestionKind.fill)
              Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(
                q.answer.replaceRange(q.blank!, q.blank! + 1, '＿'),
                style: const TextStyle(fontSize: 62, letterSpacing: 6, fontWeight: FontWeight.w900, color: ink))),
            if (q.kind == QuestionKind.build) _buildLetters() else _choices(),
            const SizedBox(height: 20),
            TextButton(key: const Key('question-skip'), onPressed: busy ? null : () => advance(skip: true),
            style: TextButton.styleFrom(minimumSize: const Size(150, 64)),
              child: const Text('とばす', style: TextStyle(fontSize: 22, color: muted))),
          ])),
    ]),
  );

  Widget _buildLetters() => Column(children: [
    Container(width: double.infinity, alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(24)),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(
        selected.map((i) => letters[i]).join().padRight(q.answer.length, '＿'),
        style: const TextStyle(fontSize: 56, height: 1.2, letterSpacing: 8, fontWeight: FontWeight.w800, color: ink)))),
    const SizedBox(height: 16),
    Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
      children: List.generate(letters.length, (i) => _LetterTile(
        key: ValueKey('letter-$i'), text: letters[i], width: 86,
        selected: selected.contains(i),
        onPressed: chosen != null || selected.contains(i) ? null : () => setState(() => selected.add(i))))),
    if (chosen == null) Padding(padding: const EdgeInsets.only(top: 14), child: Row(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(tooltip: 'ならべなおす', iconSize: 34,
          style: IconButton.styleFrom(minimumSize: const Size(72, 72)),
          onPressed: selected.isEmpty ? null : () => setState(() => selected.clear()),
          icon: const Icon(Icons.replay_rounded)),
        const SizedBox(width: 16),
        _GoButton(key: const Key('build-check'), label: 'これ！', width: 220,
          icon: Icons.check_rounded,
          onPressed: selected.length != letters.length ? null : () => setState(() {
            chosen = selected.map((i) => letters[i]).join();
            correct = q.accepts(chosen!);
          })),
      ],
    )),
  ]);

  Widget _choices() => Wrap(spacing: 18, runSpacing: 18, alignment: WrapAlignment.center,
    children: List.generate(q.choices.length, (i) {
      final choice = q.choices[i];
      if (q.kind == QuestionKind.read && !caseMatch) {
        return SizedBox(width: 190, child: Column(children: [
          _ListenButton(onPressed: () => play('assets/audio/word_$choice.wav'),
            label: '${i + 1}', color: const Color(0xFFE4F2EE), compact: true),
          const SizedBox(height: 10),
          OutlinedButton.icon(key: ValueKey('answer-$i'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(180, 72),
              backgroundColor: chosen == choice ? _mint : paper,
              side: BorderSide(color: chosen == choice ? _teal : const Color(0xFFD7E3DD), width: 2)),
            onPressed: chosen != null ? null : () => _choose(choice),
            icon: Icon(chosen == choice ? Icons.check_circle_rounded : Icons.touch_app_rounded, size: 30),
            label: const Text('これ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
        ]));
      }
      return _LetterTile(key: ValueKey('answer-$i'), text: choice,
        width: choice.length > 3 ? 210 : 170, selected: chosen == choice,
        onPressed: chosen != null ? null : () => _choose(choice));
    }),
  );

  void _choose(String choice) => setState(() {
    chosen = choice;
    correct = q.accepts(q.kind == QuestionKind.fill
      ? q.answer.replaceRange(q.blank!, q.blank! + 1, choice) : choice);
  });

  Widget _feedback() => Container(key: const Key('question-feedback'),
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(28)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(correct == true ? Icons.auto_awesome_rounded : Icons.headphones_rounded,
          size: 34, color: _teal),
        const SizedBox(width: 10),
        Text(correct == true ? 'やったね！' : 'いっしょに きこう',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
      ]),
      if (correct == false || q.kind != QuestionKind.read) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(q.answer, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: ink))),
      if (q.word != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text(q.word!.meaning, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, color: ink))),
      const SizedBox(height: 14),
      Wrap(spacing: 18, runSpacing: 12, alignment: WrapAlignment.center, children: [
        if (q.audio != null) _ListenButton(onPressed: () => play(q.audio!), label: 'きく', compact: true),
        _GoButton(key: const Key('question-next'), label: 'つぎへ', width: 250,
          onPressed: busy ? null : () => advance()),
      ]),
    ]),
  );
}

class PronunciationPractice extends StatefulWidget {
  final AppController app;
  final Sound sound;
  final Word? word;
  final Future<void> Function() onComplete;
  final bool busy;
  const PronunciationPractice({super.key, required this.app, required this.sound,
    this.word, required this.onComplete, this.busy = false});
  @override
  State<PronunciationPractice> createState() => _PronunciationPracticeState();
}

class _PronunciationPracticeState extends State<PronunciationPractice> with WidgetsBindingObserver {
  bool recording = false, working = false, saved = false, wordMode = false, practiceLogged = false;
  int takes = 0;
  RecordingResult? result;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      timer?.cancel();
      widget.app.device.discard();
      if (mounted) setState(() { recording = false; result = null; });
    }
  }

  Future<void> toggle() async {
    if (working) return;
    setState(() => working = true);
    try {
      if (recording) {
        timer?.cancel();
        final r = await widget.app.device.stopRecording();
        if (mounted) setState(() { recording = false; result = r; takes++; saved = false; });
      } else {
        await widget.app.device.discard();
        await widget.app.device.startRecording();
        if (mounted) {
          setState(() { recording = true; result = null; error = null; });
          timer = Timer(const Duration(seconds: 9), () { if (mounted && recording) toggle(); });
        }
      }
    } catch (_) {
      if (mounted) setState(() { recording = false; error = 'マイクが つかえないよ'; });
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> play({bool own = false, bool slow = false}) async {
    try {
      if (own) {
        await widget.app.device.playRecording();
      } else {
        await widget.app.play(wordMode && widget.word != null ? widget.word!.audio : widget.sound.audio,
          speed: slow ? .75 : 1.0);
      }
    } catch (_) {
      if (mounted) message(context, 'さいせいできなかったよ。もういちど おためしください。');
    }
  }

  Future<void> complete() async {
    if (widget.busy || working) return;
    setState(() => working = true);
    try {
      if (result != null && !practiceLogged) {
        await widget.app.change((s) => s.record(Attempt(widget.sound.id,
          'voice_${DateTime.now().microsecondsSinceEpoch}', null, false, DateTime.now(), direction: 'speaking')));
        practiceLogged = true;
      }
      await widget.onComplete();
    } catch (_) {
      if (mounted) message(context, 'きろくを ほぞんできなかったよ。もういちど おためしください。');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _details() => showModalBottomSheet<void>(context: context, showDragHandle: true,
    isScrollControlled: true, builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        MouthDiagram(ipa: widget.sound.ipa),
        const SizedBox(height: 12),
        Text(widget.sound.hint, style: const TextStyle(fontSize: 24), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text('お手本と ききくらべよう。\nはつおんの てんすうは つかないよ。',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 22, color: muted)),
        if (result != null) ...[
          const SizedBox(height: 16),
          Text(result!.feedback, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(key: const Key('record-save'),
            onPressed: saved ? null : () async {
              try {
                await widget.app.device.keepRecording();
                if (mounted) setState(() => saved = true);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              } catch (_) {
                if (sheetContext.mounted) message(sheetContext, 'ほぞんできなかったよ。ほぞんは 20こまでだよ。');
              }
            }, icon: const Icon(Icons.bookmark_add_rounded),
            label: Text(saved ? 'ほぞんしたよ' : 'こえを のこす')),
        ],
      ]),
    )));

  String get _qualityMessage {
    if (result!.durationMs < 250 || result!.rms <= .008) return 'こえが ちいさいかも';
    if (result!.clipping >= .1) return 'すこし はなれてみよう';
    return 'じぶんの こえを きこう';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
    child: Column(children: [
      _TitleRow(title: 'まねしてみよう', onHelp: recording ? null : _details,
        leading: IconButton(tooltip: 'あそびかたを きく',
          style: IconButton.styleFrom(minimumSize: const Size(64, 64)), iconSize: 32,
          onPressed: recording ? null : () async {
            try { await widget.app.play('assets/audio/guide_mic.wav'); }
            catch (_) { if (context.mounted) message(context, 'あんないを さいせいできなかったよ。'); }
          }, icon: const Icon(Icons.hearing_rounded))),
      const SizedBox(height: 8),
      if (widget.word != null) SegmentedButton<bool>(
        style: SegmentedButton.styleFrom(minimumSize: const Size(132, 56),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        showSelectedIcon: false,
        segments: const [ButtonSegment(value: false, label: Text('おと')),
          ButtonSegment(value: true, label: Text('ことば'))], selected: {wordMode},
        onSelectionChanged: recording ? null : (s) => setState(() => wordMode = s.first)),
      const SizedBox(height: 10),
      Text(wordMode ? widget.word!.text : widget.sound.label,
        style: const TextStyle(fontSize: 60, height: 1.1, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 16),
      Wrap(spacing: 18, runSpacing: 16, alignment: WrapAlignment.center, children: [
        _PracticeControl(key: const Key('record-model'), icon: Icons.volume_up_rounded,
          label: 'きく', color: _teal, onPressed: recording ? null : () => play()),
        if (widget.app.state.microphone) _PracticeControl(key: const Key('record-start'),
          icon: recording ? Icons.stop_rounded : Icons.mic_rounded,
          label: recording ? 'とめる' : takes == 0 ? 'はなす' : takes == 1 ? 'もういちど' : 'おわり',
          color: _coral, active: recording,
          onPressed: working || (!recording && takes >= 2) ? null : toggle),
        _PracticeControl(key: const Key('record-own'), icon: Icons.headphones_rounded,
          label: 'じぶん', color: const Color(0xFF6D79B5),
          onPressed: recording || result == null ? null : () => play(own: true)),
      ]),
      const SizedBox(height: 12),
      if (recording || error != null || result != null) Center(child: Text(
        recording ? '● ろくおんちゅう' : error ?? (result != null ? _qualityMessage : ''),
        style: TextStyle(fontSize: 24, height: 1.4, color: recording || error != null ? _coral : ink),
        textAlign: TextAlign.center)),
      const SizedBox(height: 16),
      Wrap(spacing: 18, runSpacing: 12, alignment: WrapAlignment.center, children: [
        OutlinedButton.icon(onPressed: recording ? null : () => play(slow: true),
          style: OutlinedButton.styleFrom(minimumSize: const Size(180, 80)),
          icon: const Icon(Icons.slow_motion_video_rounded, size: 30),
          label: const Text('ゆっくり', style: TextStyle(fontSize: 24))),
        _GoButton(key: const Key('practice-complete'), label: 'つぎへ', width: 260,
          onPressed: recording || working || widget.busy ? null : complete),
      ]),
    ]),
  );
}

class PlacementScreen extends StatefulWidget {
  final AppController app;
  const PlacementScreen({super.key, required this.app});
  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  final answers = <bool>[];
  late final List<Question> questions;
  bool finishing = false;
  int questionsId = 0;

  @override
  void initState() {
    super.initState();
    Question sound(String id, List<String> choices) => Question(id: 'placement_${questionsId++}',
      skill: id, answer: widget.app.curriculum.sound(id).label,
      kind: QuestionKind.listen, choices: choices, audio: widget.app.curriculum.sound(id).audio);
    Question word(String text, List<String> choices, {bool build = false}) {
      final w = widget.app.curriculum.words.firstWhere((w) => w.text == text);
      return Question(id: 'placement_${questionsId++}', skill: w.skills.last, answer: text,
        kind: build ? QuestionKind.build : QuestionKind.listen, choices: choices, audio: w.audio, word: w);
    }
    questions = [sound('s', ['m', 's', 't']),
      const Question(id: 'placement_case', skill: 'a', answer: 'a', kind: QuestionKind.read, choices: ['N', 'P', 'A']),
      sound('m', ['m', 'n', 'd']), word('map', ['map', 'mad', 'mat']), word('cat', ['cat', 'cut', 'cot']),
      word('pin', [], build: true), word('red', ['red', 'bed', 'rid']), word('van', [], build: true),
      sound('x', ['x', 'qu', 'z']), word('box', [], build: true), sound('sh', ['s', 'ch', 'sh']),
      word('ship', ['chip', 'ship', 'thin'])];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('おためし'), centerTitle: true),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(28, 12, 28, 8), child: Row(children: [
        Expanded(child: LinearProgressIndicator(value: answers.length / questions.length,
          minHeight: 12, color: _teal, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 16),
        Text('${answers.length} / ${questions.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ])),
      Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
        child: questions.length == answers.length ? SingleChildScrollView(
          padding: const EdgeInsets.all(28), child: Column(children: [
            const Text('やったね！', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ink)),
            Animal(species: widget.app.state.companion, size: 230),
            Text('しま ${Placement.recommend(answers) ~/ 7 + 1} へ！',
              style: const TextStyle(fontSize: 30, color: ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            _GoButton(key: const Key('placement-done'), label: 'しゅっぱつ', onPressed: finishing ? null : () async {
              setState(() => finishing = true);
              try {
                await widget.app.change((s) {
                  s.startAt = Placement.recommend(answers);
                  s.placement..clear()..addAll(answers);
                });
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) message(context, 'ほぞんできませんでした。');
                if (mounted) setState(() => finishing = false);
              }
            }),
          ])) : QuestionView(key: ValueKey(answers.length), app: widget.app,
            question: questions[answers.length], onAnswered: (correct, helped) async {
              if (mounted) setState(() => answers.add(correct == true && !helped));
            }),
      ))),
    ])),
  );
}

BoxDecoration _stageDecoration() => BoxDecoration(
  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFE3F2E6), Color(0xFFF3F7DF)]),
  borderRadius: BorderRadius.circular(36),
  border: Border.all(color: Colors.white, width: 3),
);

class _TitleRow extends StatelessWidget {
  final String title;
  final VoidCallback? onHelp;
  final IconData helpIcon;
  final String helpLabel;
  final Widget? leading;
  const _TitleRow({required this.title, required this.onHelp,
    this.helpIcon = Icons.help_outline_rounded, this.helpLabel = 'ヒント', this.leading});
  @override
  Widget build(BuildContext context) => Row(children: [
    leading ?? const SizedBox(width: 64),
    Expanded(child: Text(title, textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w900, color: ink))),
    IconButton(tooltip: helpLabel, onPressed: onHelp, iconSize: 32,
      style: IconButton.styleFrom(minimumSize: const Size(64, 64)), icon: Icon(helpIcon)),
  ]);
}

class _GoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double width;
  final IconData icon;
  const _GoButton({super.key, required this.label, required this.onPressed,
    this.width = 330, this.icon = Icons.arrow_forward_rounded});
  @override
  Widget build(BuildContext context) => SizedBox(width: width,
    child: FilledButton.icon(onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: _coral, foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE2E5DD), disabledForegroundColor: muted,
        minimumSize: const Size(0, 80), elevation: onPressed == null ? 0 : 3,
        shadowColor: _coral.withValues(alpha: .35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
      icon: Icon(icon, size: 32), label: Text(label,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))));
}

class _ListenButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Color color;
  final bool compact;
  const _ListenButton({super.key, required this.onPressed, required this.label,
    this.color = const Color(0xFFFFFFFF), this.compact = false});
  @override
  Widget build(BuildContext context) => SizedBox(width: compact ? 150 : 190,
    child: OutlinedButton.icon(onPressed: onPressed,
      style: OutlinedButton.styleFrom(backgroundColor: color,
        foregroundColor: _teal, minimumSize: Size(0, compact ? 80 : 92),
        side: const BorderSide(color: Color(0xFFBBDDD0), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      icon: Icon(Icons.volume_up_rounded, size: compact ? 36 : 42),
      label: Text(label, style: TextStyle(fontSize: compact ? 28 : 30, fontWeight: FontWeight.w900))));
}

class _LetterTile extends StatelessWidget {
  final String text;
  final double width;
  final bool selected;
  final VoidCallback? onPressed;
  const _LetterTile({super.key, required this.text, required this.width,
    required this.selected, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(minimumSize: const Size(80, 104),
      backgroundColor: selected ? const Color(0xFFCBEBDC) : paper,
      foregroundColor: ink, disabledForegroundColor: ink,
      side: BorderSide(color: selected ? _teal : const Color(0xFFD8E3DB), width: selected ? 3 : 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
    child: FittedBox(fit: BoxFit.scaleDown, child: Text(text,
      style: const TextStyle(fontSize: 48, height: 1.2, fontWeight: FontWeight.w900)))));
}

class _PracticeControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onPressed;
  const _PracticeControl({super.key, required this.icon, required this.label,
    required this.color, required this.onPressed, this.active = false});
  @override
  Widget build(BuildContext context) => SizedBox(width: 198, height: 160,
    child: FilledButton(onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: active ? const Color(0xFFD45543) : color,
        foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFE1E5DE),
        disabledForegroundColor: const Color(0xFF9BA99F), elevation: onPressed == null ? 0 : 3,
        padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 58), const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      ])));
}

Future<void> _soundHelp(BuildContext context, AppController app, Sound sound, Word? word) =>
  showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true,
    builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        MouthDiagram(ipa: sound.ipa), const SizedBox(height: 16),
        Text(sound.hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        if (word != null) ...[
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            // Contextual spellings such as u_e may represent a different sound
            // in this word. Keep its model available without teaching a false
            // sequence of isolated sounds.
            if (app.curriculum.canBlend(word)) ...word.skills.map((id) => OutlinedButton(
              key: ValueKey('blend-part-$id'),
              onPressed: () async {
                try { await app.play(app.curriculum.sound(id).audio); }
                catch (_) { if (sheetContext.mounted) message(sheetContext, 'さいせいできなかったよ。'); }
              }, child: Text(app.curriculum.sound(id).label, style: const TextStyle(fontSize: 32)))),
            _ListenButton(key: const Key('help-word-play'), label: word.text, onPressed: () async {
              try { await app.play(word.audio); }
              catch (_) { if (sheetContext.mounted) message(sheetContext, 'さいせいできなかったよ。'); }
            }),
          ]),
          const SizedBox(height: 16),
        ],
        if (sound.label.length == 1) OutlinedButton.icon(
          onPressed: () async {
            try { await app.play('assets/audio/name_${sound.label}.wav'); }
            catch (_) { if (sheetContext.mounted) message(sheetContext, 'さいせいできなかったよ。'); }
          }, icon: const Icon(Icons.abc_rounded, size: 34),
          label: const Text('もじの なまえ', style: TextStyle(fontSize: 24))),
      ]),
    )));
