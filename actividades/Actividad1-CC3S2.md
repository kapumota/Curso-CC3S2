### Actividad 1: introducción devops, devsecops 

> **Importante:** Esta actividad es **individual**, domiciliaria y de **reforzamiento**. No debes pegar código ni comandos.
> Tu evaluación se centrará en la comprensión conceptual, la calidad de la evidencia práctica (capturas con campos destacados) y la capacidad de proponer umbrales y criterios verificables.

> Utiliza herramientas gratuitas (como draw.io o Excalidraw) para quienes no tienen experiencia en diseño de diagramas.

#### 1) ¿Qué debes **entregar** exactamente?

1. En tu **repositorio personal del curso**, crea una **carpeta** llamada **`Actividad1-CC3S2`** (si tu entorno tiene problemas con espacios, acepta `Actividad_1`, pero mantén el nombre visible como "Actividad 1" en el README).
3. Dentro de esa carpeta, incluye:

   * Un único archivo **`README.md`** (en **Markdown**) con todo el desarrollo.
   * Un subdirectorio **`imagenes/`** con tus capturas de pantalla y diagramas.
   * Un archivo **`FUENTES.md`** con las referencias consultadas (mínimo 2 fuentes de calidad).
4. En el **`README.md`** coloca, al inicio:

   * Título de la actividad y tu nombre.
   * Fecha y **tiempo total invertido** (hh\:mm).
   * Un párrafo breve con el **contexto del entorno** que usaste (sin datos sensibles).
5. **Commits recomendados** (para trazabilidad académica):

   * Un commit inicial "Estructura de actividad 1".
   * Uno o más commits intermedios ("Evidencias HTTP/DNS/TLS", "Estrategias de despliegue", etc.).
   * Un commit final "Entrega actividad 1".
6. **No subas** binarios innecesarios, ni información confidencial (tokens, cookies, IPs privadas sin anonimizar).


#### 2) Reglas y **prohibiciones**

* **No pegues** comandos, scripts ni bloques de configuración. Describe **qué hiciste** (herramienta genérica), **qué observaste** y **qué concluyes**.
* **No** incluyas credenciales, tokens, cookies ni datos sensibles. Si una captura los muestra, **censúralos**.
* Las respuestas conceptuales deben ser **precisas**, con **umbrales numéricos** cuando hables de gates o KPIs.
* Todas las capturas deben estar en `imagenes/` y referenciadas desde el README con un texto que explique **por qué** esa captura es relevante.

#### 3) Objetivos de aprendizaje

Al finalizar, deberías poder:

* Diferenciar cascada tradicional vs DevOps con **trade-offs** verificables.
* Definir y justificar **gates** de seguridad (DevSecOps) con umbrales medibles y políticas de excepción con caducidad.
* Recolectar **evidencia operativa** mínima (HTTP, DNS, TLS, puertos) sin exponer secretos, y vincularla con decisiones de despliegue.
* Aplicar principios **12-Factor** (configuración por entorno, logs como flujo, port binding) para lograr despliegues reproducibles.
* Documentar hallazgos en **Markdown** con claridad, síntesis e interpretación.

#### 4) Contenido que debes desarrollar en tu `README.md`

> El desarrollo total (sin contar imágenes) debe ser **sustantivo**: apunta a una explicación completa y concreta. No repitas definiciones "de memoria"; aterriza conceptos con **evidencia** y **criterios**.

#### 4.1 DevOps vs. cascada tradicional (investigación + comparación)

* Agrega una **imagen comparativa** en `imagenes/devops-vs-cascada.png`. Puede ser un diagrama propio sencillo.
* Explica por qué DevOps acelera y reduce riesgo en software para la nube frente a cascada (feedback continuo, pequeños lotes, automatización).
* **Pregunta retadora:** señala un **contexto real** donde un enfoque cercano a cascada sigue siendo razonable (por ejemplo, sistemas con certificaciones regulatorias estrictas o fuerte acoplamiento hardware). Expón **dos criterios verificables** y **los trade-offs** (velocidad vs. conformidad/seguridad).

