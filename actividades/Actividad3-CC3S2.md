### Actividad 3: Integración de DevOps y DevSecOps con HTTP, DNS, TLS y 12-Factor App

Esta actividad cierra la unidad cubriendo los temas de Introducción a DevOps (qué es y qué no es, del código a producción), el marco CALMS, automatización reproducible con 
Linux/Bash y Make, la visión cultural de DevOps (comunicación y colaboración) y su evolución a DevSecOps, así como los módulos de redes y arquitectura  (HTTP/DNS/TLS, puertos/procesos y metodología 12-Factor App). 

La actividad se divide en una parte teórica (reflexión conceptual)  y una parte práctica (ejercicios basados en el laboratorio proporcionado). 

**Instrucciones generales:**

* Realiza la actividad en tu repositorio personal del curso.
* Crea una carpeta llamada `Actividad3-CC3S2` y sube un archivo Markdown (`respuestas.md`) con tus respuestas teóricas, capturas de pantalla o salidas de comandos para la parte práctica, y cualquier archivo modificado o generado (sin incluir código fuente original).
* Incluye un PDF breve (máx. 4 páginas) con informe resumido, cuadro de evidencias y checklist de trazabilidad.
* Usa el laboratorio proporcionado (Makefile, app.py, configuraciones de Nginx, systemd, Netplan e Instrucciones.md).
* Los ejercicios deben ser retadores: incluye razonamiento, modificaciones y depuración donde aplique.
* Sube el repositorio actualizado antes de la fecha límite. En el README de la carpeta, agrega una tabla índice enlazando a evidencias.

#### Parte teórica

1. **Introducción a DevOps: ¿Qué es y qué no es?**
   Explica DevOps desde el código hasta la producción, diferenciándolo de waterfall. Discute "you build it, you run it" en el laboratorio, y separa mitos (ej. solo herramientas) vs realidades (CALMS, feedback, métricas, gates).

   * *Tip:* Piensa en ejemplos concretos: ¿cómo se vería un gate de calidad en tu Makefile?

2. **Marco CALMS en acción:**
   Describe cada pilar y su integración en el laboratorio (ej. Automation con Makefile, Measurement con endpoints de salud). Propón extender Sharing con runbooks/postmortems en equipo.

   * *Tip:* Relaciona cada letra de CALMS con un archivo del laboratorio.

3. **Visión cultural de DevOps y paso a DevSecOps:**
   Analiza colaboración para evitar silos, y evolución a DevSecOps (integrar seguridad como cabeceras TLS, escaneo dependencias en CI/CD).
   Propón escenario retador: fallo certificado y mitigación cultural. Señala 3 controles de seguridad sin contenedores y su lugar en CI/CD.

   * *Tip:* Usa el archivo de Nginx y systemd para justificar tus controles.

4. **Metodología 12-Factor App:**
   Elige 4 factores (incluye config por entorno, port binding, logs como flujos) y explica implementación en laboratorio.
   Reto: manejar la ausencia de estado (statelessness) con servicios de apoyo (backing services).

   * *Tip:* No solo describas: muestra dónde el laboratorio falla o podría mejorar.

#### Parte práctica

1. **Automatización reproducible con Make y Bash (Automation en CALMS).**
   Ejecuta Makefile para preparar, hosts-setup y correr la app. Agrega un target para verificar idempotencia HTTP (reintentos con curl).
   Explica cómo Lean minimiza fallos. Haz un rastreo: tabla "objetivo -> prepara/verifica -> evidencia" de Instrucciones.md.

   * *Tip:* Intenta romper el Makefile cambiando una variable y observa si sigue siendo reproducible.

2. **Del código a producción con 12-Factor (Build/Release/Run).**
   Modifica variables de entorno (`PORT`, `MESSAGE`, `RELEASE`) sin tocar código. Crea un artefacto inmutable con `git archive` y verifica paridad dev-prod.
   Documenta en tabla "variable -> efecto observable". Simula un fallo de backing service (puerto equivocado) y resuélvelo con disposability. Relaciona con logs y port binding.

   * *Tip:* Muestra cómo un log puede servir de "única fuente de verdad" en la depuración.

