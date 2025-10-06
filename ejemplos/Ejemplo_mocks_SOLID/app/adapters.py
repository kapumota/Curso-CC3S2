import os
import urllib.parse
import requests
from .ports import HttpPort

ALLOWED_HOSTS = {"api.ejemplo.com"}
TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "2.0"))

class SecureRequestsClient(HttpPort):
    def get_json(self, url: str):
        host = urllib.parse.urlparse(url).hostname
        if host not in ALLOWED_HOSTS:
            raise ValueError(f"Host no permitido: {host}")
        r = requests.get(url, timeout=TIMEOUT)
        r.raise_for_status()
        return r.json()

class FakeHttpClient(HttpPort):
    def __init__(self, fixtures):
        self.fixtures = fixtures
    def get_json(self, url: str):
        return self.fixtures[url]
