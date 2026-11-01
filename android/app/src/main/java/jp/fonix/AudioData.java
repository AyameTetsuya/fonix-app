package jp.fonix;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/** PCM container and signal quality only. This class does NOT grade pronunciation. */
public final class AudioData {
    public final byte[] pcm;
    public final double rms;
    public final double clipping;
    public final int durationMs;
    public AudioData(byte[] pcm) {
        this.pcm = pcm.clone();
        int n = pcm.length / 2, clipped = 0;
        double sum = 0;
        for (int i = 0; i < n; i++) {
            short value = (short) ((pcm[i*2] & 255) | (pcm[i*2+1] << 8));
            double f = value / 32768.0;
            sum += f*f;
            if (Math.abs(f) > .98) clipped++;
        }
        rms = n == 0 ? 0 : Math.sqrt(sum/n);
        clipping = n == 0 ? 0 : clipped/(double)n;
        durationMs = n * 1000 / 16000;
    }
    public byte[] wav() {
        ByteBuffer out = ByteBuffer.allocate(pcm.length + 44).order(ByteOrder.LITTLE_ENDIAN);
        out.put(new byte[]{'R','I','F','F'}).putInt(pcm.length+36);
        out.put(new byte[]{'W','A','V','E','f','m','t',' '}).putInt(16);
        out.putShort((short)1).putShort((short)1).putInt(16000).putInt(32000);
        out.putShort((short)2).putShort((short)16);
        out.put(new byte[]{'d','a','t','a'}).putInt(pcm.length).put(pcm);
        return out.array();
    }
}
