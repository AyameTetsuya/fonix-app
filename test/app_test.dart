import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonix_app/domain/curriculum.dart';
import 'package:fonix_app/domain/learning.dart';
import 'package:fonix_app/main.dart';

import 'fake_device.dart';

class _AudioDevice extends FakeDevice {
  final playback = <({String asset, double volume})>[];

  @override
  Future<void> play(String asset, {double speed = 1, double volume = .8}) async {
    playback.add((asset: asset, volume: volume));
    await super.play(asset, speed: speed, volume: volume);
  }
}

final _curriculum = Curriculum.decode(
  File('assets/data/curriculum.json').readAsStringSync(),
);

Future<void> _boot(WidgetTester tester, FakeDevice device, {
  Size size = const Size(1280, 800), double textScale = 1,
  Curriculum? curriculum,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(FonixApp(device: device, curriculum: curriculum ?? _curriculum));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'After tapping $key');
}

void _largeTarget(WidgetTester tester, String key, {double minimum = 64}) {
  final size = tester.getSize(find.byKey(ValueKey(key)));
  expect(size.width, greaterThanOrEqualTo(minimum), reason: '$key width');
  expect(size.height, greaterThanOrEqualTo(minimum), reason: '$key height');
}

Future<void> _openSh(WidgetTester tester) async {
  await _tap(tester, 'nav-sounds');
  await tester.scrollUntilVisible(find.byKey(const ValueKey('sound-sh')), 280,
    scrollable: find.descendant(of: find.byKey(const ValueKey('sound-grid')),
      matching: find.byType(Scrollable)));
  await tester.pumpAndSettle();
  _largeTarget(tester, 'sound-sh', minimum: 120);
  final symbol = tester.widget<Text>(find.descendant(
    of: find.byKey(const ValueKey('sound-sh')), matching: find.text('ʃ')));
  expect(symbol.style!.fontSize, greaterThanOrEqualTo(48));
  await _tap(tester, 'sound-sh');
}

