#test_service_and_dip.py
from app.adapters import FakeHttpClient, SecureRequestsClient
from app.service import MovieService
import pytest

def test_service_usa_fake_con_fixtures():
    fixtures = {"https://api.ejemplo.com/status": {"ok": True}}
    http = FakeHttpClient(fixtures)
    svc = MovieService(http)
    assert svc.status() == {"ok": True}

def test_secure_requests_client_allowlist():
    client = SecureRequestsClient()
    with pytest.raises(ValueError):
        client.get_json("https://evil.example/")
