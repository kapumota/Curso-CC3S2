### Actividad: Patrones para módulos de infraestructura

En esta actividad: 
1. Profundizaremos en los patrones **Singleton**, **Factory**, **Prototype**, **Composite** y **Builder** aplicados a IaC.
2. Analizaremos y extenderemos el código Python existente para generar configuraciones Terraform locales.
3. Diseñaremos soluciones propias, escribir tests y evaluar escalabilidad.


#### Fase 0: Preparación
Utiliza para esta actividad el siguiente [Laboratorio 6](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio6) como referencia.

1. **Configura** el entorno virtual:

   ```bash
   cd local_iac_patterns
   python -m venv .venv && source .venv/bin/activate
   pip install --upgrade pip
   ```
2. **Genera** la infraestructura base y valida:

   ```bash
   python generate_infra.py
   cd terraform
   terraform init
   terraform validate
   ```
3. **Inspecciona** `terraform/main.tf.json` para ver los bloques `null_resource` generados.


#### Fase 1: Exploración y análisis

Para cada patrón, localiza el archivo correspondiente y responde (los códigos son de referencia):

##### 1. Singleton

```python
# singleton.py
import threading
from datetime import datetime

class SingletonMeta(type):
    _instances: dict = {}
    _lock: threading.Lock = threading.Lock()

    def __call__(cls, *args, **kwargs):
        with cls._lock:
            if cls not in cls._instances:
                instance = super().__call__(*args, **kwargs)
                cls._instances[cls] = instance
        return cls._instances[cls]

class ConfigSingleton(metaclass=SingletonMeta):
    def __init__(self, env_name: str):
        self.env_name = env_name
        self.settings: dict = {}
        self.created_at: str = datetime.utcnow().isoformat()
```

* **Tarea**: Explica cómo `SingletonMeta` garantiza una sola instancia y el rol del `lock`.

#### 2. Factory

```python
# factory.py
import uuid
from datetime import datetime

class NullResourceFactory:
    @staticmethod
    def create(name: str, triggers: dict = None) -> dict:
        triggers = triggers or {
            "factory_uuid": str(uuid.uuid4()),
            "timestamp": datetime.utcnow().isoformat()
        }
        return {
            "resource": {
                "null_resource": {
                    name: {"triggers": triggers}
                }
            }
        }
```

* **Tarea**: Detalla cómo la fábrica encapsula la creación de `null_resource` y el propósito de sus `triggers`.

#### 3. Prototype

```python
# prototype.py
from copy import deepcopy
from typing import Callable

class ResourcePrototype:
    def __init__(self, template: dict):
        self.template = template

    def clone(self, mutator: Callable[[dict], None]) -> dict:
        new_copy = deepcopy(self.template)
        mutator(new_copy)
        return new_copy
```

* **Tarea**: Dibuja un diagrama UML del proceso de clonación profunda y explica cómo el **mutator** permite personalizar cada instancia.

#### 4. Composite

```python
# composite.py
from typing import List, Dict

class CompositeModule:
    def __init__(self):
        self.children: List[Dict] = []

    def add(self, block: Dict):
        self.children.append(block)

    def export(self) -> Dict:
        merged: Dict = {"resource": {}}
        for child in self.children:
            # Imagina que unimos dicts de forma recursiva
            for rtype, resources in child["resource"].items():
                merged["resource"].setdefault(rtype, {}).update(resources)
        return merged
```

* **Tarea**: Describe cómo `CompositeModule` agrupa múltiples bloques en un solo JSON válido para Terraform.

#### 5. Builder

```python
# builder.py
import json
from composite import CompositeModule
from factory import NullResourceFactory
from prototype import ResourcePrototype

class InfrastructureBuilder:
    def __init__(self):
        self.module = CompositeModule()

    def build_null_fleet(self, count: int):
        base = NullResourceFactory.create("app")
        proto = ResourcePrototype(base)
        for i in range(count):
            def mutator(block):
                # Renombra recurso "app" a "app_<i>"
                res = block["resource"]["null_resource"].pop("app")
                block["resource"]["null_resource"][f"app_{i}"] = res
            self.module.add(proto.clone(mutator))
        return self

    def export(self, path: str = "terraform/main.tf.json"):
        with open(path, "w") as f:
            json.dump(self.module.export(), f, indent=2)
```

