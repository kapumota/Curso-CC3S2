### Actividad: Escribiendo infraestructura como código en un entorno local con Terraform

####  Contexto

Imagina que gestionas docenas de entornos de desarrollo locales para distintos proyectos (app1, app2, ...). En lugar de crear y parchear manualmente cada carpeta, construirás un generador en Python que produce automáticamente:

* **`network.tf.json`** (variables y descripciones)
* **`main.tf.json`** (recursos que usan esas variables)

Después verás cómo Terraform identifica cambios, remedia desvíos manuales y permite migrar configuraciones legacy a código. Todo sin depender de proveedores en la nube, Docker o APIs externas.


#### Fase 0: Preparación 

1. **Revisa** el [laboratorio 5](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio5)  :

   ```
   modules/simulated_app/
     ├─ network.tf.json
     └─ main.tf.json
   generate_envs.py
   ```
2. **Verifica** que puedes ejecutar:

   ```bash
   python generate_envs.py
   cd environments/app1
   terraform init
   ```
3. **Objetivo**: conocer la plantilla base y el generador en Python.

####  Fase 1: Expresando el cambio de infraestructura

* **Concepto**
Cuando cambian variables de configuración, Terraform los mapea a **triggers** que, a su vez, reconcilian el estado (variables ->triggers ->recursos).

* **Actividad**

  - Modifica en `modules/simulated_app/network.tf.json` el `default` de `"network"` a `"lab-net"`.
  - Regenera `environments/app1` con `python generate_envs.py`.
  - `terraform plan` observa que **solo** cambia el trigger en `null_resource`.

* **Pregunta**

  * ¿Cómo interpreta Terraform el cambio de variable?
  * ¿Qué diferencia hay entre modificar el JSON vs. parchear directamente el recurso?
  * ¿Por qué Terraform no recrea todo el recurso, sino que aplica el cambio "in-place"?
  * ¿Qué pasa si editas directamente `main.tf.json` en lugar de la plantilla de variables?

#### Procedimiento

1. En `modules/simulated_app/network.tf.json`, cambia:

   ```diff
     "network": [
       {
   -     "default": "net1",
   +     "default": "lab-net",
         "description": "Nombre de la red local"
       }
     ]
   ```
2. Regenera **solo** el app1:

   ```bash
   python generate_envs.py
   cd environments/app1
   terraform plan
   ```

   Observa que el **plan** indica:

   > \~ null\_resource.app1: triggers.network: "net1" -> "lab-net"

#### Fase 2: Entendiendo la inmutabilidad

#### A. Remediación de 'drift' (out-of-band changes)

1. **Simulación**

   ```bash
   cd environments/app2
   # edita manualmente main.tf.json: cambiar "name":"app2" ->"hacked-app"
   ```
2. Ejecuta:

   ```bash
   terraform plan
   ```

    Verás un plan que propone **revertir** ese cambio.
3. **Aplica**

   ```bash
   terraform apply
   ```
    Y comprueba que vuelve a "app2".
   

#### B. Migrando a IaC

* **Mini-reto**
 1. Crea en un nuevo directorio `legacy/` un simple `run.sh` + `config.cfg` con parámetros (p.ej. puerto, ruta).

    ```
     echo 'PORT=8080' > legacy/config.cfg
     echo '#!/bin/bash' > legacy/run.sh
     echo 'echo "Arrancando $PORT"' >> legacy/run.sh
     chmod +x legacy/run.sh
     ```
  2. Escribe un script Python que:

     * Lea `config.cfg` y `run.sh`.
     * Genere **automáticamente** un par `network.tf.json` + `main.tf.json` equivalente.
     * Verifique con `terraform plan` que el resultado es igual al script legacy.

#### Fase 3: Escribiendo código limpio en IaC 

| Conceptos                       | Ejercicio rápido                                                                                               |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| **Control de versiones comunica contexto** | - Haz 2 commits: uno que cambie `default` de `name`; otro que cambie `description`. Revisar mensajes claros. |
| **Linting y formateo**                     | - Instala `jq`. Ejecutar `jq . network.tf.json > tmp && mv tmp network.tf.json`. ¿Qué cambió?                 |
| **Nomenclatura de recursos**               | - Renombra en `main.tf.json` el recurso `null_resource` a `local_server`. Ajustar generador Python.           |
| **Variables y constantes**                 | - Añade variable `port` en `network.tf.json` y usarla en el `command`. Regenerar entorno.                     |
| **Parametrizar dependencias**              | - Genera `env3` de modo que su `network` dependa de `env2` (p.ej. `net2-peered`). Implementarlo en Python.    |
| **Mantener en secreto**                    | - Marca `api_key` como **sensitive** en el JSON y leerla desde `os.environ`, sin volcarla en disco.           |

#### Fase 4: Integración final y discusión

1. **Recorrido** por:

   * Detección de drift (*remediation*).
   * Migración de legacy.
   * Estructura limpia, módulos, variables sensibles.
