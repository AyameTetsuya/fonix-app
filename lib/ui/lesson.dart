import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app.dart';
import '../domain/curriculum.dart';
import '../domain/learning.dart';
import '../platform/device.dart';
import 'art.dart';
import 'shell.dart' show message;

Future<void> startLesson(BuildContext context,AppController app,int index) async {
  await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>LessonScreen(app:app,lesson:app.curriculum.lessons[index])));
}

class LessonScreen extends StatefulWidget {
  final AppController app;
  final Lesson lesson;
  const LessonScreen({super.key,required this.app,required this.lesson});
  @override State<LessonScreen> createState()=>_LessonScreenState();
}
class _LessonScreenState extends State<LessonScreen> with WidgetsBindingObserver {
  late final List<Question> questions;
  late final String session;
  late final bool firstCompletion;
  int step=-1;
  bool busy=false,done=false;
  final elapsed=Stopwatch();
  AppController get app=>widget.app;
  @override void initState(){
    super.initState();firstCompletion=!app.state.completed.contains(widget.lesson.index);WidgetsBinding.instance.addObserver(this);elapsed.start();session='${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1<<30)}';
    questions=QuestionFactory(app.curriculum).forLesson(widget.lesson,
      reviews:app.state.reviews(DateTime.now(),widget.lesson.index,app.curriculum));
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);elapsed.stop();app.device.stop();app.device.discard();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed&&!done){elapsed.start();}else{elapsed.stop();}
  }
  Future<void> finish()async{
    if(busy)return;setState(()=>busy=true);
    try{await app.change((s)=>s.finish(widget.lesson.index,session,seconds:elapsed.elapsed.inSeconds));
      await app.device.discard();elapsed.stop();if(mounted)setState(()=>done=true);
    }catch(_){if(mounted)message(context,'ほぞんできなかったよ。もういちど おためしください。');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context){
    final sound=app.curriculum.sound(widget.lesson.skill);
    return Scaffold(appBar:AppBar(title:Text(widget.lesson.title),backgroundColor:Colors.transparent,
      leading:IconButton(tooltip:'ぼうけんに もどる',icon:const Icon(Icons.close),onPressed:()async{
        final exit=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
          title:const Text('ひとやすみ する？'),content:const Text('こたえた きろくは のこるよ。この レッスンは あとで はじめから あそべるよ。'),
          actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('つづける')),
            FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('もどる'))]));
        if(exit==true&&context.mounted)Navigator.pop(context);
      })),body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:28),child:LinearProgressIndicator(
        value:done?1:(step+1)/(questions.length+2),minHeight:6,borderRadius:BorderRadius.circular(6))),
      Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
        child:done?_complete():step<0?_intro(sound):step<questions.length
        ?QuestionView(key:ValueKey(step),app:app,question:questions[step],onAnswered:(correct,helped)async{
          await app.change((s)=>s.record(Attempt(questions[step].skill,questions[step].id,correct,helped,DateTime.now(),
            direction:questions[step].kind==QuestionKind.read?'textToSound':'soundToText')));
          if(mounted)setState(()=>step++);
        }):PronunciationPractice(app:app,sound:sound,word:app.curriculum.examples(widget.lesson).firstOrNull,
          onComplete:finish,busy:busy)))),
    ])));
  }
  Widget _intro(Sound sound){
    final word=app.curriculum.examples(widget.lesson).firstOrNull;
    return SingleChildScrollView(padding:const EdgeInsets.all(28),child:Column(children:[
    Text(widget.lesson.checkpoint?'しまの たからさがし！':'きょうの おとを みつけよう',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:16),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      Animal(species:app.state.companion,size:110),const SizedBox(width:24),
      Text(sound.label,style:const TextStyle(fontSize:88,fontWeight:FontWeight.w800,color:ink)),
      const SizedBox(width:24),MouthDiagram(ipa:sound.ipa),
    ]),const SizedBox(height:12),Text(sound.hint,textAlign:TextAlign.center),
    if(word!=null)...[
      const SizedBox(height:12),const Text('おとを つなげてみよう',style:TextStyle(color:muted)),
      Wrap(spacing:4,alignment:WrapAlignment.center,children:[
        ...word.skills.map((id)=>TextButton(onPressed:()=>_play(app.curriculum.sound(id).audio),
          child:Text(app.curriculum.sound(id).label,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)))),
        IconButton(tooltip:'つなげた ことば',onPressed:()=>_play(word.audio),icon:const Icon(Icons.volume_up)),
        Text(word.text,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),
      ]),
    ],const SizedBox(height:20),
    Wrap(spacing:12,runSpacing:12,alignment:WrapAlignment.center,children:[
      OutlinedButton.icon(onPressed:()=>_play(sound.audio),icon:const Icon(Icons.volume_up),label:const Text('おとを きく')),
      if(sound.label.length==1)OutlinedButton.icon(onPressed:()=>_play('assets/audio/name_${sound.label}.wav'),icon:const Icon(Icons.abc),label:Text('もじの なまえ ${sound.label.toUpperCase()}')),
      FilledButton.icon(onPressed:()=>setState(()=>step=0),icon:const Icon(Icons.arrow_forward),label:const Text('やってみよう')),
    ]),
  ]));}
  Future<void> _play(String asset)async{try{await app.play(asset);}catch(_){if(mounted)message(context,'おとを さいせいできなかったよ。');}}
  Widget _complete()=>SingleChildScrollView(padding:const EdgeInsets.all(28),child:Column(children:[
    const Icon(Icons.auto_awesome_rounded,size:55,color:orange),const SizedBox(height:12),
    const Text('ぼうけん できたね！',style:TextStyle(fontSize:32,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:12),Animal(species:app.state.companion,size:130),
    const Text('ごはんを 1こ てにいれたよ。\nまちがえた おとも、また いっしょに やってみよう。',textAlign:TextAlign.center),
    if(widget.lesson.checkpoint&&firstCompletion)const Padding(padding:EdgeInsets.all(12),child:Text('あたらしい なかまが ふえたよ！',style:TextStyle(fontWeight:FontWeight.w800,color:ink))),
    const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('ぼうけんに もどる')),
  ]));
}

