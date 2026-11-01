import 'package:fonix_app/platform/device.dart';

class FakeDevice implements Device {
  String? data,pin;
  bool failSave=false;
  final List<String> played=[];
  final List<String> kept=[];
  @override Future<String?> load()async=>data;
  @override Future<void> save(String value)async{if(failSave)throw StateError('disk full');data=value;}
  @override Future<void> play(String asset,{double speed=1,double volume=.8})async{played.add(asset);}
  @override Future<void> stop()async{}
  @override Future<void> startRecording()async{}
  @override Future<RecordingResult> stopRecording()async=>const RecordingResult(600,.1,0);
  @override Future<void> playRecording([String? id])async{}
  @override Future<String> keepRecording()async{kept.add('recording-${kept.length}');return kept.last;}
  @override Future<List<String>> recordings()async=>kept.toList();
  @override Future<void> deleteRecording(String id)async{kept.remove(id);}
  @override Future<void> discard()async{}
  @override Future<bool> hasPin()async=>pin!=null;
  @override Future<void> setPin(String value)async{pin=value;}
  @override Future<bool> verifyPin(String value)async=>pin==value;
  @override Future<void> resetAll()async{data=null;pin=null;kept.clear();}
}