**Qué se validará:** que tu imagen muestre ciclos de feedback y no solo "cajas",  que cites al menos una fuente seria.


#### 4.2 Ciclo tradicional de dos pasos y silos (limitaciones y anti-patrones)

* Inserta una imagen de **silos organizacionales** en `imagenes/silos-equipos.png` (o un dibujo propio).
* Identifica **dos limitaciones** del ciclo "construcción -> operación" sin integración continua (por ejemplo, grandes lotes, colas de defectos).
* **Pregunta retadora:** define **dos anti-patrones** ("throw over the wall", seguridad como auditoría tardía) y explica **cómo** agravan incidentes (mayor MTTR, retrabajos, degradaciones repetitivas).

**Señal de investigación genuina:** usas términos como handoff, costo de integración tardía, asimetrías de información y los explicas con tus palabras.

#### 4.3 Principios y beneficios de DevOps (CI/CD, automatización, colaboración; Agile como precursor)

* Describe CI y CD destacando **tamaño de cambios**, **pruebas automatizadas cercanas al código** y **colaboración**.
* Explica cómo **una práctica Agile** (reuniones diarias, retrospectivas) alimenta decisiones del pipeline (qué se promueve, qué se bloquea).
* Propón **un indicador observable** (no financiero) para medir mejora de colaboración Dev-Ops (por ejemplo, tiempo desde PR listo hasta despliegue en entorno de pruebas; proporción de rollbacks sin downtime).

**Validez:** explica **cómo** recolectarías ese indicador sin herramientas pagas (bitácoras, metadatos de PRs, registros de despliegue).

#### 4.4 Evolución a DevSecOps (seguridad desde el inicio: SAST/DAST; cambio cultural)

* Diferencia **SAST** (estático, temprano) y **DAST** (dinámico, en ejecución), y ubícalos en el pipeline.
* Define un **gate mínimo de seguridad** con **dos umbrales cuantitativos** (por ejemplo, "cualquier hallazgo crítico en componentes expuestos **bloquea** la promoción"; "cobertura mínima de pruebas de seguridad del **X%**").
* Incluye una **política de excepción** con **caducidad**, responsable y plan de corrección.
* **Pregunta retadora:** ¿cómo evitar el "teatro de seguridad" (cumplir checklist sin reducir riesgo)? Propón **dos señales de eficacia** (disminución de hallazgos repetidos; reducción en tiempo de remediación) y **cómo** medirlas.

**Validación:** que los umbrales sean **concretos** y la excepción tenga fecha límite y dueño.

#### 4.5 CI/CD y estrategias de despliegue (sandbox, canary, azul/verde)

* Inserta una imagen del pipeline o canary en `imagenes/pipeline_canary.png`.
* Elige **una estrategia** para un microservicio crítico (por ejemplo, autenticación) y justifica.
* Crea una **tabla breve** de **riesgos vs. mitigaciones** (al menos tres filas), por ejemplo:

  * Regresión funcional -> validación de contrato antes de promover.
  * Costo operativo del doble despliegue -> límites de tiempo de convivencia.
  * Manejo de sesiones -> "draining" y compatibilidad de esquemas.
* Define un **KPI primario** (p. ej., error 5xx, latencia p95) y un **umbral numérico** con **ventana de observación** para **promoción/abortado**.
* **Pregunta retadora:** si el KPI técnico se mantiene, pero cae una métrica de producto (conversión), explica por qué **ambos tipos de métricas** deben coexistir en el gate.

**Revisión:** el KPI tiene número y ventana; la tabla muestra comprensión del impacto en usuarios.

#### 4.6 Fundamentos prácticos sin comandos (evidencia mínima)

