import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import 'art.dart';
import 'lesson.dart';
import 'shell.dart' show message;

Future<String?> askPin(BuildContext context,{bool create=false}) async {
  final input=TextEditingController(),confirmation=TextEditingController();
  final form=GlobalKey<FormState>();
  final result=await showDialog<String>(context:context,builder:(context)=>AlertDialog(
    title:Text(create?'保護者用PINを決める':'おうちのひとの PIN'),
    content:SizedBox(width:360,child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(create?'数字4〜8桁を設定してください。忘れた場合は、端末のアプリ設定からデータを消去して再設定します。学習記録も消去されます。':'保護者用の設定を開きます。'),const SizedBox(height:16),
      TextFormField(controller:input,obscureText:true,keyboardType:TextInputType.number,maxLength:8,
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(labelText:'PIN'),
        validator:(v)=>(v?.length??0)<4?'4〜8桁で入力してください':null),
      if(create)TextFormField(controller:confirmation,obscureText:true,keyboardType:TextInputType.number,maxLength:8,
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(labelText:'もう一度入力'),
        validator:(v)=>v!=input.text?'同じPINを入力してください':null),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('もどる')),
      FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,input.text);},child:const Text('すすむ'))],
  ));
  // Controllers are owned by the dialog route; defer disposal until its closing animation ends.
  await Future<void>.delayed(const Duration(milliseconds:300));
  input.dispose();confirmation.dispose();return result;
}

Future<void> openParent(BuildContext context,AppController app)async{
  final pin=await askPin(context);
  if(pin==null||!context.mounted)return;
  try{
    final valid=await app.device.verifyPin(pin);
    if(!context.mounted)return;
    if(!valid){message(context,'PINが違います。繰り返し間違えた場合は時間をおいてください。');return;}
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>ParentScreen(app:app)));
  }catch(_){if(context.mounted)message(context,'設定を開けませんでした。時間をおいてお試しください。');}
}

class SetupScreen extends StatefulWidget {
  final AppController app;
  const SetupScreen({super.key,required this.app});
  @override State<SetupScreen> createState()=>_SetupScreenState();
}
class _SetupScreenState extends State<SetupScreen> {
  bool busy=false;
  Future<void> begin(bool diagnose)async{
    if(busy)return;setState(()=>busy=true);
    try{
      final hasPin=await widget.app.device.hasPin();
      if(!mounted)return;
      if(!hasPin){
        final pin=await askPin(context,create:true);
        if(pin==null)return;
        await widget.app.device.setPin(pin);
      }
      if(!mounted)return;
      // Start the route before replacing this setup widget with the home screen.
      if(diagnose)Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>PlacementScreen(app:widget.app)));
      await widget.app.change((s)=>s.setup=true);
    }catch(_){if(mounted)message(context,'設定を保存できませんでした。もう一度お試しください。');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(32),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:Column(children:[
      const Animal(size:130),const Text('おとの ぼうけんへ、ようこそ。',textAlign:TextAlign.center,style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:ink)),
      const SizedBox(height:16),const Text('はじめに、おうちのひとと じゅんびしよう。',style:TextStyle(color:muted)),const SizedBox(height:20),
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:paper,borderRadius:BorderRadius.circular(22)),child:const Text(
        '保護者の方へ\n\n1回3〜5分、文字と音を楽しく学ぶアプリです。録音は端末内で扱い、外部には送信しません。マイクを使わなくても学習できます。\n\n現在は家庭向けの開発版です。音声・口の図は監修前の教材です。発音の正誤を自動判定する機能はまだ有効になっていません。')),
      const SizedBox(height:22),Wrap(spacing:12,runSpacing:12,alignment:WrapAlignment.center,children:[
        FilledButton(onPressed:busy?null:()=>begin(true),child:Text(busy?'じゅんびちゅう…':'おためしクイズから はじめる')),
        OutlinedButton(onPressed:busy?null:()=>begin(false),child:const Text('はじめの しまから あそぶ')),
      ]),
    ]))))));
}

