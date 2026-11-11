import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonix_app/app.dart';
import 'package:fonix_app/domain/curriculum.dart';
import 'package:fonix_app/domain/learning.dart';
import 'fake_device.dart';

void main(){
  late Curriculum c;
  setUp(()=>c=Curriculum.decode(File('assets/data/curriculum.json').readAsStringSync()));
  test('a completed session awards food exactly once across restarts',(){
    final state=LearningState();
    expect(state.finish(0,'session-a'),isTrue);
    expect(state.finish(0,'session-a'),isFalse);
    final restored=LearningState.decode(state.encode());
    expect(restored.finish(0,'session-a'),isFalse);
    expect(restored.food,1);expect(restored.stars,1);
    expect(restored.finish(0,'session-b'),isTrue);
    expect(restored.food,2);expect(restored.stars,1);
  });
  test('recording, skips and hints never turn into correct answers',(){
    final state=LearningState();final now=DateTime(2026,11,1);
    for(var i=0;i<6;i++)state.record(Attempt('s','q$i',true,true,now.add(Duration(days:i)),direction:i.isEven?'textToSound':'soundToText'));
    state.record(Attempt('s','voice',null,false,now,direction:'speaking'));
    expect(state.mastery('s'),'まだ かくにんしていない');
    state.record(Attempt('s','wrong',false,false,now));
    expect(state.mastery('s'),'れんしゅうちゅう');
  });
  test('mastery needs two directions and independent learning days',(){
    final state=LearningState();final now=DateTime(2026,11,1);
    for(var i=0;i<5;i++)state.record(Attempt('s','q$i',i!=0,false,now.add(Duration(days:i)),direction:i.isEven?'textToSound':'soundToText'));
    expect(state.mastery('s'),'みについてきた');
    final oneDirection=LearningState();
    for(var i=0;i<5;i++)oneDirection.record(Attempt('s','q$i',true,false,now.add(Duration(days:i))));
    expect(oneDirection.mastery('s'),'れんしゅうちゅう');
  });
  test('corrective help never erases an initially wrong answer from mastery',(){
    final state=LearningState();
    for(var i=0;i<8;i++)state.record(Attempt('s','q$i',i<4,i>=4,
      DateTime(2026,11,i+1),direction:i.isEven?'textToSound':'soundToText'));
    expect(state.mastery('s'),'れんしゅうちゅう');
  });
  test('reviews are bounded and unknown skills never appear',(){
    final state=LearningState();final now=DateTime(2026,11,1);
    for(final skill in ['s','a','t','oa','word:rain'])state.record(Attempt(skill,skill,false,false,now));
    final reviews=state.reviews(now,2,c);
    expect(reviews.length,2);expect(reviews, isNot(contains('oa')));
    expect(reviews,isNot(contains('word:rain')));
  });
  test('unseen checkpoint words are not leaked by regular question generation',(){
    final held=c.words.where((w)=>w.heldOut).map((w)=>w.text).toSet();
    for(final lesson in c.lessons.where((l)=>!l.checkpoint)){
      for(final q in QuestionFactory(c).forLesson(lesson)){
        if(q.word!=null){expect(held.contains(q.word!.text),isFalse);expect(c.isDecodable(q.word!,lesson.index),isTrue);}
        expect(q.choices.toSet().length,q.choices.length);
      }
    }
  });
  test('sound-only choices do not pit identical phonemes against each other',(){
    for(final lesson in c.lessons.where((l)=>!l.checkpoint)){
      final q=QuestionFactory(c).forLesson(lesson).first;
      final sound=c.sound(lesson.skill);
      for(final choice in q.choices.where((v)=>v!=q.answer)){
        expect(c.sounds.where((s)=>s.label==choice).every((s)=>s.ipa!=sound.ipa),isTrue);
      }
    }
  });
  test('unknown sound IDs fail explicitly instead of teaching the first sound',(){
    expect(()=>c.sound('missing-sound'),throwsStateError);
    expect(c.sound('s').ipa,'s');
  });
  test('each consonant cluster lesson focuses its onset or coda',(){
    for(final cluster in ['st','sp','bl','pl','nd','nt']){
      final lesson=c.lessons.firstWhere((l)=>l.skill==cluster&&!l.checkpoint);
      final words=c.examples(lesson);
      expect(words,isNotEmpty,reason:cluster);
      for(final word in words){
        expect(c.isDecodable(word,lesson.index),isTrue,reason:word.text);
        expect(cluster=='nd'||cluster=='nt'?word.text.endsWith(cluster):word.text.startsWith(cluster),
          isTrue,reason:'$cluster lesson must focus on its cluster, not an unrelated CVC word');
      }
      final questions=QuestionFactory(c).forLesson(lesson).where((q)=>q.word!=null);
      expect(questions,isNotEmpty,reason:cluster);
      expect(questions.every((q)=>words.contains(q.word)),isTrue);
    }
  });
  test('component playback cannot substitute ju for the u in contextual u_e words',(){
    for(final text in ['tube','tune','flute','rude','rule']){
      expect(c.canBlend(c.words.firstWhere((w)=>w.text==text)),isFalse,reason:text);
    }
    for(final text in ['cat','ship','stop','hand','cake','rain','cute']){
      expect(c.canBlend(c.words.firstWhere((w)=>w.text==text)),isTrue,reason:text);
    }
    final word=c.words.firstWhere((w)=>w.text=='dog');
    final glyphVariant=Word(text:word.text,ipa:word.ipa.replaceAll('ɡ','g'),
      meaning:word.meaning,skills:word.skills);
    expect(c.canBlend(glyphVariant),isTrue,reason:'g and ɡ are the same IPA glyph convention');
  });
  test('a sound question never offers two copies of one label or phoneme',(){
    Sound sound(String id,String label,String ipa)=>Sound(id:id,label:label,ipa:ipa,
      hint:'',example:'sat',audio:'assets/audio/sound_$id.wav');
    for(final alternatives in [
      [sound('k','k','k'),sound('ck','ck','k')],
      [sound('th','th','θ'),sound('thv','th','ð')],
    ]){
      final fixture=Curriculum([sound('s','s','s'),...alternatives],[],
        [const Lesson(0,'s','s')],[]);
      final question=QuestionFactory(fixture).forLesson(fixture.lessons.first).single;
      expect(question.choices,contains('s'));
      expect(question.choices.length,2,reason:'Only one distinct distractor exists');
      expect(question.choices.toSet().length,question.choices.length);
      final phonemes=question.choices.map((label)=>fixture.sounds.firstWhere((s)=>s.label==label).ipa);
      expect(phonemes.toSet().length,question.choices.length);
    }
  });
  test('island three checkpoint checks newly learned spellings, not island two again',(){
    final second=QuestionFactory(c).forLesson(c.lessons[13]).map((q)=>q.answer).toSet();
    final third=QuestionFactory(c).forLesson(c.lessons[20]);
    expect(third,hasLength(5));
    expect(third.map((q)=>q.answer).toSet(),isNot(equals(second)));
    for(final question in third){
      expect(question.word,isNotNull);
      expect(question.word!.heldOut,isTrue);
      expect(c.isDecodable(question.word!,20),isTrue);
      expect(c.isDecodable(question.word!,13),isFalse,
        reason:'Island three must check the new short vowels or consonants');
    }
  });
  test('every checkpoint is bounded, decodable and deterministic',(){
    for(final lesson in c.lessons.where((l)=>l.checkpoint)){
      final first=QuestionFactory(c).forLesson(lesson);
      final repeated=QuestionFactory(c).forLesson(lesson);
      expect(first,hasLength(5));
      expect(first.map((q)=>q.id),orderedEquals(repeated.map((q)=>q.id)));
      expect(first.map((q)=>q.answer).toSet(),hasLength(5));
      expect(first.every((q)=>q.word!=null&&c.isDecodable(q.word!,lesson.index)),isTrue);
      expect(first.every((q)=>q.choices.toSet().length==q.choices.length),isTrue);
    }
  });
  test('placement stops at the first unconfirmed prerequisite',(){
    expect(Placement.recommend([true,true,false,true,true,true]),7);
    expect(Placement.recommend([true]),0);
    expect(Placement.recommend(List.filled(12,true)),35);
  });
  test('failed saves preserve the last durable state',()async{
    final device=FakeDevice()..failSave=true;
    final app=AppController(c,device,LearningState());
    await expectLater(app.change((s)=>s.finish(0,'failed')),throwsStateError);
    expect(app.state.completed,isEmpty);expect(app.state.food,0);
  });
  test('concurrent changes are serialized without losing rewards',()async{
    final app=AppController(c,FakeDevice(),LearningState());
    await Future.wait([app.change((s)=>s.finish(0,'one')),app.change((s)=>s.finish(1,'two'))]);
    expect(app.state.completed,{0,1});expect(app.state.food,2);
  });
  test('unknown data versions are preserved by failing instead of resetting',(){
    expect(()=>LearningState.decode('{"schema":99}'),throwsFormatException);
  });
}
