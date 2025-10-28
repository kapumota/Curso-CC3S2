### Actividad 8: El patrón AAA-Red-Green-Refactor

El proyecto se desarrollará de forma incremental utilizando el proceso RGR (Red, Green, Refactor) y pruebas unitarias con pytest para asegurar la correcta implementación de cada funcionalidad.

#### El patrón Arrange-Act-Assert

El patrón **Arrange-Act-Assert (AAA)** organiza las pruebas unitarias en tres pasos claros: preparar el escenario (**Arrange**), ejecutar el comportamiento (**Act**) y verificar el resultado (**Assert**). Las pruebas son el primer uso real del código: lo invocan como en la aplicación, capturan resultados y validan expectativas, dando retroalimentación inmediata sobre diseño y usabilidad del API. Los nombres descriptivos de clases y métodos de prueba cuentan la "historia" del comportamiento esperado (por ejemplo, `TestUsername` y `test_converts_to_lowercase`).

Para que las pruebas sean realmente útiles, se aplican los principios **FIRST**:

* **F**ast: ejecución muy rápida para ciclos TDD cortos.
* **I**solated: independientes entre sí, sin dependencias de orden o estado.
* **R**epeatable: deterministas, sin factores externos (tiempo/red/red DB); se apoya en *stubs/mocks* cuando haga falta.
* **S**elf-verifying: automatizadas, reportan "aprobado/fallado" sin inspección manual.
* **T**imely: se escriben antes del código productivo (núcleo de TDD).

Buena práctica: **una aserción por prueba**. Esto facilita entender fallos y hace más mantenible la suite. En TDD, ver pruebas rojas volverse verdes (RGR) aporta confianza y guía el diseño, promoviendo código limpio y robusto.

#### Ejemplo

El código del laboratorio muestra un ejemplo de **carrito de compras** que ilustra AAA en operaciones clave (agregar, remover, actualizar cantidades, totales y descuentos) y muestra una estructura mínima de proyecto con `src/`, `tests/`, `requirements.txt` y `pytest.ini`. Este enfoque estandariza las pruebas, mejora su legibilidad y facilita su ejecución rápida dentro del flujo TDD.

### Introducción a Red-Green-Refactor

**Red-Green-Refactor** es un ciclo de TDD que consta de tres etapas:

1. **Red (Fallo):** Escribir una prueba que falle porque la funcionalidad aún no está implementada.
2. **Green (Verde):** Implementar la funcionalidad mínima necesaria para que la prueba pase.
3. **Refactor (Refactorizar):** Mejorar el código existente sin cambiar su comportamiento, manteniendo todas las pruebas pasando.

Este ciclo se repite iterativamente para desarrollar funcionalidades de manera segura y eficiente.

#### Ejemplo

La funcionalidad que mejoraremos será una clase `ShoppingCart` que permite agregar artículos, eliminar artículos y calcular el total del carrito. El código es acumulativo, es decir, cada iteración se basará en la anterior. Utiliza la siguiente estructura para esta actividad:

```
Actividad8-CC3S2/
├── pytest.ini
├── Makefile
├── requirements.txt
├── src/
│   ├── __init__.py
│   ├── shopping_cart.py
│   ├── carrito.py
│   └── factories.py
├── tests/
│   ├── __init__.py
│   └── test_shopping_cart.py
└── evidencias/
    ├── rgr.txt
    ├── diff_refactor.md
    ├── resumen_cobertura.md
    ├── decisiones.md
    └── analisis.md
```

> **Antes de correr:**
>
> ```bash
> mkdir -p out evidencias
> ```

#### Observaciones y configuración

* **Markers de pytest** (si usas `@pytest.mark.smoke` y `@pytest.mark.regression`), declara en `pytest.ini`:

  ```ini
  [pytest]
  addopts = -ra
  testpaths = tests
  markers =
      smoke: fast smoke tests
      regression: extended regression suite
  ```

