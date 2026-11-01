import 'package:flutter/foundation.dart';
import 'domain/curriculum.dart';
import 'domain/learning.dart';
import 'platform/device.dart';

class AppController extends ChangeNotifier {
  final Curriculum curriculum;
  final Device device;
  LearningState state;
  Future<void> _pending = Future<void>.value();
  AppController(this.curriculum, this.device, this.state);

  Future<void> change(void Function(LearningState) update) {
    final task = _pending.then((_) async {
      final candidate = LearningState.decode(state.encode());
      update(candidate);
      await device.save(candidate.encode());
      state = candidate;
      notifyListeners();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> play(String asset, {double speed = 1}) =>
    device.play(asset, speed: speed, volume: state.volume);

  Future<void> reset() {
    final task = _pending.then((_) async {
      await device.resetAll();
      state = LearningState();
      notifyListeners();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }
}
