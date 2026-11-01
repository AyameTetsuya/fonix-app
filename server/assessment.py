"""Assessment boundary, conservative quota reservations, no stored audio.

The application does not connect to this service yet. An empty reviewed-target
policy intentionally prevents all external evaluation until child-speech testing.
"""
from __future__ import annotations
import base64
import array
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import urllib.request
import uuid
import wave

JST=timezone(timedelta(hours=9))

class Rejected(Exception):
    def __init__(self,status:int,code:str):
        self.status=status;self.code=code
        super().__init__(code)

@dataclass(frozen=True)
class ReviewedTarget:
    text:str
    evidence:str
    # Thresholds and advice must be reviewed per sound, not copied as universal rules.
    corrections:dict[str,dict]

class Quota:
    def __init__(self,path:str,*,daily=10,monthly_yen=1000,reservation_yen=10):
        if daily<1 or monthly_yen<1 or reservation_yen<1:
            raise ValueError('Quota amounts must be positive')
        self.path=path;self.daily=daily;self.monthly=monthly_yen;self.cost=reservation_yen
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS requests(device TEXT,request_id TEXT,day TEXT,month TEXT,cost INTEGER,PRIMARY KEY(device,request_id))')
    def connect(self):
        return sqlite3.connect(self.path,timeout=10,isolation_level=None)
    def reserve(self,device,request_id,now=None):
        try: uuid.UUID(request_id)
        except (ValueError,TypeError,AttributeError):raise Rejected(400,'invalid_request_id')
        now=(now or datetime.now(timezone.utc)).astimezone(JST)
        day=now.strftime('%Y-%m-%d');month=now.strftime('%Y-%m')
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT 1 FROM requests WHERE device=? AND request_id=?',(device,request_id)).fetchone():
                raise Rejected(409,'duplicate_request')
            count=db.execute('SELECT COUNT(*) FROM requests WHERE device=? AND day=?',(device,day)).fetchone()[0]
            cost=db.execute('SELECT COALESCE(SUM(cost),0) FROM requests WHERE month=?',(month,)).fetchone()[0]
            if count>=self.daily or cost+self.cost>self.monthly:raise Rejected(429,'usage_limit')
            db.execute('INSERT INTO requests VALUES(?,?,?,?,?)',(device,request_id,day,month,self.cost))
            db.commit()

def validate_wav(body:bytes):
    if len(body)>320044:raise Rejected(413,'audio_too_large')
    try:
        with wave.open(io.BytesIO(body)) as wav:
            if (wav.getnchannels(),wav.getsampwidth(),wav.getframerate(),wav.getcomptype())!=(1,2,16000,'NONE'):
                raise Rejected(422,'unsupported_audio_format')
            if not 4000<=wav.getnframes()<=160000:raise Rejected(422,'audio_duration')
            pcm=wav.readframes(wav.getnframes())
            if len(pcm)!=wav.getnframes()*2:raise Rejected(422,'truncated_audio')
            samples=array.array('h',pcm)
            import sys
            if sys.byteorder!='little':samples.byteswap()
            rms=(sum((v/32768)**2 for v in samples)/len(samples))**0.5
            if rms<=0.008 or sum(abs(v)>32112 for v in samples)/len(samples)>=0.1:
                raise Rejected(422,'recording_quality')
    except (wave.Error,EOFError):raise Rejected(422,'invalid_wav')

class AzureWordProvider:
    """Word-only adapter. A single letter is NEVER used to emulate an isolated phoneme."""
    def __init__(self,region,key):
        if not re.fullmatch('[a-z0-9-]+',region):raise ValueError('Invalid region')
        self.region=region;self.key=key
    def evaluate(self,audio:bytes,target:ReviewedTarget):
        params={'ReferenceText':target.text,'GradingSystem':'HundredMark',
                'Granularity':'Phoneme','Dimension':'Comprehensive',
                'EnableMiscue':True,'PhonemeAlphabet':'IPA'}
        header=base64.b64encode(json.dumps(params).encode()).decode()
        req=urllib.request.Request(
            f'https://{self.region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US&format=detailed',
            data=audio,headers={'Ocp-Apim-Subscription-Key':self.key,
              'Pronunciation-Assessment':header,'Content-Type':'audio/wav; codecs=audio/pcm; samplerate=16000'})
        with urllib.request.urlopen(req,timeout=6) as response:
            raw=json.loads(response.read(512000))
        if raw.get('RecognitionStatus')!='Success':return {'state':'indeterminate'}
        words=(raw.get('NBest') or [{}])[0].get('Words') or []
        if len(words)!=1 or words[0].get('Word','').lower()!=target.text.lower():
            return {'state':'indeterminate'}
        for phoneme in words[0].get('Phonemes',[]):
            policy=target.corrections.get(phoneme.get('Phoneme'))
            score=phoneme.get('PronunciationAssessment',{}).get('AccuracyScore')
            if policy and isinstance(score,(int,float)) and score<policy['below']:
                return {'state':'improvement_candidate','adviceId':policy['adviceId']}
        # No independently validated success threshold: do not invent a success grade.
        return {'state':'indeterminate'}

class AssessmentService:
    def __init__(self,tokens:dict[str,str],targets:dict[str,ReviewedTarget],quota:Quota,provider):
        if not tokens or any(len(t)<24 for t in tokens.values()):raise ValueError('Strong device tokens required')
        self.tokens=tokens;self.targets=targets;self.quota=quota;self.provider=provider
    def assess(self,token,target_id,request_id,body,*,consent=False):
        device=None
        for alias,secret in self.tokens.items():
            if hmac.compare_digest(hashlib.sha256(str(token).encode()).digest(),hashlib.sha256(secret.encode()).digest()):device=alias
        if device is None:raise Rejected(401,'unauthorized')
        if not consent:raise Rejected(403,'consent_required')
        target=self.targets.get(target_id)
        if target is None or not target.evidence:raise Rejected(422,'target_not_validated')
        if self.provider is None:raise Rejected(503,'provider_unconfigured')
        validate_wav(body)
        self.quota.reserve(device,request_id)
        try:
            result=self.provider.evaluate(body,target)
            allowed={p['adviceId'] for p in target.corrections.values()}
            if result.get('state')=='improvement_candidate' and result.get('adviceId') in allowed:
                return {'state':'improvement_candidate','adviceId':result['adviceId']}
            return {'state':'indeterminate'}
        except Exception:
            # Keep the reservation: the remote service may still have charged us.
            raise Rejected(503,'evaluation_unavailable') from None

def configured_service():
    tokens=json.loads(os.environ.get('FONIX_DEVICE_TOKENS','{}'))
    policy=json.loads(Path(os.environ.get('FONIX_REVIEWED_TARGETS','server/reviewed_targets.json')).read_text())
    targets={key:ReviewedTarget(v['text'],v['evidence'],v['corrections']) for key,v in policy.items()}
    provider=None
    region=os.environ.get('FONIX_SPEECH_REGION');key=os.environ.get('FONIX_SPEECH_KEY')
    if region and key:provider=AzureWordProvider(region,key)
    quota=Quota(os.environ.get('FONIX_QUOTA_DB','quota.sqlite3'),
        monthly_yen=int(os.environ.get('FONIX_MONTHLY_YEN','1000')),
        reservation_yen=int(os.environ.get('FONIX_RESERVATION_YEN','10')))
    return AssessmentService(tokens,targets,quota,provider)