* **Mocks**: si no usarás `pytest-mock`, emplea `unittest.mock`:

  ```python
  from unittest.mock import Mock

  def test_pago_exitoso():
      from src.shopping_cart import ShoppingCart
      cart = ShoppingCart(); cart.add_item("x", 10.0)
      pg = Mock(); pg.charge.return_value = True
      assert cart.process_payment(pg) is True
  ```

  (Alternativa: añade `pytest-mock` a `requirements.txt`.)

* **Quality gate de cobertura** (falla si no alcanzan el mínimo):

  ```bash
  pytest -q --maxfail=1 --disable-warnings --cov=src --cov-report=term-missing --cov-fail-under=90 --junitxml=out/junit.xml
  pytest --cov=src --cov-report=term-missing > out/coverage.txt
  ```

* **Semillas globales opcionales** (no toca `src/`):

  ```python
  # tests/conftest.py
  import random
  from faker import Faker
  import pytest

  @pytest.fixture(autouse=True)
  def _stable_seeds():
      random.seed(123)
      try:
          Faker().seed_instance(123)
      except Exception:
          pass
  ```

Puedes revisar la versión completa aquí en el [Laboratorio3](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio3) del curso.

#### Instalación rápida

```bash
python -m venv .venv
. .venv/bin/activate  # (Windows: .venv\Scripts\activate)
pip install -r requirements.txt
```


### Ejecución con Makefile (AAA + RGR)

Este proyecto incluye un **Makefile** con atajos para el ciclo **Red-Green-Refactor** y tareas frecuentes:

- `make test` - Ejecuta todas las pruebas.
- `make cov` - Ejecuta pruebas con **coverage** y muestra un resumen.
- `make lint` - Analiza el código con **pylint**.
- `make rgr` - Atajo rápido para ejecutar pruebas durante el ciclo RGR.
- `make red` - Paso **Red**: verifica que exista al menos una prueba fallando (retorna código ≠ 0 si todo está en verde).
- `make green` - Paso **Green**: ejecuta las pruebas hasta que pasen (verde).
- `make refactor` - Paso **Refactor**: vuelve a ejecutar pruebas tras refactorizar (deben seguir en verde).

> Nota: `pytest.ini` ya configura la detección de pruebas, por lo que basta con usar los *targets* del Makefile.

#### Flujo recomendado (ciclo RGR)

1) **Red**: escribe una prueba nueva que falle.
```bash
make red || true
```

2) **Green**: implementa lo mínimo para pasar.
```bash
make green
```

3) **Refactor**: limpia el diseño sin romper lo verde.
```bash
make refactor
```

En cualquier momento, validación rápida:
```bash
make rgr
```

#### Cobertura y estilo

Cobertura mínima y reporte:
```bash
make cov
```

Estilo y *code smells*:
```bash
make lint
```


#### **Ejecutar las pruebas**

Para ejecutar las pruebas, asegúrate de tener `pytest` instalado y ejecuta el siguiente comando en tu terminal:

```bash
make test
```

Todas las pruebas deberían pasar, confirmando que la funcionalidad `ShoppingCart` funciona correctamente después de las cinco iteraciones del proceso RGR.


### **Uso de mocks y stubs**

Hemos incorporado el uso de **mocks** para simular el comportamiento de un servicio externo de procesamiento de pagos (`payment_gateway`). Esto se logra mediante la inyección de dependencias, donde el `payment_gateway` se pasa como un parámetro en `process_payment(payment_gateway)` (inyección por método). Esto permite que durante las pruebas, podamos sustituir el gateway real por un **mock**, evitando llamadas reales a servicios externos y permitiendo controlar sus comportamientos (como simular pagos exitosos o fallidos).

- **Mock**: Un objeto que simula el comportamiento de objetos reales de manera controlada. En este caso, `payment_gateway` es un mock que simula el método `process_payment`.

- **Stub**: Un objeto que proporciona respuestas predefinidas a llamadas realizadas durante las pruebas, sin lógica adicional. En este caso, `payment_gateway.process_payment.return_value = True` actúa como un stub.

#### **Inyección de dependencias**