2. **Preguntas abiertas**:

   * ¿Cómo extenderías este patrón para 50 módulos y 100 entornos?
   * ¿Qué prácticas de revisión de código aplicarías a los `.tf.json`?
   * ¿Cómo gestionarías secretos en producción (sin Vault)?
   * ¿Qué workflows de revisión aplicarías a los JSON generados?


#### Ejercicios

1. **Drift avanzado**

   * Crea un recurso "load\_balancer" que dependa de dos `local_server`. Simula drift en uno de ellos y observa el plan.

2. **CLI Interactiva**

   * Refactoriza `generate_envs.py` con `click` para aceptar:

     ```bash
     python generate_envs.py --count 3 --prefix staging --port 3000
     ```

3. **Validación de Esquema JSON**

   * Diseña un JSON Schema que valide la estructura de ambos TF files.
   * Lanza la validación antes de escribir cada archivo en Python.

4. **GitOps Local**

   * Implementa un script que, al detectar cambios en `modules/simulated_app/`, regenere **todas** las carpetas bajo `environments/`.
   * Añade un hook de pre-commit que ejecute `jq --check` sobre los JSON.

5. **Compartición segura de secretos**

   * Diseña un mini-workflow donde `api_key` se lee de `~/.config/secure.json` (no versionado) y documenta cómo el equipo la distribuye sin comprometer seguridad.

### Estructura del entregable

La carpeta `Actividad13-CC3S2` de respuestas debe contener:

1. **Carpeta `modules/simulated_app/`**:
   - `network.tf.json`: Archivo JSON modificado con el cambio en el `default` de `"network"` a `"lab-net"`, además de cualquier adición como la variable `port` y la marca de `sensitive` para `api_key`.
   - `main.tf.json`: Archivo JSON actualizado con el renombre del recurso `null_resource` a `local_server` y cualquier ajuste para usar la variable `port` en el `command`.

2. **Carpeta `environments/`**:
   - Subcarpetas `app1`, `app2`, `env3`, cada una con:
     - `network.tf.json`: Generado por el script Python, reflejando las variables correspondientes (incluyendo dependencias como `net2-peered` para `env3`).
     - `main.tf.json`: Generado con los recursos configurados, usando las variables definidas.
   - Cada subcarpeta debe ser funcional para ejecutar `terraform init` y `terraform plan`.

3. **Carpeta `legacy/`**:
   - `config.cfg`: Archivo con parámetros de ejemplo (ejemplo, `PORT=8080`).
   - `run.sh`: Script bash de ejemplo que usa los parámetros de `config.cfg`.

4. **Scripts Python**:
   - `generate_envs.py`: Script modificado para:
     - Generar entornos (`app1`, `app2`, `env3`) con las configuraciones especificadas.
     - Implementar la dependencia de `env3` en `env2` (ejemplo, `net2-peered`).
     - Leer `api_key` desde `os.environ` para mantenerlo seguro.
     - (Opcional, si se completa el ejercicio 2) Refactorizado con `click` para aceptar argumentos como `--count`, `--prefix`, `--port`.
   - (Opcional, si se completa el ejercicio 3) Script adicional o función en `generate_envs.py` para validar los archivos JSON generados contra un JSON Schema.

5. **Carpeta `scripts/` (opcional, para organización)**:
   - Script para el **GitOps Local** (ejercicio 4): Un script que detecte cambios en `modules/simulated_app/` y regenere todas las carpetas bajo `environments/`.
   - Hook de pre-commit que ejecute `jq --check` sobre los JSON generados.

6. **Archivo `secure.json` (no versionado)**:
   - Ubicado en `~/.config/secure.json` (fuera del repositorio, según ejercicio 5).
   - Contiene el `api_key` para que el script Python lo lea sin versionarlo.
   - Incluir una nota en la documentación sobre su ubicación y manejo.

7. **Documentación (`README.md`)**:
   - Un archivo `README.md` que explique:
     - El propósito de la actividad.
     - La estructura de los archivos y carpetas.
     - Instrucciones para ejecutar el proyecto (ejemplo, `python generate_envs.py`, `terraform init`, `terraform plan`).
     - Respuestas a las preguntas de la **Fase 1**:
       - ¿Cómo interpreta Terraform el cambio de variable?
       - ¿Qué diferencia hay entre modificar el JSON vs. parchear directamente el recurso?
       - ¿Por qué Terraform no recrea todo el recurso, sino que aplica el cambio "in-place"?
       - ¿Qué pasa si editas directamente `main.tf.json` en lugar de la plantilla de variables?
     - Respuestas a las preguntas abiertas de la **Fase 4**:
       - ¿Cómo extenderías este patrón para 50 módulos y 100 entornos?
       - ¿Qué prácticas de revisión de código aplicarías a los `.tf.json`?
       - ¿Cómo gestionarías secretos en producción (sin Vault)?
       - ¿Qué workflows de revisión aplicarías a los JSON generados?
     - Detalles sobre los ejercicios completados (ejemplo, drift avanzado, CLI interactiva, validación de esquema, GitOps, manejo de secretos).
     - Instrucciones para configurar el entorno (ejemplo, instalar `jq`, dependencias de Python como `click` si se usa, y Terraform).