3. **HTTP como contrato observable.**
   Inspecciona cabeceras como ETag o HSTS. Define qué operaciones son seguras para reintentos. Implementa readiness y liveness simples, y mide latencias con curl.
   Documenta contrato mínimo (campos respuesta, trazabilidad en logs). Explica cómo definirías un **SLO**.

   * *Tip:* Piensa qué pasaría si tu endpoint principal no fuera idempotente.

4. **DNS y Caché en operación.**
   Configura IP estática en Netplan. Usa dig para observar TTL decreciente y getent local para resolución de `miapp.local`.
   Explica cómo opera sin zona pública, el camino stub/recursor/autoritativos y overrides locales. Diferencia respuestas cacheadas y autoritativas.

   * *Tip:* Haz dos consultas seguidas y compara TTL. ¿Qué cambia?.

5. **TLS y Seguridad en DevSecOps (Reverse Proxy).**
  
    Un **gate** (puerta/umbral de calidad) es una **verificación automática no negociable** en el flujo de CI/CD que **bloquea** el avance de un cambio si **no** se cumplen  criterios objetivos. 
    Sirve para **cumplir políticas** (seguridad, rendimiento, estilo, compatibilidad) antes de promover un artefacto a la siguiente etapa. 

   Ejemplos: "latencia P95 < 500 ms", "cobertura ≥ 90%", "TLS mínimo v1.3", "sin vulnerabilidades críticas".

    Genera certificados con Make y configura Nginx como proxy inverso. Verifica el **handshake TLS** con `openssl` y revisa las **cabeceras HTTP** con `curl`. 
    Explica la **terminación TLS** en el puerto **:443**, el **reenvío** de tráfico hacia `127.0.0.1:8080` y las **cabeceras de proxy** relevantes. Indica las **versiones de TLS permitidas** y justifica las diferencias entre el **entorno de laboratorio** y el **entorno de producción** (por ejemplo, compatibilidad vs. endurecimiento de seguridad). Comprueba la **redirección de HTTP a HTTPS** y la **presencia de HSTS** (recuerda: HSTS es una **cabecera HTTP**, no parte del handshake TLS).
    **Diseña un gate de CI/CD** (puerta de calidad) que **detenga el pipeline** cuando **no** se cumpla **TLS v1.3** como mínimo. Describe:

      - **Condición** (detectar versión TLS efectiva en el endpoint),
      - **Evidencia** (salida del comando que valida la versión), y
      - **Acción** (fallar el job con un código de salida ≠ 0 para evitar la promoción a la siguiente etapa).

7. **Puertos, Procesos y Firewall.**
    Usa ss/lsof para listar puertos/procesos de app y Nginx. Diferencia loopback de expuestos públicamente. Presenta una "foto" de conexiones activas y analiza patrones.
    Explica cómo restringirías el acceso al backend y qué test harías para confirmarlo. Integra systemd: instala el servicio, ajusta entorno seguro y prueba parada.
    Simula incidente (mata proceso) y revisa logs con journalctl.

   * *Tip:* Fíjate si el backend escucha en todas las interfaces o solo en loopback.

8. **Integración CI/CD**
   Diseña un script Bash que verifique HTTP, DNS, TLS y latencias antes del despliegue. Define umbrales (ej. latencia >0.5s falla).
   Ejecuta el script antes y después de una modificación (por ejemplo, cambio de puerto) y observa cómo se retroalimenta CALMS.

   * *Tip:* Piensa cómo este script podría integrarse en GitHub Actions.

9. **Escenario integrado y mapeo 12-Factor.**
   Modifica el endpoint para introducir un fallo no idempotente. Realiza un despliegue manual tipo blue/green (dos instancias) y documenta un postmortem con fallas, lecciones y prevención DevSecOps. Propón un runbook breve. Completa una tabla con 6 factores: principio, implementación en el laboratorio, evidencia y mejora hacia producción.

   * *Tip:* Usa este ejercicio para mostrar tu capacidad de análisis cultural, no solo técnico.