La inyección de dependencias es un patrón de diseño que permite que una clase reciba sus dependencias desde el exterior en lugar de crearlas internamente. En este proyecto, `ShoppingCart` recibe `payment_gateway` por parámetro en `process_payment(payment_gateway)` (inyección por método), así puedes pasar mocks/stubs en pruebas. Esto facilita el uso de mocks durante las pruebas y mejora la modularidad y flexibilidad del código.

#### **Manejo de excepciones**

En el método `process_payment`, añadimos manejo de excepciones para capturar y propagar errores que puedan ocurrir durante el procesamiento del pago. Esto es importante para mantener la robustez del sistema y proporcionar retroalimentación adecuada en caso de fallos.

#### **Refactorización acumulativa**

Cada iteración del proceso RGR se basa en la anterior, permitiendo construir una clase `ShoppingCart` robusta y funcional paso a paso. Al integrar características avanzadas como la inyección de dependencias y el uso de mocks, aseguramos que el código sea fácilmente testeable y mantenible.

#### **Buenas prácticas en pruebas**

- **Pruebas unitarias**: Cada prueba se enfoca en una funcionalidad específica de la clase `ShoppingCart`.
  
- **Aislamiento**: Al utilizar mocks para el `payment_gateway`, aislamos las pruebas de la clase `ShoppingCart` de dependencias externas, asegurando que las pruebas sean fiables y rápidas.
  
- **Cobertura de casos de uso**: Además de probar los escenarios exitosos (`test_process_payment`), también cubrimos casos de fallo (`test_process_payment_failure`) para asegurar que el sistema maneje adecuadamente los errores.

### Ejercicios

#### Reglas generales

* **No cambies** `src/carrito.py`, `src/shopping_cart.py`, `src/factories.py`, `Makefile`, `pytest.ini` ni `requirements.txt`.
* Agrega solo nuevos archivos bajo `tests/` y carpetas `evidencias/` y `out/`.
* Usa el estilo **AAA** (coméntalo como `# Arrange`, `# Act`, `# Assert`).
* Ejecución base:

  ```bash
     pytest -q --maxfail=1 --disable-warnings --cov=src --cov-report=term-missing --cov-fail-under=90 --junitxml=out/junit.xml
     pytest --cov=src --cov-report=term-missing > out/coverage.txt
  ```
* Entrega en **evidencias**: `out/junit.xml`, `out/coverage.txt`, `evidencias/run.txt` (salidas), `evidencias/analisis.md` (3-5 líneas por ejercicio con tablas/notas).

#### El patrón AAA

#### A1. Descuentos parametrizados

Crea `tests/test_descuentos_parametrizados.py` con casos que verifiquen el total para descuentos 0 %, 1 %, 33.33 %, 50 %, 99.99 %, 100 %, sobre subtotales con y sin centavos. Redondea solo en los **asserts**. En `evidencias/analisis.md`, añade una tabla "entrada -> total esperado".

**Pistas:**

```python
# tests/test_descuentos_parametrizados.py
import pytest
from src.carrito import Carrito, ItemCarrito, Producto

@pytest.mark.parametrize(
    "precio,cantidad,descuento,esperado",
    [
        (10.00, 1, 0.00, 10.00),
        (10.00, 1, 0.01, 9.90),
        (10.01, 1, 0.3333, 6.67),  # ajusta 'esperado' si el contrato indica otro redondeo
        (100.00, 1, 0.5, 50.00),
        (1.00, 1, 0.9999, 0.00),
        (50.00, 1, 1.00, 0.00),
    ],
)
def test_descuento_total(precio, cantidad, descuento, esperado):
    # Arrange
    c = Carrito()
    c.agregar(ItemCarrito(Producto("p", precio), cantidad))
    c.aplicar_descuento(descuento)
    # Act
    total = c.total()
    # Assert
    assert round(total, 2) == pytest.approx(esperado, abs=0.01)
```

#### A2. Idempotencia de actualización de cantidades