Realiza comprobaciones **con herramientas estándar**, pero **no** pegues los comandos. En el README escribe los **hallazgos** y la **interpretación**. Adjunta tus capturas en `imagenes/` y **marca** los campos relevantes (códigos, cabeceras, TTL, CN/SAN, fechas, puertos).

1. **HTTP - contrato observable**

   * Reporta: **método**, **código de estado** y **dos cabeceras** clave (por ejemplo, una de control de caché y otra de traza/diagnóstico).
   * Explica por qué esas cabeceras influyen en **rendimiento**, **caché** u **observabilidad**.
   * **Captura:** `imagenes/http-evidencia.png`, con los campos resaltados.

2. **DNS - nombres y TTL**

   * Reporta: **tipo de registro** (A o CNAME) y **TTL** de un dominio.
   * Explica cómo el **TTL** afecta **rollbacks** y cambios de IP (propagación, ventanas de inconsistencia).
   * **Captura:** `imagenes/dns-ttl.png`, con el TTL destacado.

3. **TLS - seguridad en tránsito**

   * Reporta: **CN/SAN**, **vigencia (desde/hasta)** y **emisora** del certificado de un sitio seguro.
   * Explica qué sucede si **no valida** la cadena (errores de confianza, riesgo de MITM, impacto en UX).
   * **Captura:** `imagenes/tls-cert.png`, con CN/SAN, emisora y fechas.

4. **Puertos - estado de runtime**

   * Enumera **dos puertos en escucha** en tu máquina o entorno y **qué servicios** sugieren.
   * Explica cómo esta evidencia ayuda a detectar **despliegues incompletos** (puerto no expuesto) o **conflictos** (puerto ocupado).
   * **Captura:** `imagenes/puertos.png`, con los puertos resaltados.

5. **12-Factor - port binding, configuración, logs**

   * Describe **cómo** parametrizarías el puerto sin tocar código (config externa).
   * Indica **dónde** verías los logs en ejecución (flujo estándar) y **por qué** no deberías escribirlos en archivos locales rotados a mano.
   * Señala un **anti-patrón** (p. ej., credenciales en el código) y su impacto en reproducibilidad.

6. **Checklist de diagnóstico (incidente simulado)**

   * **Escenario:** usuarios reportan intermitencia. Formula un checklist de **seis pasos ordenados** que permita discriminar:
     a) contrato HTTP roto, b) resolución DNS inconsistente, c) certificado TLS caducado/incorrecto, d) puerto mal configurado/no expuesto.
   * Para cada paso, indica: **objetivo**, **evidencia esperada**, **interpretación** y **acción siguiente**.
   * Evita generalidades; sé **operacional** (si X ocurre, entonces Y decisión).


#### 4.7 Desafíos de DevOps y mitigaciones

* Inserta un diagrama propio o ilustración en `imagenes/desafios_devops.png` con **tres desafíos** anotados (culturales, técnicos, de gobernanza).
* Enumera **tres riesgos** con su **mitigación concreta** (rollback, despliegues graduales, revisión cruzada, límites de "blast radius").
* Diseña un **experimento controlado** para validar que el despliegue gradual reduce riesgo frente a uno "big-bang": define **métrica primaria**, **grupo control**, **criterio de éxito** y **plan de reversión**.

#### 4.8 Arquitectura mínima para DevSecOps (HTTP/DNS/TLS + 12-Factor)

* Dibuja un **diagrama propio** en `imagenes/arquitectura-minima.png` con el flujo: **Cliente -> DNS -> Servicio (HTTP) -> TLS**, e indica **dónde** aplicar controles (políticas de caché, validación de certificados, contratos de API, límites de tasa).
* Explica cómo cada capa contribuye a **despliegues seguros y reproducibles**.
* Relaciona **dos principios 12-Factor** (config por entorno; logs a stdout) con **evidencias operativas** que un docente podría revisar (por ejemplo, diffs mínimos entre entornos, trazabilidad de logs).


