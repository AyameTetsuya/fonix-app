import 'dart:convert';
import 'dart:math';
import 'curriculum.dart';

enum QuestionKind { listen, read, build, fill }

class Question {
  final String id, skill, answer;
  final QuestionKind kind;
  final List<String> choices;
  final String? audio;
  final Word? word;
  final int? blank;
  const Question({required this.id, required this.skill, required this.answer,
    required this.kind, required this.choices, this.audio, this.word,this.blank});
  bool accepts(String value) => value.trim().toLowerCase() == answer.toLowerCase();
}

class QuestionFactory {
  final Curriculum curriculum;
  QuestionFactory(this.curriculum);
  List<Question> forLesson(Lesson lesson, {List<String> reviews = const []}) {
    final out = <Question>[];
    for (final skill in reviews.take(2)) {
      if (skill.startsWith('word:')) {
        final matches=curriculum.words.where((w)=>w.text==skill.substring(5)&&curriculum.isDecodable(w,lesson.index));
        if(matches.isNotEmpty){
          final w=matches.first;
          final choices=[w.text,...curriculum.available(lesson.index).where((v)=>v.text!=w.text&&v.ipa!=w.ipa).take(2).map((v)=>v.text)]..shuffle(Random(lesson.index));
          out.add(Question(id:'${lesson.id}_review_${w.text}',skill:skill,answer:w.text,
            kind:QuestionKind.listen,choices:choices,audio:w.audio,word:w));
        }
        continue;
      }
      if (curriculum.introduced[skill] != null && curriculum.introduced[skill]! <= lesson.index) {
        out.add(_soundQuestion(curriculum.sound(skill), '${lesson.id}_review_$skill'));
      }
    }
    final sound = curriculum.sound(lesson.skill);
    if (!lesson.checkpoint) out.add(_soundQuestion(sound, '${lesson.id}_sound'));
    final rng = Random(lesson.index + 41);
    final List<Word> practice;
    if (lesson.checkpoint) {
      final heldOut = curriculum.available(lesson.index, heldOut: true)..shuffle(rng);
      final regular = curriculum.available(lesson.index)..shuffle(rng);
      // Check the island just learned instead of reusing the first five CVC
      // words forever. Prefer reserved words, then fill with eligible practice.
      bool newlyDecodable(Word word) => !curriculum.isDecodable(word, lesson.index - 7);
      practice = [
        ...heldOut.where(newlyDecodable),
        ...regular.where(newlyDecodable),
        ...heldOut.where((word) => !newlyDecodable(word)),
        ...regular.where((word) => !newlyDecodable(word)),
      ];
    } else {
      practice = curriculum.examples(lesson)..shuffle(rng);
    }
    for (final word in practice.take(lesson.checkpoint ? 5 : 3)) {
      final alternatives = curriculum.distractors(word,lesson.index);
      final choices = <String>[word.text, ...alternatives.take(2).map((w) => w.text)]..shuffle(rng);
      final kind=alternatives.isEmpty || (!lesson.checkpoint && out.length % 3 == 0) ? QuestionKind.build
        : !lesson.checkpoint&&out.length%3==2?QuestionKind.fill
        : out.length%3==1?QuestionKind.read:QuestionKind.listen;
      final blank=kind==QuestionKind.fill?word.text.length~/2:null;
      final fillChoices=blank==null?<String>[]:[word.text[blank],... 'aeioutpsnm'.split('').where((s)=>s!=word.text[blank]).take(2)]..shuffle(rng);
      out.add(Question(id: '${lesson.id}_${word.text}', skill: 'word:${word.text}', answer: word.text,
        kind:kind,blank:blank,choices:kind==QuestionKind.fill?fillChoices:choices, word: word, audio: word.audio));
    }
    if (out.isEmpty) out.add(_soundQuestion(sound, '${lesson.id}_fallback'));
    return out;
  }

  Question _soundQuestion(Sound sound, String id) {
    // Distractors must represent different sounds. c/k and other homophones
    // are never presented as competing answers to a sound-only question.
    final others = curriculum.sounds.where((s) => s.ipa != sound.ipa && s.label != sound.label &&
      !s.id.startsWith('mix') && s.id != 'review').toList()..shuffle(Random(id.length));
    final labels = {sound.label}, phonemes = {sound.ipa};
    final choices = <String>[sound.label];
    for (final other in others) {
      if (labels.contains(other.label) || phonemes.contains(other.ipa)) continue;
      labels.add(other.label);
      phonemes.add(other.ipa);
      choices.add(other.label);
      if (choices.length == 3) break;
    }
    choices.shuffle(Random(id.hashCode));
    return Question(id: id, skill: sound.id, answer: sound.label,
      kind: QuestionKind.listen, choices: choices, audio: sound.audio);
  }
}

class Attempt {
  final String skill, question, direction;
  final bool? correct;
  final bool helped;
  final DateTime at;
  const Attempt(this.skill, this.question, this.correct, this.helped, this.at,
    {this.direction = 'soundToText'});
  Map<String, dynamic> toJson() => {'skill': skill, 'question': question,
    'correct': correct, 'helped': helped, 'at': at.toIso8601String(), 'direction': direction};
  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(j['skill'], j['question'],
    j['correct'], j['helped'], DateTime.parse(j['at']), direction: j['direction'] ?? 'soundToText');
}