typedef AnswerCallback=Future<void> Function(bool? correct,bool helped);
class QuestionView extends StatefulWidget {
  final AppController app;
  final Question question;
  final AnswerCallback onAnswered;
  const QuestionView({super.key,required this.app,required this.question,required this.onAnswered});
  @override State<QuestionView> createState()=>_QuestionViewState();
}
class _QuestionViewState extends State<QuestionView> {
  String? chosen;
  bool? correct;
  bool busy=false;
  final List<int> selected=[];
  late final List<String> letters;
  Question get q=>widget.question;
  @override void initState(){super.initState();letters=q.answer.split('')..shuffle(Random(q.id.hashCode));}
  Future<void> advance({bool skip=false})async{
    if(busy)return;setState(()=>busy=true);
    try{await widget.onAnswered(skip?null:correct,correct==false);}
    catch(_){if(mounted){setState(()=>busy=false);message(context,'ほぞんできなかったよ。もういちど おためしください。');}}
  }
  Future<void> play(String asset)async{try{await widget.app.play(asset);}catch(_){if(mounted)message(context,'おとを さいせいできなかったよ。');}}
  @override Widget build(BuildContext context){
    final caseMatch=q.kind==QuestionKind.read&&q.word==null;
    return SingleChildScrollView(padding:const EdgeInsets.all(28),child:Column(children:[
      IconButton(tooltip:'あそびかたを きく',onPressed:()=>play('assets/audio/guide_${caseMatch?'case':q.kind==QuestionKind.read?'read':q.kind==QuestionKind.build?'build':'listen'}.wav'),icon:const Icon(Icons.hearing_outlined)),
      Text(q.kind==QuestionKind.build?'おとを きいて、ことばを つくろう':q.kind==QuestionKind.fill?'あいている もじは どれかな？':caseMatch?'おなじ もじは どれかな？':q.kind==QuestionKind.read?'この ことばの おとは どれ？':'きこえた おとを えらぼう',
        style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink),textAlign:TextAlign.center),
      const SizedBox(height:24),
      if(q.kind==QuestionKind.read)Text(q.word?.text??q.answer.toLowerCase(),style:const TextStyle(fontSize:56,fontWeight:FontWeight.w800,color:ink))
      else OutlinedButton.icon(onPressed:q.audio==null?null:()=>play(q.audio!),icon:const Icon(Icons.volume_up,size:34),label:const Padding(padding:EdgeInsets.all(12),child:Text('もういちど きく'))),
      const SizedBox(height:24),
      if(q.kind==QuestionKind.fill)Padding(padding:const EdgeInsets.only(bottom:20),child:Text(q.answer.replaceRange(q.blank!,q.blank!+1,'＿'),style:const TextStyle(fontSize:46,letterSpacing:5,fontWeight:FontWeight.w800,color:ink))),
      if(q.kind==QuestionKind.build)...[
        Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),decoration:BoxDecoration(color:const Color(0xFFEAF0E2),borderRadius:BorderRadius.circular(16)),
          child:Text(selected.map((i)=>letters[i]).join().padRight(q.answer.length,'＿'),style:const TextStyle(fontSize:38,letterSpacing:8,color:ink))),
        const SizedBox(height:18),Wrap(spacing:10,runSpacing:10,alignment:WrapAlignment.center,children:List.generate(letters.length,(i)=>OutlinedButton(
          onPressed:chosen!=null||selected.contains(i)?null:()=>setState(()=>selected.add(i)),child:Text(letters[i],style:const TextStyle(fontSize:28))))),
        const SizedBox(height:12),Wrap(spacing:12,children:[TextButton(onPressed:chosen!=null?null:()=>setState(()=>selected.clear()),child:const Text('ならべなおす')),
          FilledButton(onPressed:chosen!=null||selected.length!=letters.length?null:()=>setState((){chosen=selected.map((i)=>letters[i]).join();correct=q.accepts(chosen!);}),child:const Text('これにする'))]),
      ] else Wrap(spacing:16,runSpacing:16,alignment:WrapAlignment.center,children:List.generate(q.choices.length,(i){
        final choice=q.choices[i];
        return SizedBox(width:150,child:Column(children:[
          if(q.kind==QuestionKind.read&&!caseMatch)IconButton.filledTonal(tooltip:'おと ${i+1} を きく',onPressed:()=>play('assets/audio/word_$choice.wav'),icon:const Icon(Icons.volume_up)),
          const SizedBox(height:4),OutlinedButton(style:OutlinedButton.styleFrom(minimumSize:const Size(150,85),
            backgroundColor:chosen==choice?const Color(0xFFE4ECD9):paper,side:BorderSide(color:chosen==choice?ink:const Color(0xFFDDE3D6))),
            onPressed:chosen!=null?null:()=>setState((){chosen=choice;correct=q.accepts(q.kind==QuestionKind.fill?q.answer.replaceRange(q.blank!,q.blank!+1,choice):choice);}),
            child:Text(q.kind==QuestionKind.read&&!caseMatch?'おと ${i+1}':choice,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800))),
        ]));
      })),
      const SizedBox(height:22),
      if(chosen!=null)Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFEAF0E2),borderRadius:BorderRadius.circular(20)),
        child:Column(children:[Text(correct==true?'みつけたね！':'お手本と いっしょに やってみよう。',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:ink)),
          if(correct==false)Text('こたえは「${q.answer}」だよ。'),
          if(q.word!=null)Text('${q.word!.text}：${q.word!.meaning}'),
          const SizedBox(height:12),Wrap(spacing:12,runSpacing:8,alignment:WrapAlignment.center,children:[
            if(q.audio!=null)OutlinedButton.icon(onPressed:()=>play(q.audio!),icon:const Icon(Icons.volume_up),label:const Text('お手本を きく')),
            FilledButton(onPressed:busy?null:()=>advance(),child:Text(busy?'ほぞんちゅう…':'つぎへ')),
          ]),
        ])),
      if(chosen==null)Padding(padding:const EdgeInsets.only(top:8),child:TextButton(onPressed:busy?null:()=>advance(skip:true),child:const Text('いまは とばす'))),
    ]));
  }
}

