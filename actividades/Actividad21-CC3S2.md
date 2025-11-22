### Actividad 21: Pipeline DevSecOps local-first con GitHub Actions, Docker y Kubernetes

#### Contexto general

Partiendo del código base entregado en el repositorio de apoyo: (microservicio HTTP con `/` y `/health`, Dockerfile, Docker Compose, manifiestos de Kubernetes, Makefile y workflow de automatización)

1. Crear un **repositorio personal** con ese código como punto de partida.
2. Adaptar y extender el pipeline de automatización, manteniendo el enfoque **local-first** (sin secretos reales ni registries externos obligatorios).
3. Integrar comprobaciones de calidad, seguridad, empaquetado con contenedores y preparación para despliegue en Kubernetes.
4. Documentar lo realizado en el README de tu repositorio.


> Repositorio de apoyo: `https://github.com/kapumota/Github-actions-devops`

#### Ejercicio 1 - Preparación del repositorio personal

**Instrucciones**

1. Crea un nuevo repositorio en tu cuenta personal de GitHub.
2. Copia todo el contenido del proyecto base (`Github-actions-devops`) a tu nuevo repositorio, preservando la estructura:

   * `src/`, `tests/`, `docker/`, `k8s/`, `.github/workflows/`, `Makefile`, etc.
3. Actualiza el `README.md`:

   * Cambia el título para que incluya tu nombre y tu código de alumno.
   * Agrega una sección "Objetivo del laboratorio" donde expliques en 5-8 líneas qué hace el proyecto y cuál es el flujo general (código -> contenedor -> pipeline de automatización -> despliegue).

**Entrega mínima**

* Repositorio personal en GitHub con:

  * Estructura completa del proyecto.
  * `README.md` personalizado.


#### Ejercicio 2 - Workflow de automatización básico

**Instrucciones**

1. Revisa el archivo `.github/workflows/ci-devsecops.yml` del proyecto.
2. Asegúrate de que tu workflow:

   * Se ejecute cuando haya *push* y *pull requests* a la rama principal.
   * Pueda ejecutarse manualmente desde la interfaz de GitHub.
3. Dentro del job principal:

   * Debe existir un paso que instale dependencias de desarrollo desde `requirements-dev.txt`.
   * Debe existir al menos un paso que construya la imagen del microservicio usando el `Dockerfile` del directorio `docker/`.
   * Debe existir un paso que ejecute las pruebas unitarias.

**Extensión obligatoria**

* Agrega un *step* inicial de "saludo del pipeline" que:

  * Imprima en el log el nombre del repositorio y la rama que se está construyendo usando variables que proporciona el sistema (sin escribir valores fijos).

**Entrega mínima**

* Archivo `.github/workflows/ci-devsecops.yml` funcionando.
* Al menos una ejecución exitosa visible en la pestaña **Actions**.

#### Ejercicio 3 - Análisis estático y dependencias

**Instrucciones**

1. Verifica que en `requirements-dev.txt` estén las herramientas de análisis y pruebas.
2. Asegúrate de que el workflow tenga pasos separados para:

   * Análisis de código fuente.
   * Análisis de dependencias del archivo de requerimientos.
3. Ajusta las rutas de salida para que todos los reportes se guarden dentro del directorio `artifacts/`, con nombres claros (por ejemplo, `bandit.json`, `semgrep.json`, `pip-audit.json`).

**Extensión obligatoria**

* Modifica la configuración de la herramienta de análisis estático incluida en el proyecto para que, como mínimo, tenga una regla explícita que prohíba el uso de `eval` o `exec` en el código Python.

**Entrega mínima**

* Reportes generados en `artifacts/` por cada ejecución del workflow.
* Configuración de reglas estáticas actualizada en el archivo correspondiente.

#### Ejercicio 4 - Imágenes de contenedor y revisión de seguridad

**Instrucciones**