* **Tarea**: Explica cómo `InfrastructureBuilder` orquesta Factory -> Prototype -> Composite y genera el archivo JSON final.

#### Fase 2: Ejercicios prácticos 

Extiende el código base en una rama nueva por ejercicio:

#### Ejercicio 2.1: Extensión del Singleton

* **Objetivo**: Añadir un método `reset()` que limpie `settings` pero mantenga `created_at`.
* **Código de partida**:

  ```python
  class ConfigSingleton(metaclass=SingletonMeta):
      # ...
      def reset(self):
          # TODO: implementar
  ```
* **Validación**:

  ```python
  c1 = ConfigSingleton("dev")
  created = c1.created_at
  c1.settings["x"] = 1
  c1.reset()
  assert c1.settings == {}
  assert c1.created_at == created
  ```

#### Ejercicio 2.2: Variación de la Factory

* **Objetivo**: Crear `TimestampedNullResourceFactory` que acepte un `fmt: str`.
* **Esqueleto**:

  ```python
  class TimestampedNullResourceFactory(NullResourceFactory):
      @staticmethod
      def create(name: str, fmt: str) -> dict:
          ts = datetime.utcnow().strftime(fmt)
          # TODO: usa ts en triggers
  ```
* **Prueba**: Genera recurso con formato `'%Y%m%d'` y aplica `terraform plan`.

#### Ejercicio 2.3: Mutaciones avanzadas con Prototype

* **Objetivo**: Clonar un prototipo y, en el mutator, añadir un bloque `local_file`.
* **Referencia**:

  ```python
  def add_welcome_file(block: dict):
      block["resource"]["null_resource"]["app_0"]["triggers"]["welcome"] = "¡Hola!"
      block["resource"]["local_file"] = {
          "welcome_txt": {
              "content": "Bienvenido",
              "filename": "${path.module}/bienvenida.txt"
          }
      }
  ```
* **Resultado**: Al `terraform apply`, genera `bienvenida.txt`.

#### Ejercicio 2.4: Submódulos con Composite

* **Objetivo**: Modificar `CompositeModule.add()` para soportar submódulos:

  ```python
  # composite.py (modificado)
  def export(self):
      merged = {"module": {}, "resource": {}}
      for child in self.children:
          if "module" in child:
              merged["module"].update(child["module"])
          # ...
  ```
* **Tarea**: Crea dos submódulos "network" y "app" en la misma export y valida con Terraform.

#### Ejercicio 2.5: Builder personalizado

* **Objetivo**: En `InfrastructureBuilder`, implementar `build_group(name: str, size: int)`:

  ```python
  def build_group(self, name: str, size: int):
      base = NullResourceFactory.create(name)
      proto = ResourcePrototype(base)
      group = CompositeModule()
      for i in range(size):
          def mut(block):  # renombrar
              res = block["resource"]["null_resource"].pop(name)
              block["resource"]["null_resource"][f"{name}_{i}"] = res
          group.add(proto.clone(mut))
      self.module.add({"module": {name: group.export()}})
      return self
  ```
* **Validación**: Exportar a JSON y revisar anidamiento `module -> <name> -> resource`.

#### Fase 3: Desafíos teórico-prácticos

#### 3.1 Comparativa Factory vs Prototype

* **Contenido** (\~300 palabras): cuándo elegir cada patrón para IaC, costes de serialización profundas vs creación directa y mantenimiento.

#### 3.2 Patrones avanzados: Adapter (código de referencia)

* **Implementación**:

  ```python
  # adapter.py
  class MockBucketAdapter:
      def __init__(self, null_block: dict):
          self.null = null_block

      def to_bucket(self) -> dict:
          # Mapea triggers a parámetros de bucket simulado
          name = list(self.null["resource"]["null_resource"].keys())[0]
          return {
              "resource": {
                  "mock_cloud_bucket": {
                      name: {"name": name, **self.null["resource"]["null_resource"][name]["triggers"]}
                  }
              }
          }
  ```
* **Prueba**: Inserta en builder y exporta un recurso `mock_cloud_bucket`.

#### 3.3 Tests automatizados con pytest

