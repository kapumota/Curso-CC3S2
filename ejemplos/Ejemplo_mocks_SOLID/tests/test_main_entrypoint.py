#test_main_entrypoint.py
from app.main import main

def test_main_prints_status(capsys):
    main()
    out = capsys.readouterr().out.strip()
    # Debe imprimir un dict con ok True y service up
    assert "ok" in out and "service" in out and "up" in out