1. Revisa el `Dockerfile` no-root del directorio `docker/`.
2. Asegúrate de que el workflow:

   * Construya la imagen con un nombre que utilice variables definidas en el pipeline o en el Makefile.
   * Genere una descripción de componentes de la imagen y/o del proyecto en formato JSON almacenada en `artifacts/`.
   * Ejecute un escaneo de vulnerabilidades sobre la imagen recién construida y guarde su salida en `artifacts/` (por ejemplo, en formato SARIF).

**Extensión obligatoria**

* Agrega al `Dockerfile` al menos una etiqueta de metadatos (label) que incluya tu usuario de GitHub y una breve descripción del servicio.
* Documenta en el `README.md` qué herramientas se usan para describir y analizar la imagen, y en qué archivos se encuentran los resultados.

**Entrega mínima**

* Imagen construida durante la ejecución del workflow.
* Archivo(s) de descripción y escaneo de la imagen guardados en `artifacts/`.
* `Dockerfile` actualizado con la etiqueta añadida.

#### Ejercicio 5 - Servicio HTTP, Docker Compose y pruebas de humo (smoke test)

**Instrucciones**

1. Revisa el microservicio definido en `src/app.py`, especialmente las rutas `/` y `/health`.
2. Revisa el archivo `compose.yaml` y cómo levanta el servicio.
3. Asegúrate de que el workflow:

   * Levante el servicio usando Docker Compose en segundo plano.
   * Espere el tiempo necesario y consulte el endpoint `/health` con una herramienta de línea de comandos para verificar que el servicio responde.
   * Detenga y elimine los contenedores creados al final del job, incluso si alguna verificación falla.

**Extensión obligatoria**

* Haz visible en el log de la pipeline la respuesta en JSON devuelta por `/health`.
* Agrega al menos una prueba unitaria en `tests/` que verifique una parte del comportamiento del servicio (por ejemplo, el código de estado o alguna clave del JSON esperado), y asegúrate de que se ejecute dentro del workflow.

**Entrega mínima**

* Workflow que levanta el servicio con Compose, realiza *smoke test* a `/health` y baja los contenedores.
* Al menos una prueba unitaria adicional creada.


#### Ejercicio 6 - Manifiestos de orquestación y endpoint de salud

**Instrucciones**

1. Revisa el manifiesto de despliegue en `k8s/deployment.yaml` y el servicio en `k8s/service.yaml` (si existe; de lo contrario, crea uno con el mismo puerto que el microservicio).
2. Usa el endpoint `/health` del microservicio para definir sondas de vida y de disponibilidad dentro del manifiesto de despliegue.
3. Ajusta los tiempos y rutas de las sondas para que tengan sentido con el comportamiento del servicio.

**Extensión obligatoria**

* Documenta brevemente en el `README.md` cómo se usarían estos manifiestos junto con una herramienta de orquestación local (por ejemplo, un clúster local) para probar despliegues del microservicio en contenedores.

**Entrega mínima**

* Manifiesto(s) de Kubernetes actualizados con sondas de salud basadas en `/health`.
* Explicación breve en el `README.md` sobre cómo se relaciona el endpoint de salud con el orquestador.

**Nota:**
Por "sondas de vida y de disponibilidad" se hace referencia a las comprobaciones que realiza el orquestador sobre el contenedor, normalmente llamadas *liveness* y *readiness probes* en Kubernetes.

* La **sonda de vida** sirve para detectar si el contenedor sigue "vivo" o se ha quedado colgado; si falla muchas veces, el orquestador suele reiniciarlo.
* La **sonda de disponibilidad** indica cuándo el servicio está listo para recibir tráfico (por ejemplo, después de arrancar y cargar dependencias).
  En ambos casos se suele reutilizar el endpoint `/health` para que el orquestador pueda decidir si un pod está sano o no.


#### Ejercicio 7 - Automatización local-first y empaquetado de evidencias

**Instrucciones**