#### 5) Evidencias que **deben aparecer** en tu README

* Capturas con **marcas visuales** (flechas, recuadros) sobre:

  * Código de estado y **dos cabeceras** HTTP.
  * **TTL** del dominio y tipo de registro (A/CNAME).
  * **CN/SAN**, **vigencia** y **emisora** del certificado.
  * **Puertos** en escucha (con indicios del proceso/servicio).
* Menciones explícitas de **umbrales** y **ventanas de observación** para tus gates y estrategia de despliegue.
* Un **checklist de incidente** que permita tomar decisiones (promover, observar, revertir).
* Un **diagrama** de arquitectura con ubicación de **controles** y **evidencias**.


#### 6) Sugerencia de **gestión del tiempo** (3 días, \~3 h en total)

**Día 1 (≈60–70 min) - Investigación y comparativos**

* **Lectura guiada (25–30 min):** revisa 1–2 fuentes serias sobre DevOps/DevSecOps, CI/CD y Agile. Toma notas breves con definiciones operativas (evita definiciones vagas).
* **Desarrollo (25–30 min):** redacta 4.1 (DevOps vs cascada), 4.2 (silos y anti-patrones) y 4.3 (principios y beneficios). Incluye **trade-offs verificables** y un **indicador observable** (no financiero) con cómo lo medirías.
* **Imágenes (10 min):** crea/selecciona y guarda en `imagenes/`

  * `devops-vs-cascada.png` (muestra feedback continuo)
  * `silos-equipos.png` (silos y handoffs)
* **Trazabilidad:** commit "Día 1-Comparativos e imágenes base".

**Día 2 (≈60–70 min)-Seguridad y despliegue**

* **DevSecOps (25–30 min):** redacta 4.4 con **SAST vs DAST** y define un **gate mínimo** con **umbrales numéricos** (severidad, cobertura, caducidad de excepciones y responsable).
* **Estrategia CI/CD (25–30 min):** redacta 4.5 eligiendo **una** (sandbox, canary, azul/verde). Construye una **tabla de riesgos vs mitigaciones** (≥3 filas) y fija **KPI + umbral + ventana** para promoción/rollback.
* **Imagen (10 min):** agrega `pipeline_canary.png` (pipeline o canary) en `imagenes/`.
* **Trazabilidad:** commit "Día 2-DevSecOps y estrategia de despliegue".

**Día 3 (≈60–80 min)-Evidencia práctica y cierre**

* **Comprobaciones prácticas (35–45 min):** realiza hallazgos para 4.6 sin pegar comandos:

  * HTTP (método, código y 2 cabeceras) -> `http-evidencia.png`
  * DNS (tipo y TTL) -> `dns-ttl.png`
  * TLS (CN/SAN, vigencia, emisora) -> `tls-cert.png`
  * Puertos (2 en escucha + interpretación) -> `puertos.png`
  * 12-Factor (port binding, config externa, logs) -> redacción breve
  * **Checklist de incidente (6 pasos)** con **evidencia esperada** y **acción**
* **Desafíos y arquitectura (15–20 min):** 4.7 (riesgos y mitigaciones + `desafios_devops.png`) y 4.8 (diagrama `arquitectura-minima.png` con ubicación de controles).
* **Cierre (10–15 min):** completa **tabla de evidencias**, revisa coherencia entre hallazgos y decisiones (umbrales), agrega **FUENTES.md** (≥2).
* **Trazabilidad:** commit "Día 3-Evidencia, diagramas y entrega final".

**Consejos rápidos**

* Si anticipas problemas para las capturas del día 3, adelanta **al menos** DNS/TLS en el día 2.
* Mantén cada respuesta conceptual en ≤ 160 palabras, con **criterios numéricos** cuando hables de gates/KPIs.
* Verifica que cada imagen tenga **marcas visuales** (recuadros/flechas) en los campos que mencionas en el texto.

