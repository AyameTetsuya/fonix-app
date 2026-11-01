import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonix_app/domain/curriculum.dart';
import 'package:fonix_app/domain/learning.dart';
import 'package:fonix_app/main.dart';
import 'fake_device.dart';

void main(){
  testWidgets('home, map, friends and sound dictionary form a working journey',(tester)async{
    tester.view.physicalSize=const Size(1280,800);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final c=Curriculum.decode(File('assets/data/curriculum.json').readAsStringSync());
    final device=FakeDevice()..data=(LearningState()..setup=true).encode();
    await tester.pumpWidget(FonixApp(device:device,curriculum:c));await tester.pumpAndSettle();
    expect(find.text('きょうも、\nおとの ぼうけんへ。'),findsOneWidget);
    await tester.tap(find.text('ぼうけんを はじめる'));await tester.pumpAndSettle();
    expect(find.text('きょうの おとを みつけよう'),findsOneWidget);
    await tester.tap(find.text('やってみよう'));await tester.pumpAndSettle();
    await tester.tap(find.text('s').last);await tester.pumpAndSettle();
    expect(find.text('みつけたね！'),findsOneWidget);
    await tester.tap(find.text('つぎへ'));await tester.pumpAndSettle();
    expect(find.text('お手本を まねして いってみよう'),findsOneWidget);
    await tester.tap(find.text('こえを だせないので すすむ'));await tester.pumpAndSettle();
    expect(find.text('ぼうけん できたね！'),findsOneWidget);
    await tester.tap(find.text('ぼうけんに もどる'));await tester.pumpAndSettle();
    expect(LearningState.decode(device.data).completed,{0});
    await tester.tap(find.text('なかま'));await tester.pumpAndSettle();
    expect(find.text('ごはんを あげる (1)'),findsOneWidget);
    await tester.tap(find.text('ごはんを あげる (1)'));await tester.pumpAndSettle();
    expect(find.text('もぐもぐ。ありがとう！'),findsOneWidget);
    await tester.tap(find.text('おとのずかん'));await tester.pumpAndSettle();
    await tester.tap(find.text('sh'));await tester.pumpAndSettle();
    expect(find.text('/ʃ/'),findsWidgets);
    await tester.tap(find.text('おとを きく'));await tester.pumpAndSettle();
    expect(device.played.last,'assets/audio/sound_sh.wav');
    expect(tester.takeException(),isNull);
  });
}
