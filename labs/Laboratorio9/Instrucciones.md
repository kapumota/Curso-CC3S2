### Laboratorio: DevSecOps con Docker, Compose y Airflow

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

#### Buenas prácticas que estás aplicando

* Contenedores **sin root** en runtime (menor superficie de ataque).
* **Nada** de puertos de base de datos expuestos al host.
* **Configuración en `.env`** (12-Factor), no en código ni en Dockerfiles.
* **Healthchecks** reales y **límites** de CPU/mem para evitar "DoS interno".
* Imágenes con **tags fijos** (evita `:latest`) para trazabilidad.


> El flujo es simple, **construir -> inicializar -> levantar**, probar el ETL, pasar tests y registrar evidencia de SBOM/escaneo.


### Seguridad


#### Alcance y objetivos

* **Alcance:** servicios definidos en `docker-compose.yml`: `airflow-webserver`, `airflow-scheduler`, `etl-app`, `postgres`.
* **Objetivo:** garantizar un **entorno local seguro por defecto**, con superficie de ataque mínima y buenas prácticas básicas replicables.

####  Postura de seguridad (baseline)

* **Usuarios no-root:** las imágenes de Airflow se ejecutan como usuario **no root** en runtime.
* **Privilegios:** no se usan `--privileged`, `cap-add`, `SYS_ADMIN` ni bind mounts sensibles del host.
* **Redes:** comunicación **interna** por red de Compose; **no** se expone Postgres al host.
* **Puertos:** solo se publica **`8080:8080`** para acceder a la UI de Airflow en local.
* **Etiquetado de imágenes:** se usan **tags fijos** (por ejemplo, `1.0.0`, `13`) y **no** se usa `:latest`.

#### Gestión de secretos y configuración

* **`.env.example` obligatorio:** contiene variables de entorno de referencia y **no incluye secretos reales**.
* **Uso de `.env` en este laboratorio:** por ser un entorno **didáctico/local**, **se permite** que exista `./.env` en el repositorio **si y solo si**:

  * contiene **credenciales falsas / de laboratorio**,
  * no se reutilizan en otros entornos,
  * y se entiende que su objetivo es **facilitar la reproducción** del ejercicio.
* **Regla para entornos reales:** en pre-producción/producción, **`.env no se versiona`**; solo `.env.example`. Los secretos deben gestionarse con gestores dedicados (ASM/Secrets Manager/KMS/Vault) o variables de entorno inyectadas por el orquestador/CI.

#### Exposición de servicios

* **UI Airflow:** accesible en `http://localhost:8080`.
* **Base de datos:** **no** se publica `5432`; acceso únicamente desde los servicios de la red interna de Compose.
* **Criterio:** cualquier publicación adicional de puertos debe ser **justificada** y documentada con propósito y alcance.

#### Dependencias e imágenes

* **Tags fijos (MUST):** todas las imágenes deben usar **tags explícitos** (sin `latest`).
* **Digest (SHOULD para producción):** en laboratorios locales, el uso de `@sha256` es **opcional**. En pre-producción/producción, se **recomienda fuertemente** fijar `tag@sha256` para garantizar inmutabilidad.
* **Actualizaciones:** cuando se suba de versión, registrar el **cambio de tag** en el README o changelog del laboratorio.

#### SBOM y escaneo de vulnerabilidades

> Este laboratorio **no requiere scripts adicionales** para generar SBOM/escaneos; puede hacerse con herramientas contenedorizadas.

* **SBOM (opcional recomendado en local / requerido en producción):**

  ```bash
  # Syft contenedorizado (ejemplo)
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/syft:latest etl-app:1.0.0 -o spdx-json > dist/sbom-etl-app.spdx.json
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/syft:latest airflow-secure:1.0.0 -o spdx-json > dist/sbom-airflow.spdx.json
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/syft:latest postgres:13 -o spdx-json > dist/sbom-postgres.spdx.json
  ```
* **Escaneo (opcional recomendado en local / requerido en producción):**

  ```bash
  # Grype o Trivy contenedorizados (ejemplo con Grype)
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype:latest etl-app:1.0.0
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype:latest airflow-secure:1.0.0
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype:latest postgres:13
  ```
* **Criterio de aceptación local:** registrar **hallazgos críticos** y, si es posible, aplicar mitigaciones (actualizar base, fijar versión parche). En producción, **bloquear el despliegue** ante hallazgos críticos conocidos (gate).

#### Logs, auditoría y evidencias

* **Logs a stdout/stderr:** recolectados por `docker compose logs`.
* **Evidencias mínimas (local):** conservar export de logs relevantes y, si se generan, los SBOM y reportes de escaneo en `./dist/`.
* **PII/secret-free:** no almacenar secretos reales en evidencias.

#### Recursos y límites

* **Límites de recursos (recomendado):** en local pueden omitirse si el hardware es limitado, pero en entornos compartidos se recomienda establecer `cpus`, `mem_limit` y `healthcheck` para cada servicio crítico.

#### Hardening adicional (recomendado)

* **TLS (reverse proxy) para acceso externo:** solo si se publica fuera de `localhost`.
* **Política de redes:** mantener servicios internos en redes privadas de Compose; preferir nombres de servicio sobre direcciones IP.
* **Superficie mínima:** no añadir puertos/volúmenes/privilegios salvo necesidad explícita.

#### Diferencias entre entornos (matriz)

| Control              | Local (este lab)                                     | Pre-producción / producción                   |
| -------------------- | ---------------------------------------------------- | --------------------------------- |
| `.env` versionado    | **Permitido** con credenciales falsas de laboratorio | **Prohibido**                     |
| Tags de imagen       | **Requeridos** (sin `latest`)                        | **Requeridos**                    |
| Digest `@sha256`     | **Opcional**                                         | **Recomendado/Exigible**          |
| SBOM                 | **Opcional recomendado**                             | **Obligatorio**                   |
| Escaneo vuln.        | **Opcional recomendado**                             | **Obligatorio con gate**          |
| Puertos expuestos    | Solo **8080** (Airflow UI)                           | Mínimos y detrás de TLS/ingress   |
| DB publicada         | **No**                                               | **No** (salvo casos justificados) |
| Privilegios elevados | **No**                                               | **No**                            |

#### Responsabilidades

* **Mantenedores del laboratorio:** actualizar versiones/tag y anotar cambios de seguridad relevantes.
* **Usuarios del laboratorio:** no reutilizar credenciales de demo, ejecutar SBOM/escaneos cuando sea posible y reportar hallazgos.

#### Incidentes y reporte

* Si se detecta una exposición accidental (por ejemplo, publicación de un puerto no documentado o credencial real en `.env`), **crear un issue** en el repositorio con la descripción, impacto, y pasos de mitigación propuestos.
* Para vulnerabilidades críticas en imágenes base, adjuntar **salida del escáner** y proponer **bump de versión**.

####  Recomendaciones para pre-producción/producción

1. Sustituir las credenciales de laboratorio por secretos gestionados (ASM/SM/Vault) y **eliminar `.env` versionado**.
2. Fijar **`tag@sha256`** en imágenes, en especial para bases públicas (`postgres`).
3. Habilitar **gates** de seguridad en CI: SBOM + escaneo + política de severidad (bloqueo en CRÍTICO/ALTO).
4. Publicar la UI de Airflow detrás de **TLS** y autenticación; evitar exposición directa de `:8080` a internet.
5. Definir **límites de recursos** y **healthchecks** estrictos para servicios críticos.
