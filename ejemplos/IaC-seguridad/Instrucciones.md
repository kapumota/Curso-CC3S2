### IaC Local con DevSecOps: Plan -> Policy -> Apply -> Drift -> SBOM

Este ejemplo es **100% local** (sin proveedores cloud) y muestra, en código, conceptos clave de Infraestructura como Código (IaC) y DevSecOps:
**plan -> policy (OPA opcional) -> apply -> drift -> SBOM -> tests**.

Todo está diseñado para ejecutarse en tu entorno de Python `bdd`.   No se usa AWS, GCP, Azure ni ningún servicio externo.

#### 1. Activar el entorno Python (`bdd`)

Este proyecto asume que ya tienes un virtualenv llamado `bdd`.

```bash
source bdd/bin/activate
pip install -r requirements.txt
```


#### 2. Configurar las variables de entorno locales

Copia la plantilla `.env.example` a `.env`:

```bash
cp .env.example .env   # edita si quieres (DATA_ROOT, EVIDENCE_DIR, etc.)
```

Luego edita `.env` si deseas cambiar rutas o el "contexto de despliegue" local. Ejemplo de `.env`:

```bash
APP_ENV=dev
DATA_ROOT=./data
EVIDENCE_DIR=./.evidence
CLASSIFICATION=Restricted
DEFAULT_PUBLIC=false
```

Significa:

* `DATA_ROOT`
  Carpeta donde se van a "provisionar" los recursos locales (simulan buckets).
  Por defecto `./data`.

* `EVIDENCE_DIR`
  Carpeta donde se guarda evidencia auditable: plan, drift, SBOM.
  Por defecto `./.evidence`.

* `APP_ENV`, `CLASSIFICATION`, `DEFAULT_PUBLIC`
  Simulan controles de gobierno y clasificación de datos (tipo Restricted / Internal), pero sin depender de un proveedor externo.


#### 3. Flujo de trabajo principal

Ejecuta estos targets del `Makefile` en orden lógico:

```bash
make tools        # Escaneo simple de secretos en el repo (búsqueda de "password", "token", etc.)
make plan         # Genera el plan en ./.evidence/plan.json (NO aplica todavía)
make policy       # (Opcional) Aplica políticas Rego con 'opa' si lo tienes instalado
make apply        # Crea / actualiza los recursos locales (carpetas bajo data/ + metadata.json)
make drift-check  # Detecta drift entre state/state.json y lo que realmente hay en data/
make sbom         # Genera un SBOM local con hashes -> ./.evidence/sbom.json
make test         # Ejecuta pytest sin red, usando inyección de dependencias
```

#### ¿Qué hace cada uno?

#### `make tools`

* Corre `tools/secrets_scan.py` para detectar strings que parezcan credenciales.
* Esto actúa como un gate básico de seguridad.

#### `make plan`

* Lee `desired/config.yaml` (estado deseado).
* Lee `state/state.json` (estado registrado).
* Calcula qué hay que crear / actualizar.
* Escribe `./.evidence/plan.json` con esa intención.
* Este archivo es evidencia auditable ("esto es lo que pienso cambiar").

#### `make policy`

* Si tienes instalado `opa`, revisa el plan con reglas Rego:

  * `policies/no_public.rego` bloquea buckets marcados como `public: true`.
  * `policies/no_secret_outputs.rego` evita exponer información sensible en outputs.
* Si no tienes `opa`, simplemente avisa y sigue.
* Esto simula "policy as code": seguridad como gate automático, no como checklist manual.

#### `make apply`

* Ejecuta `tools/apply.py`.
* Crea las carpetas reales dentro de `DATA_ROOT` (por defecto `./data/`), cada una con su `metadata.json`.
* Actualiza `state/state.json` para reflejar lo que quedó "provisionado".
* Aplica las políticas de prefijo permitido (principio de mínimo privilegio).

#### `make drift-check`

* Ejecuta `tools/drift_check.py`.
* Compara lo que dice `state/state.json` vs lo que realmente hay en `data/`.
* Si alguien tocó a mano los metadatos locales (simulando "cambio manual en producción"), lo reporta y falla.
* Guarda el resultado en `./.evidence/drift.json`.