8. **Historial de Git**:
   - Al menos dos commits claros (según la **Fase 3**):
     - Uno para el cambio del `default` de `name`.
     - Otro para el cambio de `description`.
     - Mensajes de commit descriptivos, como:
       - `Change default network name to lab-net`
       - `Update description for network variable`

9. **Opcional (si se completa el ejercicio 1)**:
   - Archivos adicionales en `modules/simulated_app/` para el recurso `load_balancer` que dependa de dos `local_server`, con evidencia de simulación de drift y el plan de Terraform.

10. **Opcional (si se completa el ejercicio 5)**:
    - Documentación en el `README.md` sobre el mini-workflow para compartir `api_key` de forma segura (ejemplo, cómo el equipo distribuye `secure.json` sin versionarlo).

#### Ejemplo de estructura de directorios

```
Actividad13-CC3S2/
├── modules/
│   └── simulated_app/
│       ├── network.tf.json
│       └── main.tf.json
├── environments/
│   ├── app1/
│   │   ├── network.tf.json
│   │   └── main.tf.json
│   ├── app2/
│   │   ├── network.tf.json
│   │   └── main.tf.json
│   └── env3/
│       ├── network.tf.json
│       └── main.tf.json
├── legacy/
│   ├── config.cfg
│   └── run.sh
├── scripts/
│   └── gitops_regenerate.sh  # Para GitOps Local (ejercicio 4)
├── generate_envs.py
├── .git/
├── .pre-commit-config.yaml  # Hook de pre-commit (ejercicio 4)
└── README.md
```

#### Notas sobre la implementación

1. **Fase 1: Expresando el cambio de infraestructura**:
   - El cambio en `network.tf.json` (`default: "net1" -> "lab-net"`) debe reflejarse en los entornos generados.
   - Usa `terraform plan` para verificar que solo el `trigger` de `null_resource` cambia, mostrando la capacidad de Terraform para detectar cambios incrementales.

2. **Fase 2: Inmutabilidad y migración**:
   - En el caso de `app2`, simula el drift editando `main.tf.json` y usa `terraform apply` para revertirlo.
   - Para el mini-reto, el script Python debe leer `config.cfg` y `run.sh` de `legacy/` y generar archivos `.tf.json` equivalentes, asegurando que `terraform plan` refleje la misma configuración.

3. **Fase 3: Código limpio**:
   - Usa `jq` para formatear los JSON y asegurar consistencia.
   - Ajusta `generate_envs.py` para renombrar recursos, añadir la variable `port`, y manejar dependencias entre entornos (ejemplo, `env3` depende de `env2`).
   - Implementa `api_key` como variable sensible, leída desde `os.environ`.

4. **Fase 4: Integración y discusión**:
   - Responde las preguntas abiertas en el `README.md` con propuestas prácticas, como:
     - Escalar a 50 módulos y 100 entornos: Usar plantillas modulares, scripts de automatización, y un sistema de nomenclatura estandarizado.
     - Revisión de código: Usar linters (ejemplo, `jq`), validación de esquemas JSON, y revisiones en pull requests.
     - Secretos en producción: Usar archivos locales no versionados (como `secure.json`) o variables de entorno cifradas.
     - Workflows: Integrar pre-commit hooks y CI/CD para validar JSON y ejecutar `terraform plan`.

5. **Ejercicios adicionales**:
   - Si implementas el ejercicio 1 (drift avanzado), incluye el recurso `load_balancer` en `main.tf.json` y documenta el resultado de `terraform plan`.
   - Para el ejercicio 2, usa la librería `click` en `generate_envs.py` para una CLI interactiva.
   - Para el ejercicio 3, define un JSON Schema (puedes usar `jsonschema` en Python) para validar los `.tf.json`.
   - Para el ejercicio 4, implementa un script bash o Python para GitOps y un hook de pre-commit con `jq`.
   - Para el ejercicio 5, describe un flujo seguro para compartir `secure.json` (ejemplo, mediante canales cifrados como email seguro o herramientas como 1Password).

#### Ejercicios completados
- **Drift avanzado**: Implementado recurso `load_balancer` con dependencias.
- **CLI interactiva**: `generate_envs.py` refactorizado con `click`.
- **Validación de esquema**: JSON Schema para validar `.tf.json`.
- **GitOps Local**: Script para regenerar entornos y hook de pre-commit con `jq`.
- **Secretos**: Workflow para `secure.json` descrito.

#### Notas
- No versionar `~/.config/secure.json`.
- Verificar formato JSON con `jq . file.json > tmp && mv tmp file.json`.

#### Consejos para subir al repositorio

- Asegúrate de que `.git/` esté inicializado en `Actividad13-CC3S2/` y que los commits reflejen los cambios solicitados.
- Excluye `secure.json` y otros archivos sensibles usando `.gitignore`.
- Verifica que todos los archivos `.tf.json` sean válidos ejecutando `terraform init` y `terraform plan` en cada entorno.
- Prueba el script `generate_envs.py` para asegurar que genera correctamente los entornos.
- Si implementas los ejercicios opcionales, documéntalos claramente en el `README.md`.
