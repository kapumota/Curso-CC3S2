import json
import pytest
from datetime import datetime  # si luego quieres validar timestamps

STATE_FILE = 'network_state.json'

@pytest.fixture(scope="module")
def st(tmp_path_factory):
    """
    Genera un network_state.json en un directorio temporal
    y devuelve el JSON cargado.
    """
    d = tmp_path_factory.mktemp('data2')
    from pruebas_unitarias.main import NetworkFactoryLocal

    NetworkFactoryLocal('tsnet', '10.1.0.0/16', 1).write_files(str(d))
    path = d / 'network_state.json'
    return json.loads(path.read_text())


def test_state_contains_planned(st):
    assert 'planned_values' in st


def test_planned_matches_config(st):
    cfg = st['planned_values']
    assert 'resources' in cfg
    assert isinstance(cfg['resources'], list)
    assert len(cfg['resources']) >= 1