Esto modela la detección de drift en runtime, que es parte clave de gobernanza e inspección continua.

#### `make sbom`

* Ejecuta `tools/sbom.py`.
* Recorre el repo, calcula hash SHA-256 de cada archivo y escribe `./.evidence/sbom.json`.
* Ese archivo SBOM local es una base para trazabilidad y cadena de suministro (saber qué artefactos existen, con qué checksum).

#### `make test`

* Ejecuta `pytest -q`.
* Las pruebas (`tests/test_service.py`) usan inyección de dependencias (Dependency Injection):

  * `BucketService` trabaja contra la abstracción `StoragePort`.
  * En vez de hablar con "la nube", hablamos con `LocalEncryptedStorage`, que sólo escribe carpetas y `metadata.json`.
* Esto demuestra desacoplar la lógica de negocio de su backend concreto (patrón puerto/adaptador).

#### 4. Resetear todo (limpieza local segura)

Si quieres volver el entorno a "estado inicial", puedes usar:

```bash
make clean
```

Este target hace tres cosas:

1. Borra los recursos locales que fueron "aprovisionados":

   * elimina el contenido de `data/` (simulación de buckets locales)
2. Borra la evidencia generada:

   * elimina el contenido de `.evidence/` (planes, drift, SBOM anteriores)
3. Restaura el estado declarado:

   * sobrescribe `state/state.json` con:

     ```json
     { "version": 1, "resources": [] }
     ```

Después de `make clean`, el proyecto queda listo para volver a correr `make plan` + `make apply` como si fuera la primera vez.

#### 5. Temas tratados aquí

**12-Factor / Config por entorno**

* La configuración operacional está en `.env`, no hardcodeada en el código.
* Variables como `DATA_ROOT`, `EVIDENCE_DIR`, `CLASSIFICATION` modelan despliegues en distintos "ambientes" sin duplicar código.

**Puertos y adaptadores (DI)**

* `app/ports.py` define la interfaz (`StoragePort`).
* `app/localfs.py` implementa esa interfaz usando solo el filesystem local.
* `app/service.py` contiene la lógica de negocio e invariantes de seguridad/gobierno (por ejemplo, marcar `encrypted: true`, registrar clasificación).
* Esto permite testear sin red y sin proveedor externo.

**Planificación y evidencia**

* `tools/plan.py` genera un plan estructurado y lo deja en `.evidence/plan.json`.
* Ese JSON es "auditable": puedes guardarlo, firmarlo, revisarlo antes de aplicar.
* Equivalente a `terraform plan`, pero totalmente local.

**Gates / Políticas como código**

* `policies/no_public.rego` y `policies/no_secret_outputs.rego` actúan como reglas automáticas.
* `make policy` aplica esas reglas al plan antes de permitir cambios.
* Seguridad deja de ser revisión manual y pasa a ser un gate reproducible.

**Apply controlado**

* `tools/apply.py` materializa lo que dice el plan: crea carpetas bajo `data/` y escribe `metadata.json`.
* Actualiza `state/state.json` para que quede registro de "qué está declarado como existente".
* Esto simula un `terraform apply`, pero sin nube.

**Drift**

* `tools/drift_check.py` detecta desviaciones entre el estado declarado y la realidad física.
* Si hay drift, falla. Además deja evidencia en `.evidence/drift.json`.

**SBOM local**

* `tools/sbom.py` genera un inventario firmado con hashes SHA-256 de los archivos locales.
* Eso modela el control de cadena de suministro / trazabilidad de artefactos.

**Pruebas sin red**

* `pytest` verifica que `BucketService` respeta las reglas (crear recursos con clasificación, actualizar políticas de prefijo, etc.) sin depender de servicios externos.
* Esto reproduce la idea de que la capa de negocio tiene que ser testeable de forma aislada, algo central en DevSecOps (romper dependencias directas a servicios externos, usar inyección de dependencias, etc.).