1. Revisa el `Makefile` del proyecto y los comandos disponibles.
2. Asegúrate de que exista un objetivo que ejecute de forma encadenada las fases principales del pipeline (construcción, pruebas, análisis, empaquetado de evidencias).
3. Verifica que exista un objetivo que empaquete los reportes y otros archivos de evidencia en un archivo comprimido con marca de tiempo dentro de `artifacts/`.

**Extensión obligatoria**

* Ejecuta el pipeline completo en tu máquina local (sin usar GitHub Actions) y genera al menos un archivo comprimido de evidencias.
* Describe en el `README.md` cómo se pueden reproducir localmente los pasos más importantes del pipeline usando comandos del `Makefile`.

**Entrega mínima**

* `Makefile` funcional, con un pipeline encadenado y empaquetado de evidencias.
* Al menos un archivo comprimido de evidencias generado localmente.


#### Ejercicio 8 - Control de cambios y revisión colaborativa

**Instrucciones**

1. Agrega un archivo de configuración de propietarios de código en la raíz del repo para definir:

   * Quién es responsable de revisar cambios en `src/` y `tests/`.
   * Quién revisa cambios en `.github/` y archivos de configuración relacionados con automatización y seguridad.
2. Configura reglas en el repositorio (o documéntalas) para exigir revisiones antes de hacer *merge* en la rama principal.

**Extensión obligatoria**

* En el `README.md`, explica en 4-6 líneas cómo este archivo y las reglas de protección de rama ayudan a garantizar que al menos dos pares de ojos revisen los cambios antes de que lleguen a la rama principal.

**Entrega mínima**

* Archivo de propietarios de código en el repo.
* Descripción textual sobre cómo se protegería la rama principal usando este archivo y las reglas de revisión.

**Nota:**
La expresión "al menos dos pares de ojos" significa que ninguna persona debería poder fusionar sus propios cambios directamente sin que otra persona los revise. En la práctica, el archivo de propietarios de código y las reglas de protección de rama obligan a que haya revisiones y aprobaciones antes del *merge*, de modo que siempre participen al menos dos personas distintas en los cambios que llegan a la rama principal.


#### Ejercicio 9 - Optimización y rendimiento del pipeline

**Instrucciones**

1. Agrega a tu workflow un mecanismo de caché para acelerar la instalación de dependencias de Python.
2. Asegúrate de que el cache se invalide cuando cambien las dependencias.
3. Define un grupo de concurrencia que evite que se ejecuten en paralelo múltiples versiones del pipeline para la misma rama, cancelando ejecuciones antiguas si se dispara una nueva.

**Extensión obligatoria**

* Ejecuta el workflow varias veces y observa la diferencia de tiempo entre una ejecución "fría" y otra que reutiliza la caché.
* Agrega una breve sección en el `README.md` donde comentes en 3-4 líneas qué mejoras de rendimiento observaste y qué trade-offs ves en esta configuración.

**Entrega mínima**

* Workflow actualizado con caché de dependencias y grupo de concurrencia.
* Comentarios en el `README.md` sobre las observaciones de rendimiento.

**Nota:**
Una "ejecución fría" es una corrida del workflow en la que todavía no existe caché disponible, por lo que hay que descargar e instalar todas las dependencias desde cero y suele tardar más. Cuando el caché ya fue creado y se reutiliza en corridas posteriores, el pipeline es más rápido porque aprovecha esos datos ya almacenados. La comparación entre ejecuciones frías y ejecuciones con caché permite medir el impacto real de la optimización.


#### Forma de entrega

Para la entrega se requiere:

1. Contar con un **repositorio personal público** con:

   * Código base adaptado.
   * Todos los archivos mencionados en los ejercicios.
   * `README.md` actualizado con las explicaciones solicitadas.
2. Presentar:

   * URL del repositorio.
   * Capturas o enlaces a ejecuciones relevantes de la pestaña **Actions** donde se observe el pipeline corriendo.
   * Evidencias generadas (reportes, SBOMs, empaquetados, etc.) dentro de `artifacts/`.