Verifica que establecer varias veces la **misma** cantidad no cambia el total ni el número de ítems.

**Pistas:**

```python
# tests/test_idempotencia_cantidades.py
from src.carrito import Carrito, ItemCarrito, Producto

def test_actualizacion_idempotente():
    # Arrange
    c = Carrito()
    c.agregar(ItemCarrito(Producto("x", 3.25), 2))
    total1 = c.total()
    # Act
    for _ in range(5):
        c.actualizar_cantidad("x", 2)
    total2 = c.total()
    # Assert
    assert total1 == total2
    assert sum(i.cantidad for i in c.items) == 2
```

#### A3. Fronteras de precio y valores inválidos

Cubre precios frontera (`0.01`, `0.005`, `0.0049`, `9999999.99`) y precios no válidos (`0`, negativos). Si el comportamiento no está definido por el SUT, usa `xfail` con razón.

**Pistas:**

```python
# tests/test_precios_frontera.py
import pytest
from src.carrito import Carrito, ItemCarrito, Producto

@pytest.mark.parametrize("precio", [0.01, 0.005, 0.0049, 9999999.99])
def test_precios_frontera(precio):
    # Arrange
    c = Carrito()
    # Act
    c.agregar(ItemCarrito(Producto("p", precio), 1))
    # Assert
    assert c.total() >= 0  # ajusta si el contrato define otra cosa

@pytest.mark.xfail(reason="Contrato no definido para precio=0 o negativo")
@pytest.mark.parametrize("precio_invalido", [0.0, -1.0])
def test_precios_invalidos(precio_invalido):
    c = Carrito()
    c.agregar(ItemCarrito(Producto("p", precio_invalido), 1))
```

#### A4. Redondeos acumulados vs. final

Crea casos donde redondear por ítem difiere de redondear al final. Documenta en `evidencias/analisis.md` una mini-tabla "suma por ítem / redondeo final / diferencia".

**Pistas:**

```python
# tests/test_redondeo_acumulado.py
from src.carrito import Carrito, ItemCarrito, Producto

def test_redondeo_acumulado_vs_final():
    # Arrange
    c = Carrito()
    c.agregar(ItemCarrito(Producto("a", 0.3333), 3))
    c.agregar(ItemCarrito(Producto("b", 0.6667), 3))
    # Act
    total = c.total()
    suma_por_item = sum(i.producto.precio * i.cantidad for i in c.items)
    # Assert
    assert round(total, 2) == round(suma_por_item, 2)
```

#### RGR sin tocar el SUT

#### B1. Rojo (falla esperada)- precisión financiera

Escribe un test que **xfail** por precisión binaria con `float`. Copia el traceback a `evidencias/run.txt` y anota el impacto (2-3 líneas).

**Pistas:**

```python
# tests/test_rgr_precision_rojo.py
import pytest
from src.shopping_cart import ShoppingCart

@pytest.mark.xfail(reason="Float binario puede introducir error en dinero")
def test_total_precision_decimal():
    # Arrange
    cart = ShoppingCart()
    cart.add_item("x", 0.1); cart.add_item("x", 0.2)
    # Act / Assert
    assert cart.total() == 0.30  # 0.1 + 0.2 != 0.3 exactamente en binario
```

#### B2. Verde (exclusión documentada)

Convierte el test anterior a `skip` con una razón explícita (no se corrige en esta versión). Explica en `evidencias/analisis.md`.

**Pistas:**

```python
# tests/test_rgr_precision_verde.py
import pytest

@pytest.mark.skip(reason="Contrato: precisión binaria no se corrige en esta versión")
def test_total_precision_decimal_skip():
    # mismo setup del rojo; excluido para mantener el pipeline estable
    ...
```

#### B3. Refactor de suites

Reorganiza casos en dos clases: `TestPrecisionMonetaria` y `TestPasarelaPagoContratos` para legibilidad, sin duplicar lógica. Documenta la reorganización en `evidencias/analisis.md`.

**Pistas:**

