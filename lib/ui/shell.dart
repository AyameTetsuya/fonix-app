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
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: app,
    builder: (context, _) {
      if (!app.state.setup) return SetupScreen(app: app);
      return Scaffold(body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 750;
        final body = [
          HomeScreen(app: app, onMap: () => setState(() { page = 1; })),
          MapScreen(app: app), FriendsScreen(app: app), DictionaryScreen(app: app),
        ][page];
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 12, 20, 10), child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.explore_outlined, color: paper, size: 28)),
            const SizedBox(width: 12), const Text('わくわくフォニックス', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
            const Spacer(), Chip(avatar: const Icon(Icons.star_rounded, color: Color(0xFFDDA44A)), label: Text('${app.state.stars}')),
            const SizedBox(width: 12), IconButton(tooltip: 'おうちのひとへ', onPressed: () => openParent(context,app), icon: const Icon(Icons.tune_rounded)),
          ])),
          Expanded(child: Row(children: [
            if (wide) Padding(padding: const EdgeInsets.only(left:12),child: NavigationRail(
              backgroundColor: Colors.transparent, selectedIndex: page, labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() { page=i; }),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.cottage_outlined), selectedIcon: Icon(Icons.cottage), label: Text('ホーム')),
                NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('ぼうけん')),
                NavigationRailDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: Text('なかま')),
                NavigationRailDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: Text('おとのずかん')),
              ])),
            Expanded(child: body),
          ])),
          if (!wide) NavigationBar(selectedIndex:page,onDestinationSelected:(i)=>setState((){page=i;}),destinations: const [
            NavigationDestination(icon:Icon(Icons.cottage_outlined),label:'ホーム'),
            NavigationDestination(icon:Icon(Icons.map_outlined),label:'ぼうけん'),
            NavigationDestination(icon:Icon(Icons.pets_outlined),label:'なかま'),
            NavigationDestination(icon:Icon(Icons.auto_stories_outlined),label:'ずかん'),
          ]),
        ]);
      })));
    });
}

class HomeScreen extends StatelessWidget {
  final AppController app;
  final VoidCallback onMap;
  const HomeScreen({super.key, required this.app, required this.onMap});
  @override Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.wb_sunny_outlined,size:18,color:muted),const SizedBox(width:8),
        Text('きょうも、${friendNames[app.state.companion]}と いっしょに。',style:const TextStyle(color:muted,fontWeight:FontWeight.w600))]),
      const SizedBox(height:16),
      ClipRRect(borderRadius: BorderRadius.circular(28),child: LayoutBuilder(builder:(context,c) {
        final wide=c.maxWidth>650;
        final intro=Padding(padding:const EdgeInsets.all(28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('LITTLE SOUNDS, BIG ADVENTURES',style:TextStyle(fontSize:10,letterSpacing:2,color:muted,fontWeight:FontWeight.w700)),
          const SizedBox(height:15), const Text('きょうも、\nおとの ぼうけんへ。',style:TextStyle(fontSize:32,height:1.5,fontWeight:FontWeight.w800,color:ink)),
          const SizedBox(height:12),const Text('きいて、つなげて、いってみよう。\nちいさな おとが、ことばに なるよ。',style:TextStyle(height:1.9,color:muted)),
          const SizedBox(height:22), FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink),
            onPressed:()=>startLesson(context,app,app.state.nextLesson),icon:const Icon(Icons.play_arrow_rounded),
            label:Text(app.state.completed.length==70?'もういちど あそぶ':'ぼうけんを はじめる')),
          const SizedBox(height:10), const Text('1かい 3〜5ふん ・ ネットなしでも あそべる',style:TextStyle(fontSize:11,color:muted)),
        ]));
        return ColoredBox(color:const Color(0xFFF0F0E4),child:wide
          ? SizedBox(height:390,child:Row(children:[Expanded(flex:5,child:intro),const Expanded(flex:5,child:AdventureScene())]))
          : Column(children:[intro,const SizedBox(height:200,child:AdventureScene())]));
      })),
      const SizedBox(height:24), Row(children:[const Text('きみの ぼうけん',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:ink)),const Spacer(),TextButton(onPressed:onMap,child:const Text('ちずを みる →'))]),
      const SizedBox(height:12), Wrap(spacing:16,runSpacing:16,children:[
        _Stat(Icons.flag_outlined,'すすんだ レッスン','${app.state.stars} / 70'),
        _Stat(Icons.pets_outlined,'ぼうけんの なかま','${app.state.unlockedAnimals} ひき'),
        _Stat(Icons.spa_outlined,'なかまの ごはん','${app.state.food} こ'),
      ]),
    ]));
}

