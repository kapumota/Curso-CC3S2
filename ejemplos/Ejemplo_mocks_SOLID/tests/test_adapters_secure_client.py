#test_adapters_secure_client.py
import requests
from app.adapters import SecureRequestsClient

class DummyResp:
    def __init__(self, status_code=200, data=None):
        self.status_code = status_code
        self._data = data or {}
    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"status: {self.status_code}")
    def json(self):
        return self._data

def test_secure_requests_client_happy_path(monkeypatch):
    def fake_get(url, timeout):
        assert url == "https://api.ejemplo.com/status"
        assert timeout == 2.0
        return DummyResp(200, {"ok": True, "from": "secure-client"})
    monkeypatch.setattr(requests, "get", fake_get)
    client = SecureRequestsClient()
    data = client.get_json("https://api.ejemplo.com/status")
    assert data["ok"] is True
    assert data["from"] == "secure-client"
