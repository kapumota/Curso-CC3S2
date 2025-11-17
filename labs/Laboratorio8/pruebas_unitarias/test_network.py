import pytest
import json
from pathlib import Path

from netaddr import IPNetwork
from pruebas_unitarias.main import NetworkFactoryLocal


@pytest.fixture(scope="module")
def factory(tmp_path_factory):
    # Directorio temporal para los archivos generados
    d = tmp_path_factory.mktemp('data')
    # Prueba con parámetros personalizados
    f = NetworkFactoryLocal('testnet', '192.168.0.0/24', 2)
    f.write_files(str(d))
    return d


@pytest.fixture(scope="module")
def config(factory):
    path = factory / 'network_config.json'
    return json.loads(path.read_text())


def test_valid_prefixlen(config):
    """
    Validar que las entradas con 'cidr' tengan un prefijo válido.
    """
    resources = config['resources']
    for r in resources:
        if 'cidr' in r:
            net = IPNetwork(r['cidr'])
            # Prefijo entre 1 y 32 (IPv4)
            assert 0 < net.prefixlen <= 32


def test_subnet_count(config):
    subs = [r for r in config['resources'] if r['type'] == 'local_subnet']
    assert len(subs) == 2


def test_names_unique(config):
    names = [r['name'] for r in config['resources']]
    assert len(names) == len(set(names))


def test_invalid_cidr_exit(monkeypatch, tmp_path):
    """
    CIDR inválido debe terminar el programa con SystemExit.
    """
    # Simular sys.exit lanzando SystemExit
    monkeypatch.setattr(
        'pruebas_unitarias.main.sys.exit',
        lambda code: (_ for _ in ()).throw(SystemExit(code))
    )

    from pruebas_unitarias.main import NetworkFactoryLocal

    with pytest.raises(SystemExit):
        NetworkFactoryLocal('bad', '10.0.0.0/99', 1)