class _Stat extends StatelessWidget {
  final IconData icon; final String title,value;
  const _Stat(this.icon,this.title,this.value);
  @override Widget build(BuildContext context)=>Container(width:215,padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(color:paper,borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE8E9DD))),
    child:Row(children:[Icon(icon,color:const Color(0xFF9CAC87),size:30),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:11,color:muted)),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),
    ]))]));
}

class MapScreen extends StatelessWidget {
  final AppController app;
  const MapScreen({super.key,required this.app});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('おとの しまを めぐろう',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:6),const Text('ひとつずつ、できることが ふえていく。',style:TextStyle(color:muted)),const SizedBox(height:22),
    LayoutBuilder(builder:(context,c)=>Wrap(spacing:16,runSpacing:16,children:List.generate(10,(i){
      final island=app.curriculum.islands[i],open=app.state.unlocked(i*7);
      final completed=app.state.completed.where((l)=>l~/7==i).length;
      return SizedBox(width:(c.maxWidth-16*(c.maxWidth>900?2:1))/(c.maxWidth>900?3:2),child:Material(color:open?paper:const Color(0xFFF0F0E8),
        borderRadius:BorderRadius.circular(24),child:InkWell(borderRadius:BorderRadius.circular(24),onTap:open?()=>_lessons(context,i):null,
          child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:Color(island.color).withValues(alpha:.15),borderRadius:BorderRadius.circular(8)),child:Text('ISLAND ${(i+1).toString().padLeft(2,'0')}',style:TextStyle(fontSize:10,letterSpacing:1,color:Color(island.color),fontWeight:FontWeight.w800))),const Spacer(),Icon(open?Icons.arrow_forward_rounded:Icons.lock_outline,color:muted,size:20)]),
            Center(child:Opacity(opacity:open?1:.35,child:Animal(species:i+1,size:100))),
            Text(island.name,style:TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:open?ink:muted)),
            const SizedBox(height:5),Text(island.subtitle,style:const TextStyle(fontSize:11,color:muted)),const SizedBox(height:14),
            LinearProgressIndicator(value:completed/7,borderRadius:BorderRadius.circular(5),minHeight:5,color:Color(island.color),backgroundColor:const Color(0xFFE9EDDF)),
            const SizedBox(height:7),Text(open?'$completed / 7 レッスン':'まえの しまから すすもう',style:const TextStyle(fontSize:11,color:muted)),
          ])))));
    }))),
  ]));
  void _lessons(BuildContext context,int island)=>showModalBottomSheet<void>(context:context,isScrollControlled:true,
    builder:(context)=>SafeArea(child:SizedBox(height:500,child:ListView(padding:const EdgeInsets.all(24),children:[
      Text(app.curriculum.islands[island].name,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:16),
      ...app.curriculum.lessons.where((l)=>l.island==island).map((l)=>ListTile(minTileHeight:60,
        leading:Icon(app.state.completed.contains(l.index)?Icons.check_circle:app.state.unlocked(l.index)?Icons.play_circle_outline:Icons.lock_outline,color:ink),
        title:Text(l.title),subtitle:Text(l.checkpoint?'しまの まとめ':'レッスン ${l.index%7+1}'),
        enabled:app.state.unlocked(l.index),onTap:(){Navigator.pop(context);startLesson(context,app,l.index);})),
    ]))));
}

class FriendsScreen extends StatefulWidget {
  final AppController app;
  const FriendsScreen({super.key,required this.app});
  @override State<FriendsScreen> createState()=>_FriendsScreenState();
}
class _FriendsScreenState extends State<FriendsScreen> {
  String feedback='きょうは なにを しようかな？'; bool busy=false;
  AppController get app=>widget.app;
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('ぼうけんの なかま',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:ink)),
    const SizedBox(height:20),Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:const Color(0xFFEDF0E2),borderRadius:BorderRadius.circular(26)),
      child:Wrap(alignment:WrapAlignment.center,crossAxisAlignment:WrapCrossAlignment.center,spacing:32,runSpacing:16,children:[
        Animal(species:app.state.companion,size:150),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(friendNames[app.state.companion],style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:8),Text(feedback),
          const SizedBox(height:20),Wrap(spacing:10,runSpacing:10,children:[
            FilledButton.icon(onPressed:busy||app.state.food==0?null:()async{
              setState(()=>busy=true);
              try {await app.change((s)=>s.feed());if(mounted)setState(()=>feedback='もぐもぐ。ありがとう！');}
              catch(_){if(context.mounted)message(context,'ほぞんできなかったよ。もういちど おためしください。');}
              finally{if(mounted)setState(()=>busy=false);}
            },icon:const Icon(Icons.spa_outlined),label:Text('ごはんを あげる (${app.state.food})')),
            OutlinedButton.icon(onPressed:()=>setState(()=>feedback='なでなで。とっても うれしそう！'),icon:const Icon(Icons.favorite_border),label:const Text('なでる')),
          ]),
        ]),
      ])),const SizedBox(height:24),const Text('いっしょに いく なかまを えらぼう',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:ink)),
    const SizedBox(height:16),Wrap(spacing:14,runSpacing:14,children:List.generate(11,(i){
      final unlocked=i<app.state.unlockedAnimals,selected=i==app.state.companion;
      return SizedBox(width:138,child:OutlinedButton(style:OutlinedButton.styleFrom(backgroundColor:selected?const Color(0xFFDEE8D6):paper,
        side:BorderSide(color:selected?ink:const Color(0xFFE3E6DA))),onPressed:!unlocked||busy?null:()async{
          setState(()=>busy=true);try{await app.change((s)=>s.companion=i);}catch(_){if(context.mounted)message(context,'ほぞんできませんでした。');}
          finally{if(mounted)setState(()=>busy=false);}
        },child:Column(children:[if(unlocked)Animal(species:i,size:76)else const Padding(padding:EdgeInsets.all(23),child:Icon(Icons.lock_outline)),
          Text(unlocked?friendNames[i]:'しまを すすもう',style:const TextStyle(fontSize:12))])));
    })),
  ]));
}

