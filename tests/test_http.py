import threading
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import unittest
import urllib.error
import urllib.request
import uuid
from server.assessment import AssessmentService,Quota,ReviewedTarget
from server.main import Handler
from test_assessment import TOKEN,Provider,wav_data

class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        service=AssessmentService({'tablet':TOKEN},{'word_ship':ReviewedTarget('ship','test-only',{'ʃ':{'below':60,'adviceId':'test-advice'}})},
            Quota(str(Path(self.tmp.name)/'quota.db')),Provider())
        self.server=ThreadingHTTPServer(('127.0.0.1',0),Handler);self.server.service=service
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.addCleanup(self.close)
        self.url=f'http://127.0.0.1:{self.server.server_port}'
    def close(self):
        self.server.shutdown();self.server.server_close();self.thread.join()
    def test_real_health_and_assessment_round_trip(self):
        with urllib.request.urlopen(self.url+'/health') as r:self.assertEqual(json.load(r),{'status':'ok'})
        req=urllib.request.Request(self.url+'/v1/assess',data=wav_data(),headers={
            'Authorization':'Bearer '+TOKEN,'Content-Type':'audio/wav','X-Fonix-Target':'word_ship',
            'X-Request-ID':str(uuid.uuid4()),'X-Fonix-Consent':'1'})
        with urllib.request.urlopen(req) as r:
            self.assertEqual(r.headers['Cache-Control'],'no-store')
            self.assertEqual(json.load(r),{'state':'improvement_candidate','adviceId':'test-advice'})
    def test_missing_authorization_rejected(self):
        req=urllib.request.Request(self.url+'/v1/assess',data=wav_data(),headers={'Content-Type':'audio/wav'})
        with self.assertRaises(urllib.error.HTTPError) as e:urllib.request.urlopen(req)
        self.assertEqual(e.exception.code,401)