class PronunciationPractice extends StatefulWidget {
  final AppController app;
  final Sound sound;
  final Word? word;
  final Future<void> Function() onComplete;
  final bool busy;
  const PronunciationPractice({super.key,required this.app,required this.sound,this.word,required this.onComplete,this.busy=false});
  @override State<PronunciationPractice> createState()=>_PronunciationPracticeState();
}
class _PronunciationPracticeState extends State<PronunciationPractice> with WidgetsBindingObserver {
  bool recording=false,working=false,saved=false,wordMode=false,practiceLogged=false;
  int takes=0;
  RecordingResult? result;
  String? error;
  Timer? timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive||state==AppLifecycleState.paused){
      timer?.cancel();widget.app.device.discard();
      if(mounted)setState((){recording=false;result=null;});
    }
  }
  Future<void> toggle()async{
    if(working)return;setState(()=>working=true);
    try{
      if(recording){
        timer?.cancel();final r=await widget.app.device.stopRecording();
        if(mounted)setState((){recording=false;result=r;takes++;saved=false;});
      }else{
        await widget.app.device.discard();await widget.app.device.startRecording();
        if(mounted){setState((){recording=true;result=null;error=null;});timer=Timer(const Duration(seconds:9),(){if(mounted&&recording)toggle();});}
      }
    }catch(_){if(mounted)setState((){recording=false;error='マイクを つかえなかったよ。お手本を きいて、まねしてみよう。';});}
    finally{if(mounted)setState(()=>working=false);}
  }
  Future<void> play({bool own=false,bool slow=false})async{
    try{if(own){await widget.app.device.playRecording();}else{await widget.app.play(wordMode&&widget.word!=null?widget.word!.audio:widget.sound.audio,speed:slow ? 0.75 : 1.0);}}
    catch(_){if(mounted)message(context,'さいせいできなかったよ。もういちど おためしください。');}
  }
  Future<void> complete()async{
    if(widget.busy||working)return;
    setState(()=>working=true);
    try{
      if(result!=null&&!practiceLogged){
        await widget.app.change((s)=>s.record(Attempt(widget.sound.id,
          'voice_${DateTime.now().microsecondsSinceEpoch}',null,false,DateTime.now(),direction:'speaking')));
        practiceLogged=true;
      }
      await widget.onComplete();
    }catch(_){if(mounted)message(context,'きろくを ほぞんできなかったよ。もういちど おためしください。');}
    finally{if(mounted)setState(()=>working=false);}
  }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
    IconButton(tooltip:'あそびかたを きく',onPressed:recording?null:()async{try{await widget.app.play('assets/audio/guide_mic.wav');}catch(_){if(mounted)message(context,'あんないを さいせいできなかったよ。');}},icon:const Icon(Icons.hearing_outlined)),
    const Text('お手本を まねして いってみよう',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),
    if(widget.word!=null)SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('おと')),ButtonSegment(value:true,label:Text('ことば'))],selected:{wordMode},
      onSelectionChanged:recording?null:(s)=>setState(()=>wordMode=s.first)),
    const SizedBox(height:12),Text(wordMode?widget.word!.text:widget.sound.label,style:const TextStyle(fontSize:52,fontWeight:FontWeight.w800,color:ink)),
    Text(widget.sound.hint,textAlign:TextAlign.center),const SizedBox(height:16),
    Wrap(spacing:10,runSpacing:10,alignment:WrapAlignment.center,children:[
      OutlinedButton.icon(onPressed:recording?null:()=>play(),icon:const Icon(Icons.volume_up),label:const Text('お手本')),
      OutlinedButton.icon(onPressed:recording?null:()=>play(slow:true),icon:const Icon(Icons.slow_motion_video),label:const Text('ゆっくり')),
      if(widget.app.state.microphone)FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:recording?const Color(0xFFB95F55):ink),
        onPressed:working||(!recording&&takes>=2)?null:toggle,icon:Icon(recording?Icons.stop:Icons.mic_none),
        label:Text(recording?'ろくおんを とめる':takes==0?'じぶんの こえを ろくおん':'もういちど ろくおん')),
    ]),
    if(recording)const Padding(padding:EdgeInsets.all(12),child:Text('● ろくおんちゅう…',style:TextStyle(color:Color(0xFFB95F55)))),
    if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!)),
    if(result!=null)...[
      Padding(padding:const EdgeInsets.all(14),child:Text(result!.feedback,textAlign:TextAlign.center)),
      Wrap(spacing:10,runSpacing:10,alignment:WrapAlignment.center,children:[
        OutlinedButton.icon(onPressed:()=>play(own:true),icon:const Icon(Icons.hearing),label:const Text('じぶんの こえ')),
        OutlinedButton.icon(onPressed:saved?null:()async{
          try{await widget.app.device.keepRecording();if(mounted)setState(()=>saved=true);}
          catch(_){if(mounted)message(context,'ほぞんできなかったよ。ほぞんは 20こまでだよ。');}
        },icon:const Icon(Icons.bookmark_outline),label:Text(saved?'ほぞんしたよ':'この こえを のこす')),
      ]),
    ],
    const SizedBox(height:16),const Text('お手本と ききくらべ',style:TextStyle(fontSize:12,color:muted)),
    const SizedBox(height:16),FilledButton.icon(onPressed:recording||working||widget.busy?null:complete,
      icon:const Icon(Icons.check),label:Text(widget.busy?'ほぞんちゅう…':'れんしゅうを おえる')),
    if(result==null&&!recording)TextButton(onPressed:working||widget.busy?null:complete,child:const Text('こえを だせないので すすむ')),
  ]));
}

