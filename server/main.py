"""Local assessment service. Deploy only behind an authenticated TLS boundary."""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
from .assessment import Rejected,configured_service

class Handler(BaseHTTPRequestHandler):
    server_version='Fonix'
    def setup(self):
        super().setup();self.connection.settimeout(8)
    def log_message(self,*_):pass  # Never log paths, tokens, bodies or provider responses.
    def respond(self,status,value):
        body=json.dumps(value).encode()
        self.send_response(status);self.send_header('Content-Type','application/json')
        self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
        self.send_header('Connection','close');self.end_headers();self.wfile.write(body)
    def do_GET(self):
        self.respond(200,{'status':'ok'}) if self.path=='/health' else self.respond(404,{'error':'not_found'})
    def do_POST(self):
        if self.path!='/v1/assess':self.respond(404,{'error':'not_found'});return
        try:
            size=int(self.headers.get('Content-Length','0'))
            if size<1 or size>320044 or self.headers.get('Transfer-Encoding'):
                raise Rejected(413,'invalid_body_size')
            if self.headers.get('Content-Type')!='audio/wav':raise Rejected(415,'audio_wav_required')
            auth=self.headers.get('Authorization','')
            if not auth.startswith('Bearer '):raise Rejected(401,'unauthorized')
            body=self.rfile.read(size)
            if len(body)!=size:raise Rejected(400,'truncated_body')
            result=self.server.service.assess(auth[7:],self.headers.get('X-Fonix-Target'),
                self.headers.get('X-Request-ID'),body,consent=self.headers.get('X-Fonix-Consent')=='1')
            self.respond(200,result)
        except Rejected as e:self.respond(e.status,{'error':e.code})
        except (ValueError,TimeoutError):self.respond(400,{'error':'invalid_request'})
        except Exception:self.respond(503,{'error':'unavailable'})

if __name__=='__main__':
    service=configured_service()
    server=ThreadingHTTPServer(('127.0.0.1',8787),Handler)
    server.service=service
    server.serve_forever()
