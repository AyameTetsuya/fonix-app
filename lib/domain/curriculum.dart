import 'dart:convert';

class Sound {
  final String id, label, ipa, hint, example, audio;
  const Sound({required this.id, required this.label, required this.ipa,
    required this.hint, required this.example, required this.audio});
  factory Sound.fromJson(Map<String, dynamic> j) => Sound(
    id: j['id'], label: j['label'], ipa: j['ipa'], hint: j['hint'],
    example: j['example'], audio: j['audio']);
}

class Word {
  final String text, ipa, meaning;
  final List<String> skills;
  final bool heldOut, blend;
  const Word({required this.text, required this.ipa, required this.meaning,
    required this.skills, this.heldOut = false, this.blend = false});
  factory Word.fromJson(Map<String, dynamic> j) => Word(
    text: j['text'], ipa: j['ipa'], meaning: j['meaning'],
    skills: List<String>.from(j['skills']), heldOut: j['heldOut'] ?? false,
    blend: j['blend'] ?? false);
  String get audio => 'assets/audio/word_$text.wav';
}

class Lesson {
  final int index;
  final String title, skill;
  const Lesson(this.index, this.title, this.skill);
  String get id => 'lesson_${index.toString().padLeft(2, '0')}';
  int get island => index ~/ 7;
  bool get checkpoint => index % 7 == 6;
}

class Island {
  final String name, subtitle, animal;
  final int color;
  const Island(this.name, this.subtitle, this.animal, this.color);
}

class Curriculum {
  final List<Sound> sounds;
  final List<Word> words;
  final List<Lesson> lessons;
  final List<Island> islands;
  final Map<String, int> introduced;
  Curriculum(this.sounds, this.words, this.lessons, this.islands)
    : introduced = {for (final l in lessons) if (!l.checkpoint) l.skill: l.index};
  factory Curriculum.decode(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final lessons = <Lesson>[];
    final islands = <Island>[];
    for (final island in j['islands'] as List) {
      islands.add(Island(island['name'], island['subtitle'], island['animal'], island['color']));
      for (final l in island['lessons'] as List) {
        lessons.add(Lesson(lessons.length, l['title'], l['skill']));
      }
    }
    return Curriculum((j['sounds'] as List).map((s) => Sound.fromJson(s)).toList(),
      (j['words'] as List).map((w) => Word.fromJson(w)).toList(), lessons, islands);
  }
  Sound sound(String id) => sounds.firstWhere((s) => s.id == id,
    orElse: () => throw StateError('Unknown curriculum sound: $id'));
  bool isDecodable(Word word, int index) =>
    word.skills.every((s) => introduced.containsKey(s) && introduced[s]! <= index) &&
    (!word.blend || index >= 42);
  List<Word> available(int index, {bool heldOut = false}) =>
    words.where((w) => w.heldOut == heldOut && isDecodable(w, index)).toList();
  List<Word> examples(Lesson lesson) {
    final eligible = available(lesson.index);
    bool focusedOn(Word word) {
      if (word.skills.contains(lesson.skill)) return true;
      // Clusters are stored as their component sounds, not as digraph tokens.
      if (word.skills.length < 2) return false;
      if (const {'st', 'sp', 'bl', 'pl'}.contains(lesson.skill)) {
        return word.skills.take(2).join() == lesson.skill;
      }
      if (const {'nd', 'nt'}.contains(lesson.skill)) {
        return word.skills.skip(word.skills.length - 2).join() == lesson.skill;
      }
      return false;
    }
    final focused = eligible.where(focusedOn).toList();
    return focused.isNotEmpty ? focused : eligible;
  }
  // Conservatively expose component playback only when its declared sounds
  // actually reconstruct the word's IPA. Do not guess contextual variants.
  bool canBlend(Word word) {
    String normalized(String ipa) => ipa.replaceAll('g', 'ɡ');
    final components = word.skills.map((id) => sound(id).ipa).join();
    return normalized(components) == normalized(word.ipa);
  }
  List<Word> distractors(Word word,int index){
    final result=available(index).where((w)=>w.text!=word.text&&w.ipa!=word.ipa).toList();
    List<String> tokens(String ipa)=>RegExp('tʃ|dʒ|eɪ|aɪ|oʊ|.').allMatches(ipa).map((m)=>m.group(0)!).toList();
    bool minimal(Word other){
      final a=tokens(word.ipa),b=tokens(other.ipa);
      return a.length==b.length&&List.generate(a.length,(i)=>a[i]!=b[i]?1:0).fold(0,(int x,int y)=>x+y)==1;
    }
    result.sort((a,b)=>(minimal(a)?0:1).compareTo(minimal(b)?0:1));
    return result;
  }
}
