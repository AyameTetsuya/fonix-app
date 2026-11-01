package jp.fonix;

import android.Manifest;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.AssetFileDescriptor;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.os.SystemClock;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.FlutterInjector;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private MediaPlayer player;
    private AudioRecord recorder;
    private volatile boolean recording;
    private volatile Exception recordingFailure;
    private Thread recordingThread;
    private ByteArrayOutputStream pcm;
    private File temporary;
    private MethodChannel.Result permissionResult;
    private final ExecutorService secrets = Executors.newSingleThreadExecutor();
    private int pinFailures;
    private long pinLockedUntil;

    private SharedPreferences preferences() { return getSharedPreferences("fonix", MODE_PRIVATE); }
    private File savedDir() {
        File dir = new File(getFilesDir(),"recordings");
        if (!dir.exists() && !dir.mkdirs()) throw new IllegalStateException("Cannot prepare recordings");
        return dir;
    }
    private File checkedRecording(String id) {
        if (id == null || !id.matches("[a-f0-9-]{36}\\.wav")) throw new IllegalArgumentException("Invalid recording ID");
        return new File(savedDir(), id);
    }
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        temporary = new File(getCacheDir(),"fonix_take.wav");
        if (temporary.exists()) temporary.delete();
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(),"jp.fonix/device")
            .setMethodCallHandler(this::call);
    }
    private void call(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "load": result.success(preferences().getString("state",null)); return;
                case "save":
                    if (!preferences().edit().putString("state",call.argument("data")).commit()) throw new IllegalStateException("Save failed");
                    result.success(null); return;
                case "play": {
                    stopPlayer();
                    String asset = call.argument("asset");
                    if (asset == null || !asset.matches("assets/audio/[a-z0-9_]+\\.wav")) throw new IllegalArgumentException("Invalid asset");
                    String key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset);
                    try (AssetFileDescriptor fd=getAssets().openFd(key)) {
                        player = new MediaPlayer();
                        player.setDataSource(fd.getFileDescriptor(),fd.getStartOffset(),fd.getLength());
                        player.prepare();
                        Number volume=call.argument("volume"),speed=call.argument("speed");
                        float v=volume==null?.8f:Math.max(0,Math.min(1,volume.floatValue()));
                        player.setVolume(v,v);
                        player.setPlaybackParams(player.getPlaybackParams().setSpeed(speed==null?1:speed.floatValue()));
                        player.setOnCompletionListener(p -> stopPlayer());
                        player.start();
                    }
                    result.success(null); return;
                }
                case "stop": stopPlayer(); result.success(null); return;
                case "startRecording":
                    if (recording || permissionResult != null) throw new IllegalStateException("Recording is already active");
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) {
                        permissionResult=result;
                        requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},91);
                    } else { startCapture(); result.success(null); }
                    return;
                case "stopRecording": {
                    AudioData data = stopCapture();
                    try(FileOutputStream out=new FileOutputStream(temporary)) { out.write(data.wav()); }
                    Map<String,Object> map=new HashMap<>();
                    map.put("durationMs",data.durationMs);map.put("rms",data.rms);map.put("clipping",data.clipping);
                    result.success(map); return;
                }
                case "playRecording": {
                    stopPlayer();String id=call.argument("id");File file=id==null?temporary:checkedRecording(id);
                    if (!file.isFile()) throw new IllegalStateException("Recording does not exist");
                    player=new MediaPlayer();player.setDataSource(file.getAbsolutePath());player.prepare();
                    player.setOnCompletionListener(p -> stopPlayer());player.start();result.success(null);return;
                }
                case "keepRecording": {
                    File[] files=savedDir().listFiles((dir,name)->name.endsWith(".wav"));
                    if (files==null || files.length>=20 || !temporary.isFile()) throw new IllegalStateException("Recording limit or missing take");
                    String id=UUID.randomUUID()+".wav";
                    Files.copy(temporary.toPath(),checkedRecording(id).toPath());result.success(id);return;
                }
                case "recordings": {
                    String[] files=savedDir().list((dir,name)->name.matches("[a-f0-9-]{36}\\.wav"));
                    if (files==null) throw new IllegalStateException("Cannot list recordings");
                    Arrays.sort(files);result.success(new ArrayList<>(Arrays.asList(files)));return;
                }
                case "deleteRecording": {
                    stopPlayer();File f=checkedRecording(call.argument("id"));
                    if (f.exists()&&!f.delete()) throw new IllegalStateException("Cannot delete recording");
                    result.success(null);return;
                }
                case "discard": discard();result.success(null);return;
                case "hasPin": result.success(preferences().contains("pin"));return;
                case "setPin": {
                    String pin=call.argument("pin");
                    secrets.execute(()->{
                        try {String hash=PinHash.create(pin);
                            if(!preferences().edit().putString("pin",hash).commit())throw new IllegalStateException();
                            runOnUiThread(()->result.success(null));
                        }catch(Exception e){runOnUiThread(()->result.error("PIN","PIN could not be saved",null));}
                    });return;
                }
                case "verifyPin": {
                    if(SystemClock.elapsedRealtime()<pinLockedUntil){result.success(false);return;}
                    String pin=call.argument("pin"),hash=preferences().getString("pin","");
                    secrets.execute(()->{
                        try{boolean valid=PinHash.verify(pin,hash);
                            runOnUiThread(()->{
                                if(valid){pinFailures=0;}else if(++pinFailures>=5){pinLockedUntil=SystemClock.elapsedRealtime()+30000;pinFailures=0;}
                                result.success(valid);
                            });
                        }catch(Exception e){runOnUiThread(()->result.error("PIN","PIN verification unavailable",null));}
                    });return;
                }
                case "resetAll":
                    discard();stopPlayer();
                    File[] all=savedDir().listFiles();
                    if(all==null)throw new IllegalStateException("Cannot list files");
                    for(File f:all)if(!f.delete())throw new IllegalStateException("Cannot delete file");
                    if(!preferences().edit().clear().commit())throw new IllegalStateException("Cannot reset state");
                    result.success(null);return;
                default: result.notImplemented();
            }
        } catch (Exception e) { result.error("DEVICE","Device operation failed",null); }
    }
    private void stopPlayer(){if(player!=null){player.release();player=null;}}
    private void startCapture() throws Exception {
        stopPlayer();discard();
        int min=AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT);
        if(min<=0)throw new IllegalStateException("Unsupported audio format");
        recorder=new AudioRecord(MediaRecorder.AudioSource.MIC,16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,Math.max(min,4096));
        if(recorder.getState()!=AudioRecord.STATE_INITIALIZED){recorder.release();recorder=null;throw new IllegalStateException("Microphone unavailable");}
        pcm=new ByteArrayOutputStream();recordingFailure=null;
        recorder.startRecording();recording=true;
        recordingThread=new Thread(()->{
            byte[] buffer=new byte[2048];
            while(recording && pcm.size()<320000){
                int count=recorder.read(buffer,0,Math.min(buffer.length,320000-pcm.size()));
                if(count<0){recordingFailure=new IllegalStateException("Microphone read failed");break;}
                if(count>0)pcm.write(buffer,0,count);
            }
            recording=false;
        },"fonix-microphone");recordingThread.start();
    }
    private AudioData stopCapture() throws Exception {
        if(recorder==null||pcm==null)throw new IllegalStateException("Not recording");
        recording=false;
        recorder.stop();
        if(recordingThread!=null){recordingThread.join(1500);if(recordingThread.isAlive())throw new IllegalStateException("Microphone did not stop");}
        recorder.release();recorder=null;recordingThread=null;
        if(recordingFailure!=null)throw recordingFailure;
        AudioData data=new AudioData(pcm.toByteArray());pcm=null;return data;
    }
    private void discard() throws Exception {
        if(recorder!=null)stopCapture();
        if(temporary!=null&&temporary.exists()&&!temporary.delete())throw new IllegalStateException("Cannot delete temporary audio");
    }
    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] grants){
        super.onRequestPermissionsResult(code,permissions,grants);
        if(code==91&&permissionResult!=null){
            MethodChannel.Result pending=permissionResult;permissionResult=null;
            try{if(grants.length==0||grants[0]!=PackageManager.PERMISSION_GRANTED)throw new SecurityException();
                startCapture();pending.success(null);
            }catch(Exception e){pending.error("MICROPHONE","Microphone permission unavailable",null);}
        }
    }
    @Override protected void onPause(){
        stopPlayer();try{discard();}catch(Exception ignored){}
        super.onPause();
    }
    @Override protected void onDestroy(){
        if(permissionResult!=null){permissionResult.error("CANCELLED","Activity closed",null);permissionResult=null;}
        stopPlayer();try{discard();}catch(Exception ignored){}
        secrets.shutdown();super.onDestroy();
    }
}