```python
# tests/test_refactor_suites.py
import pytest
from unittest.mock import Mock
from src.shopping_cart import ShoppingCart


class TestPrecisionMonetaria:
    def test_suma_pequenas_cantidades(self):
        # Arrange
        cart = ShoppingCart()
        cart.add_item("x", 0.05)
        cart.add_item("x", 0.05)
        # Act
        total = cart.total()
        # Assert
        assert round(total, 2) == 0.10


class TestPasarelaPagoContratos:
    def test_pago_exitoso(self):
        # Arrange
        cart = ShoppingCart()
        cart.add_item("x", 10.0)
        pg = Mock()
        pg.charge.return_value = True
        # Act
        resultado = cart.process_payment(pg)
        # Assert
        assert resultado is True
        pg.charge.assert_called_once()

```
#### TDD + DevOps

#### C1. Contratos de pasarela de pago con `mock`

Cubre: pago exitoso (`True`), excepción transitoria (timeout) **sin reintento automático del SUT**, y rechazo definitivo (`False`). En `evidencias/analisis.md`, agrega tabla "evento -> expectativa".

**Pistas:**

```python
# tests/test_pasarela_pago_contratos.py
import pytest
from unittest.mock import Mock
from src.shopping_cart import ShoppingCart


def test_pago_exitoso():
    # Arrange
    cart = ShoppingCart()
    cart.add_item("x", 10.0)
    pg = Mock()
    pg.charge.return_value = True
    # Act
    resultado = cart.process_payment(pg)
    # Assert
    assert resultado is True
    pg.charge.assert_called_once()


def test_pago_timeout_sin_reintento_automatico():
    # Arrange
    cart = ShoppingCart()
    cart.add_item("x", 10.0)
    pg = Mock()
    pg.charge.side_effect = TimeoutError("timeout")
    # Act / Assert
    with pytest.raises(TimeoutError):
        cart.process_payment(pg)
    # El SUT no debe reintentar automáticamente
    assert pg.charge.call_count == 1

    # (Opcional) Reintento manual desde el test para documentar el contrato
    pg.charge.side_effect = None
    pg.charge.return_value = True
    assert pg.charge() is True  # reintento manual exitoso


def test_pago_rechazo_definitivo():
    # Arrange
    cart = ShoppingCart()
    cart.add_item("x", 10.0)
    pg = Mock()
    pg.charge.return_value = False
    # Act
    resultado = cart.process_payment(pg)
    # Assert
    assert resultado is False
    pg.charge.assert_called_once()

```

#### C2. Marcadores de humo y regresión

Marca tres pruebas críticas como `@pytest.mark.smoke` y la batería extendida como `@pytest.mark.regression`. Guarda ambas salidas en `evidencias/run.txt` y comenta su utilidad en CI.

**Pistas:**

```python
# tests/test_markers.py
import pytest
from src.carrito import Carrito, ItemCarrito, Producto

@pytest.mark.smoke
def test_smoke_agregar_y_total():
    c = Carrito(); c.agregar(ItemCarrito(Producto("x", 1.0), 1))
    assert c.total() == 1.0

@pytest.mark.regression
def test_regression_descuento_redondeo():
    c = Carrito()
    c.agregar(ItemCarrito(Producto("x", 10.0), 1))
    c.aplicar_descuento(0.15)
    assert round(c.total(), 2) == 8.50
```

Ejecución selectiva:

```bash
pytest -m smoke -q
pytest -m regression -q
```

#### C3. Umbral de cobertura como *quality gate*

Ejecuta con `--cov-fail-under=90`. Si falla, lista en `evidencias/analisis.md` las áreas a fortalecer y pega `term-missing` en `out/coverage.txt`.

**Pistas:**

```bash
pytest --cov=src --cov-report=term-missing --cov-fail-under=90 || true
```

#### C4. MREs para defectos

Para cada `xfail` o fallo real, adjunta un **Minimal Reproducible Example** (4-6 líneas) y documenta pasos y expectativa en `evidencias/analisis.md`.

**Pistas:**

