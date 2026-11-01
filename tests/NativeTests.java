import jp.fonix.AudioData;
import jp.fonix.PinHash;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public class NativeTests {
    private static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    public static void main(String[] args)throws Exception{
        AudioData silence=new AudioData(new byte[32000]);
        check(silence.durationMs==1000,"duration");check(silence.rms==0,"silence rms");
        byte[] wave=silence.wav();check(wave.length==32044,"wav length");
        ByteBuffer b=ByteBuffer.wrap(wave).order(ByteOrder.LITTLE_ENDIAN);
        check(b.getInt(24)==16000,"sample rate");check(b.getInt(40)==32000,"data length");
        byte[] pcm=new byte[32000];for(int i=0;i<16000;i++){pcm[i*2]=(byte)0xff;pcm[i*2+1]=0x7f;}
        AudioData clipped=new AudioData(pcm);check(clipped.clipping==1,"clipped samples");
        check(clipped.rms>.99,"rms scale");
        String one=PinHash.create("1234"),two=PinHash.create("1234");
        check(!one.equals(two),"fresh salts");check(PinHash.verify("1234",one),"correct pin");
        check(!PinHash.verify("9999",one),"wrong pin");check(!PinHash.verify("x",one),"invalid pin");
        check(!one.contains("1234"),"no plaintext");
        System.out.println("NativeTests: 12 assertions passed (PCM/WAV and PIN; Android hardware not exercised)");
    }
}
