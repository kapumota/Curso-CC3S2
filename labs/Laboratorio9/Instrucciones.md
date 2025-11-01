### Laboratorio:DevSecOps con Docker, Compose y Airflow

Este proyecto es una maqueta práctica para enseñar **DevSecOps con contenedores**. 
Veremos cómo una aplicación ETL corre dentro de Docker, orquestada con Compose, con **configuración por entorno**, **healthchecks**, **límites de recursos**, pruebas en contenedor y "gates" de **supply chain** (SBOM + escaneo).

#### Antes de empezar

Necesitas **Docker** (Desktop/Engine con Compose), **GNU Make** y un archivo de entorno. Duplica el ejemplo:

```bash
cp .env.example .env
```

####  Arranque en 3 pasos

Primero construimos, luego inicializamos la base de Airflow y, por último, levantamos todo:

```bash
make build
make reset-init
make up
```

La **UI de Airflow** queda en `http://localhost:8080` (usuario `admin`, clave `admin`).
Para seguir los logs del webserver:

```bash
make logs
```

> Si la UI insiste en "You need to initialize the database", usa `make reset-init` y vuelve a `make up`.

#### ¿Qué hace el ETL?

El servicio `etl-app` ejecuta `pipeline.py`: lee `app/data/input.csv`, calcula una columna `value_squared` e inserta el resultado en Postgres (`processed_data`). Puedes relanzar el ETL manualmente sin tocar el resto:

```bash
docker compose run --rm etl-app python pipeline.py
```

Y si quieres comprobar los datos:

```bash
docker compose exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM processed_data LIMIT 5;"
```

#### Pruebas como en CI

Las pruebas se ejecutan **dentro de contenedores** con una base efímera, para que tu máquina no contamine resultados:

```bash
make test
```

#### Gates de supply chain

Genera la **SBOM** y lanza un escaneo de vulnerabilidades. Son pasos pensados como "gates" de cumplimiento:

```bash
make sbom
make scan
```

Los archivos SBOM quedan en `./dist/`.

#### Operación diaria

Cuando quieras trabajar: `make up`.
Para parar: `make down`.
Para empezar desde cero (desechable): `docker compose down -v` y luego `make reset-init && make up`.

#### Si algo falla

* Puerto 8080 ocupado -> cambia a `8090:8080` en `airflow-webserver`.
* Aviso de **FERNET** en Airflow -> genera una clave y colócala como `FERNET_KEY` en `.env`; expórtala con `AIRFLOW__CORE__FERNET_KEY`.
* Docker/WSL raro (Windows) -> `wsl --shutdown`, reinicia Docker Desktop y repite `make build && make init && make up`.

## Buenas prácticas que estás aplicando

* Contenedores **sin root** en runtime (menor superficie de ataque).
* **Nada** de puertos de base de datos expuestos al host.
* **Configuración en `.env`** (12-Factor), no en código ni en Dockerfiles.
* **Healthchecks** reales y **límites** de CPU/mem para evitar "DoS interno".
* Imágenes con **tags fijos** (evita `:latest`) para trazabilidad.


> El flujo es simple, **construir -> inicializar -> levantar**, probar el ETL, pasar tests y registrar evidencia de SBOM/escaneo.
