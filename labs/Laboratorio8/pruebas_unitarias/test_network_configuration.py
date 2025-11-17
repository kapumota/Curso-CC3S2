import json
import pytest
from pruebas_unitarias.main import NetworkFactoryLocal


@pytest.fixture(scope="module")
def conf(tmp_path_factory):
    """
    Genera un network_config.json temporal y devuelve el JSON cargado.
    """
    d = tmp_path_factory.mktemp('data3')
    NetworkFactoryLocal('confnet', '10.2.0.0/16', 2).write_files(str(d))
    path = d / 'network_config.json'
    return json.loads(path.read_text())


def test_schema_keys(conf):
    assert isinstance(conf, dict)
    assert 'resources' in conf
    for res in conf['resources']:
        assert 'type' in res
        assert 'name' in res
