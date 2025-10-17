### Laboratorio: Patrones de arquitectura en IaC local (Terraform + Python)

Este laboratorio reúne **cinco módulos** que demuestran patrones de diseño aplicados a **Infraestructura como Código (IaC) local** usando**Terraform en formato JSON** y pequeños **programas en Python**:

- `Adapter/`
- `Facade/`
- `Inversion_control/` (Inversión de control)
- `Inyeccion_dependencias/`
- `Mediator/`

Cada carpeta incluye su propio `Instrucciones.md` con detalles conceptuales. Este **README** consolida los **requisitos**, **flujo de ejecución común** y **comandos mínimos** para correr cada módulo de manera reproducible en local.

#### Requisitos

- **Terraform** ≥ 1.5 (probado con 1.6/1.7).
- **Python** ≥ 3.9 (se recomienda 3.10+). No requiere librerías externas (usa `stdlib`).
- **Make** (solo para `Inversion_control/`).

> Sugerencia: exporta variables de entorno para una caché de plugins local y entorno reproducible:
>
> ```bash
> export TF_DATA_DIR="$PWD/.terraform"
> export TF_PLUGIN_CACHE_DIR="$PWD/.terraform/plugin-cache"
> mkdir -p "$TF_PLUGIN_CACHE_DIR"
> ```


#### Flujo de ejecución (común)

1. **Entrar a la carpeta del módulo** (por ejemplo, `Adapter/`).  
2. **Generar archivos JSON** (si el módulo incluye un generador):
   ```bash
   python main.py
   ```
   Esto crea/actualiza `*.tf.json` con la **topología local** (recursos `null_resource`, `local_file`, etc.).
3. **Inicializar y aplicar con Terraform**:
   ```bash
   terraform init
   terraform plan         # opcional, para revisar cambios
   terraform apply -auto-approve
   ```
4. **Verificar la salida en consola** (los `local-exec` imprimen mensajes trazables).
5. **Destruir cuando termines**:
   ```bash
   terraform destroy -auto-approve
   ```

> Todos los módulos son **locales** (no crean recursos en la nube). Trabajan con `provider "null"` y artefactos de salida locales.


#### Módulos y comandos mínimos

#### 1) `Adapter/`
**Patrón:** *Adapter* para transformar **metadatos de identidades/roles** a recursos locales (`null_resource`).  
**Archivos clave:** `main.py`, `access.py`, `main.tf.json`, `Instrucciones.md`.

**Ejecutar:**
```bash
cd Adapter
python main.py              # genera/actualiza main.tf.json según el adapter
terraform init
terraform apply -auto-approve
# terraform destroy -auto-approve   # al finalizar
```

#### 2) `Facade/`
**Patrón:** *Facade* orquesta varios módulos simples detrás de una interfaz única.  
**Archivos clave:** `provider.tf.json`, `bucket.tf.json`, `bucket_access.tf.json`, `main.py`, `Instrucciones.md`.

**Ejecutar:**
```bash
cd Facade
python main.py              # materializa JSONs de bucket + accesos
terraform init
terraform apply -auto-approve
# terraform destroy -auto-approve
```

#### 3) `Inversion_control/`
**Patrón:** *Inversión de control (IoC)*: un módulo **red** publica salidas que otro módulo **server** consume dinámicamente.  
**Archivos clave:** `Makefile`, `main.py`, `main.tf.json`, `network/network.tf.json`, `Instrucciones.md`.

**Comandos (vía Make):**
```bash
cd Inversion_control
make prepare         # crea .terraform/ y cachés
make network         # aplica el módulo de red y publica network/network_outputs.json
make server          # genera main.tf.json a partir de las salidas y aplica el servidor
# make destroy       # destruye ambos módulos
# make clean         # limpia artefactos locales
```

> Si prefieres **sin Make**:
> ```bash
> cd Inversion_control/network
> terraform init && terraform apply -auto-approve
> cd ..
> python main.py
> terraform init && terraform apply -auto-approve
> ```

#### 4) `Inyeccion_dependencias/`

**Patrón:** *Inyección de dependencias*: el **servidor** recibe la **red** y otros parámetros como dependencias explícitas.  
**Archivos clave:** `network/` (Terraform de la red), `main.py` (genera `server.tf.json`), `Instrucciones.md`.

**Ejecutar:**
```bash
cd Inyeccion_dependencias/network
terraform init && terraform apply -auto-approve   # provisiona la red local
cd ..
python main.py                                    # genera server.tf.json con dependencias
terraform init && terraform apply -auto-approve   # provisiona el servidor que usa la red
# terraform destroy -auto-approve                  # en cada carpeta, para limpiar
```

#### 5) `Mediator/`

**Patrón:** *Mediador*: coordina dependencias **complejas** (red -> servidor -> firewall -> auditoría) sin acoplar módulos directamente.  
**Archivos clave:** ver `Instrucciones.md` del módulo (define `network.py`, `server.py`, `firewall.py`, `audit.py`, etc.).

**Ejecutar (esquema):**
```bash
cd Mediator
python network.py       # genera JSON de red + publica dependencia
python server.py        # consume dependencia de red y crea servidor
python firewall.py      # media dependencias y aplica reglas
python audit.py         # valida estado y crea/lee artefactos locales
terraform init && terraform apply -auto-approve
# terraform destroy -auto-approve
```

> Según el diseño, algunos pasos pueden integrarse en un **único `main.py`**. Revisa `Instrucciones.md` de este módulo para la secuencia exacta.

#### Buenas prácticas y reproducibilidad

- **Idempotencia:** Los generadores (`main.py`) deben producir el mismo JSON dado el mismo input. Usa seeds/constantes si agregas aleatoriedad.
- **Caché de plugins:** `TF_PLUGIN_CACHE_DIR` acelera y hace más estable la ejecución en CI y local.
- **Plan como gate:** `terraform plan -detailed-exitcode` puede emplearse en CI para detectar *drift* (0=sin cambios, 2=hay cambios).
- **Formato/lint:** `terraform fmt -recursive` y `terraform validate` antes de aplicar. (Opcional: `tflint`, `checkov`/OPA/Rego si deseas añadir *hardening*).
- **Destroy disciplinado:** destruye recursos locales al terminar para *resetear* el entorno del laboratorio.
- **Trazabilidad:** conserva archivos generados (por ejemplo, `network_outputs.json`) en `out/` o dentro del módulo para diagnósticos.


Para explicaciones teóricas y ejemplos concretos de cada patrón, revisa los **`Instrucciones.md`** dentro de cada carpeta.
