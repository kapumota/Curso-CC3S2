### Actividad 8: El patrón AAA-Red-Green-Refactor

El proyecto se desarrollará de forma incremental utilizando el proceso RGR (Red, Green, Refactor) y pruebas unitarias con pytest para asegurar la correcta implementación de cada funcionalidad.

#### El patrón Arrange-Act-Assert

El patrón **Arrange-Act-Assert (AAA)** organiza las pruebas unitarias en tres pasos claros: preparar el escenario (**Arrange**), ejecutar el comportamiento (**Act**) y verificar el resultado (**Assert**). Las pruebas son el primer uso real del código: lo invocan como en la aplicación, capturan resultados y validan expectativas, dando retroalimentación inmediata sobre diseño y usabilidad del API. Los nombres descriptivos de clases y métodos de prueba cuentan la "historia” del comportamiento esperado (p. ej., `TestUsername` y `test_converts_to_lowercase`).

Para que las pruebas sean realmente útiles, se aplican los principios **FIRST**:

* **F**ast: ejecución muy rápida para ciclos TDD cortos.
* **I**solated: independientes entre sí, sin dependencias de orden o estado.
* **R**epeatable: deterministas, sin factores externos (tiempo/red/red DB); se apoya en *stubs/mocks* cuando haga falta.
* **S**elf-verifying: automatizadas, reportan "aprobado/fallado” sin inspección manual.
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
│   └── shopping_cart.py
├── tests/
│   ├── __init__.py
│   └── test_shopping_cart.py
└── Evidencias/
    ├── rgr.txt
    ├── diff_refactor.md
    ├── resumen_cobertura.md
    └── decisiones.md

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
pytest test_shopping_cart.py
```

Todas las pruebas deberían pasar, confirmando que la funcionalidad `ShoppingCart` funciona correctamente después de las cinco iteraciones del proceso RGR.


### **Uso de mocks y stubs**

Hemos incorporamos el uso de **mocks** para simular el comportamiento de un servicio externo de procesamiento de pagos (`payment_gateway`). Esto se logra mediante la inyección de dependencias, donde el `payment_gateway` se pasa como un parámetro al constructor de `ShoppingCart`. Esto permite que durante las pruebas, podamos sustituir el gateway real por un **mock**, evitando llamadas reales a servicios externos y permitiendo controlar sus comportamientos (como simular pagos exitosos o fallidos).

- **Mock**: Un objeto que simula el comportamiento de objetos reales de manera controlada. En este caso, `payment_gateway` es un mock que simula el método `process_payment`.

- **Stub**: Un objeto que proporciona respuestas predefinidas a llamadas realizadas durante las pruebas, sin lógica adicional. En este caso, `payment_gateway.process_payment.return_value = True` actúa como un stub.

#### **Inyección de dependencias**

La inyección de dependencias es un patrón de diseño que permite que una clase reciba sus dependencias desde el exterior en lugar de crearlas internamente. En nuestro ejemplo, `ShoppingCart` recibe `payment_gateway` como un parámetro durante su inicialización. Esto facilita el uso de mocks durante las pruebas y mejora la modularidad y flexibilidad del código.

#### **Manejo de excepciones**

En el método `process_payment`, añadimos manejo de excepciones para capturar y propagar errores que puedan ocurrir durante el procesamiento del pago. Esto es importante para mantener la robustez del sistema y proporcionar retroalimentación adecuada en caso de fallos.

#### **Refactorización acumulativa**

Cada iteración del proceso RGR se basa en la anterior, permitiendo construir una clase `ShoppingCart` robusta y funcional paso a paso. Al integrar características avanzadas como la inyección de dependencias y el uso de mocks, aseguramos que el código sea fácilmente testeable y mantenible.

#### **Buenas prácticas en pruebas**

- **Pruebas unitarias**: Cada prueba se enfoca en una funcionalidad específica de la clase `ShoppingCart`.
  
- **Aislamiento**: Al utilizar mocks para el `payment_gateway`, aislamos las pruebas de la clase `ShoppingCart` de dependencias externas, asegurando que las pruebas sean fiables y rápidas.
  
- **Cobertura de casos de uso**: Además de probar los escenarios exitosos (`test_process_payment`), también cubrimos casos de fallo (`test_process_payment_failure`) para asegurar que el sistema maneje adecuadamente los errores.
#### Qué debes presentar

Para evidenciar **AAA (Arrange-Act-Assert)** y **RGR (Red-Green-Refactor)** con trazabilidad y reproducibilidad, el estudiante debe entregar:

1) **Repositorio y versión**
- URL del repositorio y la carpeta llamada Actividad8-CC3S2 y **hash del commit** evaluado.
- Instrucciones mínimas para reproducir: comandos usados (`python -m venv ...`, `pip install -r requirements.txt`, `make rgr`, etc.).

2) **Red-Green-Refactor documentado**
- **Red**: prueba nueva que falla. Adjuntar salida de `make red` (o `pytest`) mostrando al menos un **FAIL** y el **mensaje de aserción** esperado.
- **Green**: cambio mínimo para pasar. Adjuntar salida de `make green` con **tests en verde**.
- **Refactor**: limpieza del diseño sin cambiar comportamiento. Adjuntar salida de `make refactor` en verde y un **diff antes/después** (fragmentos relevantes).

3) **AAA en las pruebas**
- Señalar, por cada prueba creada o modificada, las secciones **Arrange**, **Act** y **Assert** (comentarios o docstring).
- Justificar brevemente **qué contrato** verifica cada aserción (qué garantiza del carrito o de los productos).

4) **Resultados automatizados**
- **Pruebas**: salida de `make test` (resumen de passed/failed/xfail, tiempo).
- **Cobertura**: salida de `make cov` y breve comentario de los **módulos no cubiertos** y planes de mejora.
- **Linter**: salida de `make lint` con observaciones relevantes y cómo se atendieron o justificaron.

5) **Diseño y decisiones**
- Explicar **qué deuda** técnica se redujo en el refactor (nombres, duplicación, acoplamientos, responsabilidades).
- Indicar **casos borde** contemplados (ej.: cantidades negativas, stocks, precios cero, cupones inválidos) y dónde se prueban.

6) **Evidencia ejecutable**
- Registrar una sesión corta del flujo (`make red -> make green -> make refactor -> make rgr`) en texto o captura.
- Incluir archivos generados si aplica (por ejemplo, `htmlcov/` comprimido) o referencias claras a cómo producirlos.

> Entregables sugeridos en el repositorio:
> - `Evidencias/rgr.txt` (salidas de comandos clave).
> - `Evidencias/diff_refactor.md` (antes/después con comentarios).
> - `Evidencias/resumen_cobertura.md` (breve análisis de gaps).
> - `Evidencias/decisiones.md` (justificación de diseño y casos borde).

#### Contenido de evidencias

* **`Evidencias/rgr.txt`**: salidas (con fecha/hora local) de:

  * `make red` (muestra **FAIL** y mensaje de aserción esperado),
  * `make green` (suite en verde),
  * `make refactor` (verde tras refactor),
  * `make rgr` (validación rápida).
* **`Evidencias/diff_refactor.md`**: fragmentos antes/después con breve justificación (nombres, duplicación, responsabilidades, acoplamientos).
* **`Evidencias/resumen_cobertura.md`**: reporte de `make cov` + módulos/ramas no cubiertos y plan breve para subir cobertura.
* **`Evidencias/decisiones.md`**:

  * Contratos verificados por cada prueba (qué garantiza del carrito/pagos),
  * Variables y **efecto observable** (p. ej., `DISCOUNT_RATE`, `TAX_RATE`),
  * Casos borde considerados y dónde se prueban.