class PlacementScreen extends StatefulWidget {
  final AppController app;
  const PlacementScreen({super.key,required this.app});
  @override State<PlacementScreen> createState()=>_PlacementScreenState();
}
class _PlacementScreenState extends State<PlacementScreen> {
  final answers=<bool>[];
  late final List<Question> questions;
  bool finishing=false;
  @override void initState(){
    super.initState();
    Question sound(String id,List<String> choices)=>Question(id:'placement_${questionsId++}',skill:id,answer:widget.app.curriculum.sound(id).label,
      kind:QuestionKind.listen,choices:choices,audio:widget.app.curriculum.sound(id).audio);
    Question word(String text,List<String> choices,{bool build=false}){
      final w=widget.app.curriculum.words.firstWhere((w)=>w.text==text);
      return Question(id:'placement_${questionsId++}',skill:w.skills.last,answer:text,kind:build?QuestionKind.build:QuestionKind.listen,
        choices:choices,audio:w.audio,word:w);
    }
    questions=[sound('s',['m','s','t']),const Question(id:'placement_case',skill:'a',answer:'a',kind:QuestionKind.read,choices:['N','P','A']),
      sound('m',['m','n','d']),word('map',['map','mad','mat']),word('cat',['cat','cut','cot']),word('pin',[],build:true),
      word('red',['red','bed','rid']),word('van',[],build:true),sound('x',['x','qu','z']),word('box',[],build:true),
      sound('sh',['s','ch','sh']),word('ship',['chip','ship','thin'])];
  }
  int questionsId=0;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('おためし たからさがし')),
    body:Column(children:[Padding(padding:const EdgeInsets.all(20),child:LinearProgressIndicator(value:answers.length/12)),
      Expanded(child:questions.length==answers.length?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Animal(size:110),const Text('おためし できたね！',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:ink)),
        Text('しま ${Placement.recommend(answers)~/7+1} から はじめてみよう。'),const SizedBox(height:20),
        FilledButton(onPressed:finishing?null:()async{
          setState(()=>finishing=true);
          try{await widget.app.change((s){s.startAt=Placement.recommend(answers);s.placement..clear()..addAll(answers);});if(context.mounted)Navigator.pop(context);}
          catch(_){if(context.mounted)message(context,'ほぞんできませんでした。');if(mounted)setState(()=>finishing=false);}
        },child:const Text('ぼうけんへ')),
      ])):QuestionView(key:ValueKey(answers.length),app:widget.app,question:questions[answers.length],onAnswered:(correct,helped)async{
        if(mounted)setState(()=>answers.add(correct==true&&!helped));
      })),
    ]));
}
