### DevSecOps Mocks/Stubs + DI/DIP + SOLID (IaC local) - versión lint-clean

Este proyecto integra dobles de prueba, DI/DIP, SOLID y gates DevSecOps con política como código.
Esta versión ya corrige los hallazgos de `ruff` reportados y usa un Makefile para un entorno **ya activado** (`bdd`).

## Uso (modo bdd)
```bash
# activa tu venv existente (bdd)
source bdd/bin/activate

make env-check
make gates
make test
make run
make pack
```