#### 7) Integridad académica y defensa breve

* Redacta con tus propias palabras; si usas material externo, **cítalo** en `FUENTES.md`.
* Prepárate para una **defensa oral breve**: el docente puede pedirte que expliques por qué el **umbral** que propusiste es apropiado, o cómo interpretarías una caída en conversión aunque la latencia técnica mejore.

#### 8) Lista de archivos esperados en tu repositorio

```
/Actividad1-CC3S2/
  README.md
  FUENTES.md
  /imagenes/
     devops-vs-cascada.png
     silos-equipos.png
     http-evidencia.png
     pipeline_canary.png
     desafios_devops.png
     dns-ttl.png
     tls-cert.png
     puertos.png
     arquitectura-minima.png
```

### Adicional

#### 1. Umbrales para gates de seguridad (SAST/DAST)

- **Umbral 1: Número de vulnerabilidades críticas en SAST**
  - **Valor**: 0 vulnerabilidades críticas o de alta severidad (CVSS ≥ 7.0) detectadas por análisis estático antes de la promoción a producción.
  - **Justificación**: Vulnerabilidades críticas (por ejemplo, inyecciones SQL) representan riesgos graves. Un umbral de 0 evita despliegues inseguros.
  - **Cómo medir**: Revisar informe de herramienta SAST (sin especificar configuración) filtrando hallazgos por severidad crítica o alta.
  - **Ejemplo en README**: "Gate SAST: 0 vulnerabilidades críticas (CVSS ≥ 7.0). Evidencia: informe con 0 hallazgos críticos."

- **Umbral 2: Cobertura mínima de pruebas de seguridad (DAST)**
  - **Valor**: ≥ 80% de cobertura de pruebas dinámicas en rutas críticas de la API/aplicación (por ejemplo, autenticación, pagos).
  - **Justificación**: Un 80% cubre la mayoría de funcionalidades críticas, reduciendo riesgos como XSS. No se exige 100% por rutas no críticas.
  - **Cómo medir**: Verificar informe DAST para el porcentaje de endpoints probados frente al total definido en el contrato de API.
  - **Ejemplo en README**: "Gate DAST: ≥ 80% cobertura en rutas críticas. Evidencia: informe DAST con 85% de endpoints probados."

- **Política de excepción**:
  - **Ejemplo**: "Vulnerabilidad crítica no corregible: excepción por 7 días, asignada al líder técnico. Plan: aplicar parche o mitigación (por ejemplo, WAF) y reevaluar en DAST. Caducidad: 7 días."
  - **Justificación**: Limita la excepción en tiempo, asigna responsable y define corrección.

- **Evitar el "teatro de seguridad"**:
  - **Señal de eficacia 1**: Reducción de hallazgos repetidos en SAST/DAST (métrica: ≤ 5% de vulnerabilidades recurrentes).
    - **Cómo medir**: Comparar informes de SAST/DAST entre despliegues consecutivos.
  - **Señal de eficacia 2**: Tiempo de remediación de vulnerabilidades críticas ≤ 48 horas.
    - **Cómo medir**: Registrar detección (en pipeline) y corrección (commit o nuevo escaneo).

#### 2. Umbrales para KPIs de despliegue (sección 4.5)

- **KPI primario**: Tasa de errores HTTP 5xx ≤ 0.1% en una ventana de observación de 1 hora post-despliegue.
  - **Justificación**: Errores 5xx indican fallos graves (por ejemplo, código roto). Un umbral bajo asegura estabilidad; la ventana de 1 hora detecta problemas inmediatos.
  - **Cómo medir**: Revisar métricas de balanceador de carga o servidor web para proporción de respuestas 5xx.
  - **Ejemplo en README**: "KPI: Tasa de errores 5xx ≤ 0.1% en 1 hora. Evidencia: captura con 0.05% de errores 5xx en entorno canary."