void main() {
  for (final text in ['tube', 'tune', 'flute', 'rude', 'rule', 'cute']) {
    testWidgets('word help uses a valid sound sequence for $text', (tester) async {
      final word = _curriculum.words.firstWhere((word) => word.text == text);
      final curriculum = Curriculum(_curriculum.sounds, [word],
        _curriculum.lessons, _curriculum.islands);
      final lesson = curriculum.lessons.firstWhere((lesson) => lesson.skill == 'u_e');
      final state = LearningState(setup: true,
        completed: Set<int>.from(List.generate(lesson.index, (index) => index)));
      final device = _AudioDevice()..data = state.encode();
      await _boot(tester, device, curriculum: curriculum);
      await _tap(tester, 'adventure-start');
      await tester.tap(find.byTooltip('ヒント'));
      await tester.pumpAndSettle();

      final parts = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('blend-part-');
      });
      if (text == 'cute') {
        expect(parts, findsNWidgets(word.skills.length));
        await _tap(tester, 'blend-part-u_e');
        expect(device.played.last, 'assets/audio/sound_u_e.wav');
      } else {
        expect(parts, findsNothing,
          reason: 'Do not present /ju/ as the component of a word using /u/');
      }
      await _tap(tester, 'help-word-play');
      expect(device.played.last, word.audio);
      expect(device.playback.last.volume, state.volume);
      expect(device.data, state.encode(), reason: 'Opening help preserves saved progress and settings');
    });
  }

  testWidgets('a child can learn, record, feed a friend and compare sound audio',
    (tester) async {
      final device = _AudioDevice()
        ..data = LearningState(setup: true, volume: .65).encode();
      await _boot(tester, device);

      await _tap(tester, 'adventure-start');
      await _tap(tester, 'lesson-start');
      expect(device.played.last, 'assets/audio/sound_s.wav');
      final question = QuestionFactory(_curriculum).forLesson(_curriculum.lessons.first).single;
      await _tap(tester, 'question-listen');
      await _tap(tester, 'answer-${question.choices.indexOf(question.answer)}');
      await _tap(tester, 'question-next');

      await _tap(tester, 'record-model');
      expect(device.played.last, 'assets/audio/sound_s.wav');
      await _tap(tester, 'record-start');
      await _tap(tester, 'record-start');
      await _tap(tester, 'record-own');
      await _tap(tester, 'practice-complete');
      expect(find.text('やったね！'), findsOneWidget);
      final learned = LearningState.decode(device.data);
      expect(learned.completed, {0});
      expect(learned.stars, 1);
      expect(learned.food, 1);
      expect(learned.sessions, hasLength(1));
      expect(learned.attempts.where((a) => a.direction == 'soundToText').single.correct, isTrue);
      expect(learned.attempts.where((a) => a.direction == 'speaking').single.correct, isNull);
      expect(device.kept, isEmpty, reason: 'Recording stays temporary unless explicitly saved');

      await _tap(tester, 'lesson-done');
      await _tap(tester, 'nav-friends');
      await _tap(tester, 'feed-companion');
      expect(find.byKey(const ValueKey('companion-reaction')), findsOneWidget);
      expect(LearningState.decode(device.data).food, 0);
      expect(LearningState.decode(device.data).completed, {0});
      final feedButton = tester.widget<FilledButton>(find.byKey(const ValueKey('feed-companion')));
      expect(feedButton.onPressed, isNull, reason: 'One meal consumes one reward');

      final beforeDictionary = device.playback.length;
      await _openSh(tester);
      expect(device.playback.length, beforeDictionary + 1, reason: 'A single card tap plays the sound');
      expect(device.played.last, 'assets/audio/sound_sh.wav');
      await _tap(tester, 'sound-play-sh');
      expect(device.played.last, 'assets/audio/sound_sh.wav');
      await _tap(tester, 'word-play-sh');
      expect(device.played.last, 'assets/audio/word_ship.wav');
      expect(device.playback.skip(beforeDictionary).map((p) => p.volume), everyElement(.65),
        reason: 'Phonemes and words both honor the parent volume setting');
      expect(tester.takeException(), isNull);
    });

  for (final viewport in [
    (size: const Size(1280, 800), scale: 1.0),
    (size: const Size(960, 600), scale: 1.3),
  ]) {
    testWidgets('child controls fit ${viewport.size} at text scale ${viewport.scale}',
      (tester) async {
        final device = FakeDevice()..data = LearningState(setup: true).encode();
        await _boot(tester, device, size: viewport.size, textScale: viewport.scale);
        _largeTarget(tester, 'adventure-start', minimum: 80);
        for (final nav in ['home', 'map', 'friends', 'sounds']) {
          _largeTarget(tester, 'nav-$nav', minimum: 80);
        }
        final launchLabel = tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('adventure-start')), matching: find.text('しゅっぱつ')));
        expect(launchLabel.style!.fontSize, greaterThanOrEqualTo(30));
        expect(find.byType(Text).evaluate().length, lessThanOrEqualTo(12),
          reason: 'The home screen presents a single visual action with little reading');

        await _tap(tester, 'nav-map');
        await _tap(tester, 'island-0');
        _largeTarget(tester, 'lesson-select-0', minimum: 100);
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('lesson-select-0'))).onPressed, isNotNull);
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('lesson-select-1'))).onPressed, isNull);
        await _tap(tester, 'lesson-select-0');
        await _tap(tester, 'lesson-start');
        _largeTarget(tester, 'answer-0', minimum: 80);
        _largeTarget(tester, 'question-listen', minimum: 80);
        await _tap(tester, 'question-skip');
        _largeTarget(tester, 'record-model', minimum: 100);
        _largeTarget(tester, 'record-start', minimum: 100);
        _largeTarget(tester, 'record-own', minimum: 100);
        await _tap(tester, 'record-model');
        await _tap(tester, 'record-start');
        await _tap(tester, 'record-start');
        await _tap(tester, 'practice-complete');
        await _tap(tester, 'lesson-done');

        await _tap(tester, 'nav-friends');
        _largeTarget(tester, 'feed-companion');
        await _tap(tester, 'pet-companion');
        expect(find.byKey(const ValueKey('companion-reaction')), findsOneWidget);
        await _openSh(tester);
        _largeTarget(tester, 'sound-play-sh');
        _largeTarget(tester, 'word-play-sh');
        await _tap(tester, 'sound-play-sh');
        await _tap(tester, 'word-play-sh');
        await tester.tap(find.byTooltip('とじる'));
        await tester.pumpAndSettle();
        await _tap(tester, 'nav-home');
        expect(find.byKey(const ValueKey('adventure-start')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
  }
}