* **Ejemplos**:

  ```python
  def test_singleton_meta():
      a = ConfigSingleton("X"); b = ConfigSingleton("Y")
      assert a is b

  def test_prototype_clone_independent():
      proto = ResourcePrototype(NullResourceFactory.create("app"))
      c1 = proto.clone(lambda b: b.__setitem__("f1", 1))
      c2 = proto.clone(lambda b: b.__setitem__("b1", 2))
      assert "f1" not in c2 and "b1" not in c1
  ```

#### 3.4 Escalabilidad de JSON

* **Tarea**: Mide tamaño de `terraform/main.tf.json` para `build_null_fleet(15)` vs `(150)`.
* **Discusión**: impacto en CI/CD, posibles estrategias de fragmentación.

#### 3.5 Integración con Terraform Cloud (opcional)

* **Esquema**: `builder.export_to_cloud(workspace)` usando API HTTP.
* **Diagrama**: Flujo desde `generate_infra.py` -> `terraform login` -> `apply`.

### Entregable

Para completar la actividad se debe preparar y presentar una sección de entregables en una carpeta principal llamada **Actividad14-CC3S2**. Esta carpeta debe organizarse de manera clara y estructurada, preferiblemente con subcarpetas por fase o ejercicio para facilitar la revisión.

#### Estructura recomendada de la carpeta
- **Actividad14-CC3S2/**
  - **Fase1/**
    - Documento principal (por ejemplo: "Entregable_Fase1.md" o "Entregable_Fase1.pdf")
    - Diagramas UML (por ejemplo: "Diagrama_UML_Patrones.png" o archivos .drawio/.uml)
  - **Fase2/**
    - Subcarpetas por ejercicio (por ejemplo: "Ejercicio2.1/", "Ejercicio2.2/", etc.)
    - Cada subcarpeta debe incluir: código modificado, rama Git asociada (puedes incluir un archivo README con el enlace o commit hash), y logs de Terraform.
  - **Fase3/**
    - Documentos y códigos por subdesafío (por ejemplo: "Comparativa_Factory_vs_Prototype.md", "adapter.py", etc.)
    - Diagramas y mediciones donde aplique.
  - **README.md**: Un archivo general que resuma la estructura de la carpeta, instrucciones para reproducir (por ejemplo: cómo clonar el repositorio, ejecutar tests), y cualquier nota adicional.

#### Entregables detallados por fase

#### Fase 1: Exploración y análisis
- **Documento principal**: Un archivo (Markdown, PDF o Word) que incluya:
  - Fragmentos de código destacados (usando sintaxis de código, por ejemplo: bloques `python:disable-run`
  - Explicación detallada de cada patrón:
    - **Singleton**: Cómo `SingletonMeta` garantiza una sola instancia (usando el diccionario `_instances` y el método `__call__`) y el rol del `lock` (para sincronización en entornos multihilo, evitando carreras).
    - **Factory**: Cómo `NullResourceFactory` encapsula la creación de `null_resource` (método estático `create` que genera un diccionario Terraform-compatible), y el propósito de `triggers` (para forzar re-ejecuciones en Terraform, usando UUID y timestamp para unicidad).
    - **Prototype**: Explicación del proceso de clonación profunda (usando `deepcopy` para copiar el template independientemente), y cómo el `mutator` (una función callable) permite personalizar cada clon sin afectar el original.
    - **Composite**: Cómo `CompositeModule` agrupa múltiples bloques (método `add` para agregar hijos, `export` para merging recursivo en un JSON válido para Terraform, uniendo recursos como `null_resource`).
    - **Builder**: Cómo `InfrastructureBuilder` orquesta los patrones (usa Factory para base, Prototype para clones mutados, Composite para agrupar, y exporta a JSON via `export`).
- **Diagrama UML simplificado**: Uno o más diagramas (puedes usar herramientas como PlantUML, Draw.io o Lucidchart) que muestren:
  - Clases y relaciones para cada patrón (por ejemplo: herencia en SingletonMeta, composición en Composite).
  - Un diagrama general del flujo: Factory -> Prototype -> Composite -> Builder.
  - Específicamente para Prototype: Diagrama del proceso de clonación (template -> deepcopy -> mutator -> nuevo dict).

#### Fase 2: Ejercicios prácticos
- **Ramas Git**: Crea una rama nueva por ejercicio en tu repositorio Git (basado en el lab base). Incluye en la carpeta:
  - Enlace al repositorio o exporta las ramas como archivos ZIP/tar si es necesario.
  - Para cada ejercicio: Código modificado (archivos .py actualizados) y logs de validación (archivos .txt o .log con salida de comandos como `terraform plan` y `terraform apply`).
- **Ejercicio 2.1 (Extensión del Singleton)**:
  - Archivo modificado: `singleton.py` con el método `reset()` implementado (limpia `settings` pero mantiene `created_at`).
  - Log de prueba: Archivo con la salida del assert proporcionado (por ejemplo: script de test ejecutado).
- **Ejercicio 2.2 (Variación de la Factory)**:
  - Archivo modificado: `factory.py` con la clase `TimestampedNullResourceFactory` (usa `strftime(fmt)` en triggers).
  - Log: Salida de `terraform plan` mostrando el recurso con formato de timestamp (por ejemplo: '%Y%m%d').
- **Ejercicio 2.3 (Mutaciones avanzadas con Prototype)**:
  - Archivo modificado: `prototype.py` o integración en `builder.py` con mutator que añade `local_file`.
  - Log: Salida de `terraform apply` confirmando la creación de `bienvenida.txt`.
- **Ejercicio 2.4 (Submódulos con Composite)**:
  - Archivo modificado: `composite.py` con soporte para "module" en `export()`.
  - Log: JSON exportado con submódulos "network" y "app", y salida de `terraform validate`.
- **Ejercicio 2.5 (Builder personalizado)**:
  - Archivo modificado: `builder.py` con método `build_group(name, size)`.
  - Log: JSON exportado mostrando anidamiento `module -> <name> -> resource`, y salida de Terraform.

#### Fase 3: Desafíos teórico-prácticos
- **3.1 Comparativa Factory vs Prototype**:
  - Documento (~300 palabras): Archivo Markdown/PDF explicando cuándo elegir cada uno en IaC (Factory para creación simple/estandarizada, Prototype para variaciones eficientes via clones). Discute costes (serialización profunda en Prototype es más costosa en memoria para objetos grandes vs creación directa en Factory) y mantenimiento (Prototype reduce duplicación de código).
- **3.2 Patrones avanzados: Adapter**:
  - Archivo de código: `adapter.py` con la clase `MockBucketAdapter` implementada (mapea null_resource a mock_cloud_bucket).
  - Integración: Modificación en `builder.py` para insertar el adapter.
  - Log/Prueba: JSON exportado con `mock_cloud_bucket`, y salida de Terraform.
- **3.3 Tests automatizados con pytest**:
  - Archivo de tests: `test_patterns.py` con al menos los ejemplos proporcionados (test_singleton_meta, test_prototype_clone_independent), y posiblemente más para cubrir otros patrones.
  - Log: Salida de `pytest` (por ejemplo: archivo .txt con resultados de tests passing).
- **3.4 Escalabilidad de JSON**:
  - Medición: Script o log mostrando tamaño de `main.tf.json` para `build_null_fleet(15)` y `(150)` (usa comandos como `ls -l` o Python para medir bytes).
  - Documento: Discusión (~200 palabras) sobre impacto en CI/CD (tiempos de parseo, límites de Git/storage) y estrategias de fragmentación (por ejemplo: módulos Terraform separados, HCL en lugar de JSON, o tools como Terragrunt).

### Notas generales para la entrega
- **Formato y calidad**: Usa Markdown para documentos por simplicidad. Asegura que los códigos sean ejecutables y los diagramas legibles. Incluye referencias al lab base (GitHub link).
- **Validación general**: Ejecuta la preparación (Fase 0) y verifica que todo funcione (por ejemplo: `terraform validate` sin errores).
- **Repositorio Git**: Sube la carpeta completa a GitHub o similar, y incluye el enlace en el README. Cada fase/ejercicio debe tener commits descriptivos.
- **Completitud**: La actividad está completa si todos los entregables de Fase 1 y 2 están presentes, y al menos 3/5 de Fase 3. Si hay omisiones, justifícalas en el README.