class DictionaryScreen extends StatelessWidget {
  final AppController app;
  const DictionaryScreen({super.key,required this.app});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('おとの ずかん',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:6),
    const Text('もじを おすと、おとと くちの ひみつが わかるよ。',style:TextStyle(color:muted)),const SizedBox(height:22),
    ExpansionTile(title:const Text('アルファベットの なまえ・おおもじ・こもじ'),children:[
      Wrap(spacing:8,runSpacing:8,children:'abcdefghijklmnopqrstuvwxyz'.split('').map((letter)=>OutlinedButton(
        onPressed:()=>showDialog<void>(context:context,builder:(context)=>AlertDialog(title:Text('${letter.toUpperCase()}  $letter',style:const TextStyle(fontSize:48,fontWeight:FontWeight.w800)),
          content:const Text('もじの なまえと、ことばの なかの おとは べつだよ。'),actions:[
            TextButton(onPressed:(){app.play('assets/audio/name_$letter.wav').catchError((Object _){if(context.mounted)message(context,'さいせいできなかったよ。');});},child:const Text('もじの なまえ')),
            TextButton(onPressed:()=>showSound(context,app,app.curriculum.sound(letter=='q'?'qu':letter)),child:Text(letter=='q'?'qu の おと':'ことばの なかの おと')),
            TextButton(onPressed:()=>Navigator.pop(context),child:const Text('とじる')),
          ])),child:Text('${letter.toUpperCase()} $letter',style:const TextStyle(fontSize:20)))).toList()),
      const SizedBox(height:20),
    ]),const SizedBox(height:20),
    Wrap(spacing:12,runSpacing:12,children:app.curriculum.sounds.where((s)=>!s.id.startsWith('mix')&&s.id!='review').map((s)=>SizedBox(width:115,height:100,
      child:OutlinedButton(style:OutlinedButton.styleFrom(backgroundColor:paper,side:const BorderSide(color:Color(0xFFE3E6DA))),
        onPressed:()=>showSound(context,app,s),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(s.label,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
          if(app.state.showIpa)Text('/${s.ipa}/',style:const TextStyle(fontSize:13,color:muted)),
        ])))).toList()),
  ]));
}

Future<void> showSound(BuildContext context,AppController app,Sound sound)=>showDialog<void>(context:context,builder:(context)=>AlertDialog(
  title:Row(children:[Text(sound.label,style:const TextStyle(fontSize:32,fontWeight:FontWeight.w800)),const SizedBox(width:20),
    if(app.state.showIpa)Text('/${sound.ipa}/',style:const TextStyle(color:muted)),const Spacer(),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
  content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    MouthDiagram(ipa:sound.ipa),const SizedBox(height:16),Text(sound.hint),const SizedBox(height:20),
    FilledButton.icon(onPressed:()async{try{await app.play(sound.audio);}catch(_){if(context.mounted)message(context,'おとを さいせいできなかったよ。');}},icon:const Icon(Icons.volume_up_outlined),label:const Text('おとを きく')),
    if(sound.label.length==1)Padding(padding:const EdgeInsets.only(top:10),child:OutlinedButton.icon(onPressed:()async{
      try{await app.play('assets/audio/name_${sound.label}.wav');}catch(_){if(context.mounted)message(context,'おとを さいせいできなかったよ。');}
    },icon:const Icon(Icons.abc),label:Text('もじの なまえ (${sound.label.toUpperCase()})'))),
    const SizedBox(height:16),Text('ことばの れい：${sound.example}',style:const TextStyle(color:muted)),
  ]))),
));