```python
# tests/test_mre_precision.py
from src.shopping_cart import ShoppingCart

def test_mre_precision():
    c = ShoppingCart(); c.add_item("x", 0.1); c.add_item("x", 0.2)
    assert round(c.total(), 2) == 0.30  # documenta el síntoma
```

####  Observabilidad y estabilidad

#### D1. Estabilidad con datos aleatorios controlados

Fija semillas para `random` y `faker` y demuestra que dos corridas producen el mismo total. Registra ambas salidas en `evidencias/run.txt`.

**Pistas:**

```python
# tests/test_estabilidad_semillas.py
import random
from faker import Faker
from src.factories import ProductoFactory
from src.carrito import Carrito, ItemCarrito

def test_estabilidad_semillas(capsys):
    # 1- corrida
    random.seed(123)
    faker = Faker(); faker.seed_instance(123)
    p = ProductoFactory()
    c = Carrito(); c.agregar(ItemCarrito(p, 2))
    print(c.total())
    out1 = capsys.readouterr().out

    # 2- corrida (mismas semillas)
    random.seed(123)
    faker.seed_instance(123)
    p2 = ProductoFactory()
    c2 = Carrito(); c2.agregar(ItemCarrito(p2, 2))
    print(c2.total())
    out2 = capsys.readouterr().out

    assert out1 == out2
```

#### D2. Invariantes de inventario

Valida el invariante: "agregar N, remover N -> total=0 e items=0; agregar N, actualizar a 0 -> estado equivalente". Resume en `evidencias/analisis.md` por qué previene regresiones.

**Pistas:**

```python
# tests/test_invariantes_inventario.py
from src.carrito import Carrito, ItemCarrito, Producto

def test_invariante_agregar_remover_y_actualizar():
    # Arrange
    c = Carrito()
    c.agregar(ItemCarrito(Producto("x", 5.0), 3))
    t1 = c.total()
    # Act
    c.remover("x")
    c.agregar(ItemCarrito(Producto("x", 5.0), 3))
    c.actualizar_cantidad("x", 0)
    # Assert
    assert c.total() == 0.0
    assert sum(i.cantidad for i in c.items) == 0
    assert t1 == 15.0  # sanity check del estado inicial
```

#### D3. Contrato de mensajes de error

Valida que mensajes de excepción contengan contexto accionable (nombre de producto, cantidad inválida). Si el SUT no lo provee, marca `xfail` con el texto deseado y explícitalo en `evidencias/analisis.md`.

**Pistas:**

```python
# tests/test_mensajes_error.py
import pytest
from src.carrito import Carrito

@pytest.mark.xfail(reason="Esperamos mensaje con pista accionable")
def test_mensaje_error_contiene_contexto():
    c = Carrito()
    with pytest.raises(ValueError) as e:
        c.actualizar_cantidad("inexistente", 1)
    assert "inexistente" in str(e.value)
```
#### Contenido de evidencias en el repositorio

* **`evidencias/rgr.txt`**: salidas (con fecha/hora local) de:

  * `make red` (muestra **FAIL** y mensaje de aserción esperado),
  * `make green` (suite en verde),
  * `make refactor` (verde tras refactor),
  * `make rgr` (validación rápida).
* **`evidencias/diff_refactor.md`**: fragmentos antes/después con breve justificación (nombres, duplicación, responsabilidades, acoplamientos).
* **`evidencias/resumen_cobertura.md`**: reporte de `make cov` + módulos/ramas no cubiertos y plan breve para subir cobertura.
* **`evidencias/decisiones.md`**:

  * Contratos verificados por cada prueba (qué garantiza del carrito/pagos),
  * Variables y **efecto observable** (por ejemplo, `DISCOUNT_RATE`, `TAX_RATE`),
  * Casos borde considerados y dónde se prueban.

* Nuevos archivos de prueba dentro de `tests/` (no borres los existentes).
* `out/junit.xml`, `out/coverage.txt`.
* `evidencias/run.txt` y `evidencias/analisis.md` con tablas, MREs y comentarios breves.
