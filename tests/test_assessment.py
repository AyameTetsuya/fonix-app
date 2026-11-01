import concurrent.futures
from datetime import datetime,timezone
import io
import math
from pathlib import Path
import struct
import tempfile
import unittest
import uuid
import wave
from server.assessment import AssessmentService,Quota,Rejected,ReviewedTarget,validate_wav

TOKEN='test-only-device-token-not-a-credential'

def wav_data(*,silence=False):
    buf=io.BytesIO()
    with wave.open(buf,'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(16000)
        w.writeframes(b''.join(struct.pack('<h',0 if silence else int(6000*math.sin(i*.1))) for i in range(8000)))
    return buf.getvalue()

class Provider:
    def __init__(self):self.calls=0;self.fail=False
    def evaluate(self,body,target):
        self.calls+=1
        if self.fail:raise RuntimeError('sensitive provider detail')
        return {'state':'improvement_candidate','adviceId':'test-advice','raw':'MUST NOT LEAK'}

class AssessmentTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.quota=Quota(str(Path(self.tmp.name)/'usage.db'))
        self.provider=Provider()
        # Synthetic policy/fixtures test transport and privacy; no pronunciation validity is claimed.
        self.target=ReviewedTarget('ship','test-fixture-only',{'ʃ':{'below':60,'adviceId':'test-advice'}})
        self.service=AssessmentService({'tablet':TOKEN},{'word_ship':self.target},self.quota,self.provider)
    def assess(self,**changes):
        values=dict(token=TOKEN,target_id='word_ship',request_id=str(uuid.uuid4()),body=wav_data(),consent=True)
        values.update(changes);return self.service.assess(**values)
    def rejected(self,code,**changes):
        with self.assertRaises(Rejected) as e:self.assess(**changes)
        self.assertEqual(e.exception.code,code)
    def test_no_consent_no_provider_call(self):
        self.rejected('consent_required',consent=False);self.assertEqual(self.provider.calls,0)
    def test_unknown_token_no_provider_call(self):
        self.rejected('unauthorized',token='wrong');self.assertEqual(self.provider.calls,0)
    def test_unreviewed_targets_fail_closed(self):
        self.rejected('target_not_validated',target_id='sound_s');self.assertEqual(self.provider.calls,0)
    def test_duplicate_does_not_bill_twice(self):
        request=str(uuid.uuid4());self.assess(request_id=request)
        self.rejected('duplicate_request',request_id=request);self.assertEqual(self.provider.calls,1)
    def test_silence_is_not_a_pronunciation_success(self):
        self.rejected('recording_quality',body=wav_data(silence=True));self.assertEqual(self.provider.calls,0)
    def test_truncated_audio_is_rejected_before_billing(self):
        self.rejected('truncated_audio',body=wav_data()[:-100]);self.assertEqual(self.provider.calls,0)
    def test_oversized_body_rejected(self):
        with self.assertRaises(Rejected):validate_wav(b'x'*320045)
    def test_provider_detail_is_not_exposed(self):
        result=self.assess();self.assertEqual(result,{'state':'improvement_candidate','adviceId':'test-advice'})
    def test_failures_remain_reserved(self):
        self.provider.fail=True
        self.rejected('evaluation_unavailable')
        with self.quota.connect() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM requests').fetchone()[0],1)
    def test_monthly_budget_is_shared_across_devices(self):
        quota=Quota(str(Path(self.tmp.name)/'shared.db'),monthly_yen=15,reservation_yen=10)
        quota.reserve('one',str(uuid.uuid4()))
        with self.assertRaises(Rejected) as e:quota.reserve('two',str(uuid.uuid4()))
        self.assertEqual(e.exception.code,'usage_limit')
    def test_concurrent_daily_limit_is_atomic(self):
        quota=Quota(str(Path(self.tmp.name)/'parallel.db'),daily=3)
        def reserve(_):
            try:quota.reserve('tablet',str(uuid.uuid4()));return True
            except Rejected:return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            self.assertEqual(sum(pool.map(reserve,range(12))),3)
    def test_day_boundary_uses_japan_time(self):
        self.quota.reserve('tablet',str(uuid.uuid4()),datetime(2026,11,1,15,0,tzinfo=timezone.utc))
        with self.quota.connect() as db:self.assertEqual(db.execute('SELECT day FROM requests').fetchone()[0],'2026-11-02')
    def test_repository_policy_has_no_fake_reviewed_targets(self):
        self.assertEqual(Path('server/reviewed_targets.json').read_text().strip(),'{}')

if __name__=='__main__':unittest.main()
