#clients.py
import os
import requests
import urllib.parse

ALLOWED_HOSTS = {"api.ejemplo.com"}
TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "2.0"))

def _check_allowlist(url: str):
    host = urllib.parse.urlparse(url).hostname
    if host not in ALLOWED_HOSTS:
        raise ValueError(f"Host no permitido: {host}")

def get_json(url: str, http=requests):
    _check_allowlist(url)
    r = http.get(url, timeout=TIMEOUT)
    r.raise_for_status()
    return r.json()
