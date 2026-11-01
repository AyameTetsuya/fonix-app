import 'package:flutter/services.dart';

class RecordingResult {
  final int durationMs;
  final double rms, clipping;
  const RecordingResult(this.durationMs, this.rms, this.clipping);
  bool get usable => durationMs >= 250 && rms > 0.008 && clipping < 0.1;
  String get feedback => durationMs < 250 || rms <= 0.008
    ? 'こえが よく きこえなかったよ。お手本を きいてみよう。'
    : clipping >= 0.1 ? 'すこし はなれて おはなししてみよう。'
    : 'ろくおんできたよ！ お手本と ききくらべてみよう。';
}

abstract class Device {
  Future<String?> load();
  Future<void> save(String data);
  Future<void> play(String asset, {double speed = 1, double volume = 0.8});
  Future<void> stop();
  Future<void> startRecording();
  Future<RecordingResult> stopRecording();
  Future<void> playRecording([String? id]);
  Future<String> keepRecording();
  Future<List<String>> recordings();
  Future<void> deleteRecording(String id);
  Future<void> discard();
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> resetAll();
}

class AndroidDevice implements Device {
  static const _channel = MethodChannel('jp.fonix/device');
  @override Future<String?> load() => _channel.invokeMethod<String>('load');
  @override Future<void> save(String data) => _channel.invokeMethod('save', {'data': data});
  @override Future<void> play(String asset, {double speed = 1, double volume = 0.8}) =>
    _channel.invokeMethod('play', {'asset': asset, 'speed': speed, 'volume': volume});
  @override Future<void> stop() => _channel.invokeMethod('stop');
  @override Future<void> startRecording() => _channel.invokeMethod('startRecording');
  @override Future<RecordingResult> stopRecording() async {
    final j = await _channel.invokeMapMethod<String, dynamic>('stopRecording');
    return RecordingResult(j!['durationMs'], (j['rms'] as num).toDouble(), (j['clipping'] as num).toDouble());
  }
  @override Future<void> playRecording([String? id]) => _channel.invokeMethod('playRecording', {'id': id});
  @override Future<String> keepRecording() async => (await _channel.invokeMethod<String>('keepRecording'))!;
  @override Future<List<String>> recordings() async => (await _channel.invokeListMethod<String>('recordings'))!.cast<String>();
  @override Future<void> deleteRecording(String id) => _channel.invokeMethod('deleteRecording', {'id': id});
  @override Future<void> discard() => _channel.invokeMethod('discard');
  @override Future<bool> hasPin() async => await _channel.invokeMethod<bool>('hasPin') ?? false;
  @override Future<void> setPin(String pin) => _channel.invokeMethod('setPin', {'pin': pin});
  @override Future<bool> verifyPin(String pin) async => await _channel.invokeMethod<bool>('verifyPin', {'pin': pin}) ?? false;
  @override Future<void> resetAll() => _channel.invokeMethod('resetAll');
}
