#test_clients.py
from unittest.mock import Mock
import pytest
from app.clients import get_json

def test_stub_respuesta_fija():
    http = Mock()
    http.get.return_value.status_code = 200
    http.get.return_value.json.return_value = {"ok": True}
    data = get_json("https://api.ejemplo.com/status", http=http)
    assert data == {"ok": True}

def test_mock_verifica_interaccion():
    http = Mock()
    http.get.return_value.status_code = 200
    http.get.return_value.json.return_value = {"ok": True}
    get_json("https://api.ejemplo.com/status", http=http)
    http.get.assert_called_once_with("https://api.ejemplo.com/status", timeout=2.0)

def test_allowlist_bloquea_dominios_no_permitidos():
    http = Mock()
    with pytest.raises(ValueError):
        get_json("https://malicioso.evil/steal", http=http)