class ParentScreen extends StatefulWidget {
  final AppController app;
  const ParentScreen({super.key,required this.app});
  @override State<ParentScreen> createState()=>_ParentScreenState();
}
class _ParentScreenState extends State<ParentScreen> with WidgetsBindingObserver {
  late Future<List<String>> saved;
  bool busy=false,locked=false;
  AppController get app=>widget.app;
  @override void initState(){super.initState();saved=app.device.recordings();WidgetsBinding.instance.addObserver(this);}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused){locked=true;}
    if(state==AppLifecycleState.resumed&&locked&&mounted){
      WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)Navigator.of(context).popUntil((r)=>r.isFirst);});
    }
  }
  Future<void> action(Future<void> Function() run)async{
    if(busy)return;setState(()=>busy=true);
    try{await run();if(mounted)setState(()=>saved=app.device.recordings());}
    catch(_){if(mounted)message(context,'保存・操作に失敗しました。既存のデータは自動消去していません。');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<bool> confirm(String text)async=>await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
    title:const Text('確認'),content:Text(text),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('キャンセル')),
      FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('削除する'))]))??false;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('おうちのひとへ')),
    body:ListenableBuilder(listenable:app,builder:(context,_)=>ListView(padding:const EdgeInsets.all(24),children:[
      _heading('学習の記録'),
      Text('完了：${app.state.completed.length} / 70 レッスン　仲間：${app.state.unlockedAnimals}匹'),
      Text('学習した回数：${app.state.sessions.length}回　合計：${app.state.sessions.fold<int>(0,(n,s)=>n+(s['seconds'] as int))~/60}分'),
      Text('お試しクイズ：${app.state.placement.isEmpty?'未実施':'${app.state.placement.where((v)=>v).length} / ${app.state.placement.length}問を確認'}'),
      Builder(builder:(_){
        final first=app.state.attempts.where((a)=>a.correct!=null).toList();
        final right=first.where((a)=>a.correct==true).length;
        return Text('初回解答：$right / ${first.length} 正解　未解答：${app.state.attempts.where((a)=>a.correct==null&&a.direction!='speaking').length}件\n録音を伴う発話練習：${app.state.attempts.where((a)=>a.direction=='speaking').length}回');
      }),const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:app.state.due.keys.map((s)=>Chip(label:Text('${s.startsWith('word:')?s.substring(5):app.curriculum.sound(s).label}：${app.state.mastery(s)}'))).toList()),
      const Divider(height:32),_heading('学習設定'),
      SwitchListTile(title:const Text('音の図鑑にIPAを表示'),value:app.state.showIpa,onChanged:busy?null:(v)=>action(()=>app.change((s)=>s.showIpa=v))),
      SwitchListTile(title:const Text('録音機能を使う'),subtitle:const Text('マイク権限は録音を開始するときに確認します。'),value:app.state.microphone,
        onChanged:busy?null:(v)=>action(()=>app.change((s)=>s.microphone=v))),
      const Text('教材の音量'),Slider(value:app.state.volume,onChanged:busy?null:(v)=>action(()=>app.change((s)=>s.volume=v))),
      DropdownButtonFormField<int>(initialValue:app.state.startAt~/7,decoration:const InputDecoration(labelText:'最初の開始地点'),
        items:List.generate(10,(i)=>DropdownMenuItem(value:i,child:Text('島 ${i+1}：${app.curriculum.islands[i].name}'))),
        onChanged:busy?null:(v){if(v!=null)action(()=>app.change((s)=>s.startAt=v*7));}),
      const SizedBox(height:12),OutlinedButton(onPressed:busy?null:()=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>PlacementScreen(app:app))),child:const Text('お試しクイズをやり直す')),
      const Divider(height:32),_heading('発音チェックとプライバシー'),
      const Text('録音・お手本との聴き比べを利用できます。無音や入力が大きすぎる場合の案内は、発音の正誤とは別の確認です。\n\n単音・単語の自動評価は、子どもの声とFire実機での検証が完了していないため無効です。オンライン評価も未接続で、アプリは録音を外部へ送信しません。'),
      const SwitchListTile(title:Text('オンラインで詳しく評価'),subtitle:Text('利用条件・精度・費用の確認後に提供予定'),value:false,onChanged:null),
      const SizedBox(height:12),_heading('保存した録音（最大20件）'),
      FutureBuilder<List<String>>(future:saved,builder:(context,snapshot){
        if(snapshot.hasError)return const Text('録音一覧を読み込めませんでした。');
        if(!snapshot.hasData)return const LinearProgressIndicator();
        if(snapshot.data!.isEmpty)return const Text('保存した録音はありません。');
        return Column(children:snapshot.data!.map((id)=>ListTile(title:Text('録音 ${id.replaceAll('.wav','')}'),
          leading:IconButton(tooltip:'再生',onPressed:busy?null:()=>action(()=>app.device.playRecording(id)),icon:const Icon(Icons.play_circle_outline)),
          trailing:IconButton(tooltip:'削除',onPressed:busy?null:()async{
            if(await confirm('この録音を削除しますか？'))await action(()=>app.device.deleteRecording(id));
          },icon:const Icon(Icons.delete_outline)))).toList());
      }),const SizedBox(height:12),
      OutlinedButton(onPressed:busy?null:()async{
        if(await confirm('保存した録音をすべて削除しますか？ 学習進行は残ります。'))await action(()async{for(final id in await app.device.recordings()){await app.device.deleteRecording(id);}});
      },child:const Text('録音をすべて削除')),
      const Divider(height:32),_heading('教材・アプリについて'),
      const Text('家庭向け開発版 0.1.0\n音声：eSpeak NGによる米語の仮音声（監修前）。口の図・説明・問題は教材レビュー前です。\n広告・購入・外部リンクはありません。アプリの更新は保護者が行います。'),
      const Divider(height:32),_heading('データ管理'),
      OutlinedButton(onPressed:busy?null:()async{
        final pin=await askPin(context,create:true);if(pin!=null)await action(()=>app.device.setPin(pin));
      },child:const Text('保護者用PINを変更')),
      const SizedBox(height:12),OutlinedButton(onPressed:busy?null:()async{
        if(await confirm('学習履歴・進行・仲間・ごはんを初期化しますか？ 録音と保護者用PINは残ります。')){
          await action(()=>app.change((s){s.completed.clear();s.attempts.clear();s.due.clear();s.intervals.clear();s.rewards.clear();s.sessions.clear();s.placement.clear();s.startAt=0;s.food=0;s.companion=0;}));
        }
      },child:const Text('学習進行を初期化')),
      const SizedBox(height:12),OutlinedButton(onPressed:busy?null:()async{
        if(await confirm('録音・学習・設定・保護者用PINをすべて削除しますか？ 元に戻せません。')){
          await action(()=>app.reset());if(context.mounted)Navigator.pop(context);
        }
      },child:const Text('すべての端末内データを削除')),
      const SizedBox(height:32),
    ])));
  Widget _heading(String s)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Text(s,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:ink)));
}