class LearningState {
  final Set<int> completed;
  final List<Attempt> attempts;
  final Map<String, DateTime> due;
  final Map<String, int> intervals;
  final Set<String> rewards;
  final List<bool> placement;
  final List<Map<String,dynamic>> sessions;
  int startAt, food, companion;
  bool setup, showIpa, microphone;
  double volume;
  LearningState({Set<int>? completed, List<Attempt>? attempts,
    Map<String, DateTime>? due, Map<String, int>? intervals, Set<String>? rewards,
    List<bool>? placement,List<Map<String,dynamic>>? sessions,
    this.startAt = 0, this.food = 0, this.companion = 0, this.setup = false,
    this.showIpa = true, this.microphone = true, this.volume = 0.8})
    : completed = completed ?? {}, attempts = attempts ?? [], due = due ?? {},
      intervals = intervals ?? {}, rewards = rewards ?? {},placement=placement??[],sessions=sessions??[];
  int get nextLesson {
    var i = startAt;
    while (i < 70 && completed.contains(i)) { i++; }
    return min(i, 69);
  }
  int get stars => completed.length;
  int get unlockedAnimals => 1 + List.generate(10, (i) => i)
    .where((i) => completed.contains(i * 7 + 6)).length;
  bool unlocked(int lesson) => lesson <= nextLesson || completed.contains(lesson);
  List<String> reviews(DateTime now, int lesson, Curriculum c) {
    final keys = due.keys.where((s) => !due[s]!.isAfter(now) &&
      (s.startsWith('word:') ? c.words.any((w)=>w.text==s.substring(5)&&c.isDecodable(w,lesson))
        : (c.introduced[s] ?? 999) <= lesson)).toList()
      ..sort((a, b) => due[a]!.compareTo(due[b]!));
    return keys.take(2).toList();
  }
  void record(Attempt attempt) {
    attempts.add(attempt);
    if (attempt.correct == null) return;
    final old = intervals[attempt.skill] ?? 0;
    final days = attempt.correct == true && !attempt.helped ? (old == 0 ? 1 : old == 1 ? 3 : 7) : 0;
    intervals[attempt.skill] = days;
    due[attempt.skill] = attempt.at.add(Duration(days: days));
  }
  bool finish(int index, String sessionId,{int seconds=0}) {
    if (!rewards.add(sessionId)) return false;
    completed.add(index);
    sessions.add({'id':sessionId,'lesson':index,'seconds':seconds,'at':DateTime.now().toIso8601String()});
    food++;
    return true;
  }
  bool feed() { if (food == 0) return false; food--; return true; }
  String mastery(String skill) {
    // An initially wrong answer still counts as wrong after corrective help.
    // Only a correct answer obtained with help is excluded from independent mastery.
    final all = attempts.where((a) => a.skill == skill && a.correct != null &&
      (a.correct != true || !a.helped)).toList();
    if (all.isEmpty) return 'まだ かくにんしていない';
    final recent = all.reversed.take(5).toList();
    final days = recent.map((a) => '${a.at.year}-${a.at.month}-${a.at.day}').toSet();
    final directions = recent.map((a) => a.direction).toSet();
    return recent.length >= 5 && recent.where((a) => a.correct == true).length >= 4 &&
      days.length >= 2 && directions.length >= 2 ? 'みについてきた' : 'れんしゅうちゅう';
  }
  String encode() => jsonEncode({'schema': 1, 'completed': completed.toList(),
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'due': due.map((k, v) => MapEntry(k, v.toIso8601String())), 'intervals': intervals,
    'rewards': rewards.toList(), 'startAt': startAt, 'food': food, 'companion': companion,
    'setup': setup, 'showIpa': showIpa, 'microphone': microphone, 'volume': volume,
    'placement':placement,'sessions':sessions});
  factory LearningState.decode(String? source) {
    if (source == null || source.isEmpty) return LearningState();
    final j = jsonDecode(source) as Map<String, dynamic>;
    if (j['schema'] != 1) throw const FormatException('Unknown learning data version');
    if((j['startAt'] as int)<0||j['startAt']>69||(j['food'] as int)<0||
      (j['companion'] as int)<0||j['companion']>10||
      (j['volume'] as num)<0||j['volume']>1||
      (j['completed'] as List).any((i)=>i is! int||i<0||i>69)){
      throw const FormatException('Invalid learning data');
    }
    return LearningState(completed: Set<int>.from(j['completed']),
      attempts: (j['attempts'] as List).map((a) => Attempt.fromJson(a)).toList(),
      due: (j['due'] as Map<String, dynamic>).map((k, v) => MapEntry(k, DateTime.parse(v))),
      intervals: Map<String, int>.from(j['intervals']), rewards: Set<String>.from(j['rewards']),
      startAt: j['startAt'], food: j['food'], companion: j['companion'], setup: j['setup'],
      showIpa: j['showIpa'], microphone: j['microphone'], volume: (j['volume'] as num).toDouble(),
      placement:List<bool>.from(j['placement']??[]),sessions:(j['sessions'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e)).toList());
  }
}

class Placement {
  // Two independent checks per stage. A single memorized word cannot skip a stage.
  static int recommend(List<bool> answers) {
    var stage = 0;
    for (var i = 0; i + 1 < answers.length && i < 12; i += 2) {
      if (!answers[i] || !answers[i + 1]) break;
      stage++;
    }
    return min(stage, 5) * 7;
  }
}