- **Métrica de producto coexistente**: Tasa de conversión (por ejemplo, registros completados) ≥ 95% del valor pre-despliegue.
  - **Justificación**: Una caída en métricas de negocio indica problemas funcionales o de UX, complementando KPIs técnicos.
  - **Cómo medir**: Comparar eventos de usuarios (por ejemplo, clics en "registrarse") antes y después del despliegue.

#### 3. Alcance de "herramientas estándar" para comprobaciones prácticas

**Definición**: Herramientas estándar son gratuitas, nativas o ampliamente disponibles en sistemas operativos (Windows, Linux, macOS) o navegadores, sin configuraciones complejas ni licencias. Ejemplos:
- **Navegadores**: Chrome, Firefox, Edge (inspector de red, visor de certificados).
- **Línea de comandos nativa**: `dig` o `nslookup` (DNS), `netstat` o `ss` (puertos), `curl` (HTTP).
- **Interfaz gráfica**: Paneles de red o administradores de tareas del sistema.
- **Entornos de desarrollo**: Cliente HTTP de Postman (gratuito) o funciones de inspección en VS Code.
- **Restricción**: Evitar herramientas pagas (por ejemplo, Splunk) o entornos personalizados con credenciales.

#### Comprobaciones prácticas (sección 4.6)

1. **HTTP - Contrato observable**
   - **Reportar**: Método (GET, POST), código de estado (200, 404), dos cabeceras (por ejemplo, `Cache-Control`, `X-Request-ID`).
   - **Herramienta**: Inspector de red del navegador (Chrome DevTools, Firefox). Acceder a un sitio público (por ejemplo, `example.com`).
   - **Hallazgo e interpretación**: "Solicitud GET a example.com, código 200, cabeceras `Cache-Control: max-age=3600` (mejora rendimiento) y `X-Request-ID: abc123` (trazabilidad)."
   - **Captura**: Guardar inspector de red con método, código y cabeceras resaltados (`imagenes/http-evidencia.png`).

2. **DNS - Nombres y TTL**
   - **Reportar**: Tipo de registro (A, CNAME), TTL (por ejemplo, 3600 segundos) de un dominio público.
   - **Herramienta**: `dig`, `nslookup` en terminal, o sitio como `dns.google.com`.
   - **Hallazgo e interpretación**: "example.com, registro A, TTL 3600s. TTL alto retrasa rollbacks por propagación lenta."
   - **Captura**: Guardar consulta DNS con tipo y TTL resaltados (`imagenes/dns-ttl.png`).

3. **TLS - Seguridad en tránsito**
   - **Reportar**: CN, SAN, vigencia (desde/hasta), emisora de un certificado (por ejemplo, `https://example.com`).
   - **Herramienta**: Visor de certificados del navegador (candado en barra de direcciones).
   - **Hallazgo e interpretación**: "Certificado de example.com: CN=example.com, SAN=www.example.com, emitido por Let’s Encrypt, válido hasta 2025-11-01. Fallo en validación causa errores de confianza y riesgo de MITM."
   - **Captura**: Guardar ventana de certificado con CN, SAN, emisora y fechas resaltadas (`imagenes/tls-cert.png`).

4. **Puertos - Estado de runtime**
   - **Reportar**: Dos puertos en escucha (por ejemplo, 80, 443) y servicios (HTTP, HTTPS).
   - **Herramienta**: `netstat`, `ss`, o administrador de recursos del sistema.
   - **Hallazgo e interpretación**: "Puerto 80 (servidor web), 443 (HTTPS). Si 443 no está abierto, indica despliegue incompleto de TLS."
   - **Captura**: Guardar lista de puertos con puertos y servicios resaltados (`imagenes/puertos.png`).
> Si por política personal usas `Actividad_1`, explica al inicio del README que corresponde a **Actividad1-CC3S2** para mantener la trazabilidad.

