### IA atravesando todo el ciclo DevSecOps: de AIOps y MLOps a LLMOps y observabilidad


Hablar hoy de **DevSecOps** sin hablar de **IA** empieza a ser una omisión rara. Los equipos ya no solo automatizan *builds*, *tests* y despliegues: también entrenan modelos, consumen LLMs, enchufan copilots al IDE y montan paneles donde la mitad de las alertas ya han pasado antes por algún modelo de ML. La realidad es que la IA **ya está atravesando el ciclo DevSecOps**, nos guste o no.

El problema es que muchas conversaciones se quedan en la superficie: "pongamos un copilot", "metamos un chatbot encima de Grafana", "usemos un modelo para priorizar vulnerabilidades". Falta una mirada más sistémica: si la IA ahora forma parte de tu *toolchain*, de tu *pipeline* y de tu entorno de producción, entonces **también forma parte de tu superficie de ataque, tu cadena de suministro y tu modelo de observabilidad**.

Este texto intenta precisamente eso: dibujar la foto completa de **"IA atravesando todo el ciclo DevSecOps: de AIOps y MLOps a LLMOps y observabilidad"**. No como una lista de *buzzwords*, sino como un mapa coherente para alguien que ya vive en el mundo de *pipelines*, contenedores, Kubernetes, SRE y seguridad, y quiere entender cómo encajan AIOps, MLOps, MLSecOps, LLMOps y los *guardrails* alrededor de todo eso.

Se organiza en cinco bloques que se enganchan entre sí:

1. Cómo se ven **AIOps y MLOps desde una mentalidad DevSecOps**, tratando modelos y datos como artefactos más de la *supply chain*.
2. Qué implica hacer **LLMOps con guardrails**, cuando el LLM deja de ser una demo y se convierte en copiloto o interfaz sobre tus sistemas.
3. Cómo usar IA para **mejorar y proteger el propio pipeline DevSecOps**, sin caer en el "vibe coding" inseguro.
4. Qué cambios exige en **gobernanza, cumplimiento y gestión de riesgos** que parte del código y de las decisiones operativas las tomen modelos.
5. Y qué significa hablar de **observabilidad y "AI observability"** cuando ya no solo observas microservicios, sino también modelos y agentes.

La tesis de fondo es sencilla: un desarrollador o ingeniero DevSecOps no puede tratar la IA como una caja mágica pegada al costado del sistema, sino como un componente más de primera clase, con su *supply chain*, sus amenazas, sus controles y su telemetría. 

### 1. Fundamentos de AIOps/MLOps desde la mirada DevSecOps

Cuando hablamos de AIOps y MLOps "desde DevSecOps", la idea clave es **tratar modelos y datos como artefactos de la misma cadena de suministro** que el resto del software. 
Ya no basta con asegurar solo el código de la app; ahora hay que asegurar también *datasets*, *pipelines*, contenedores de entrenamiento y modelos desplegados.

#### Unificación DevOps-MLOps-DevSecOps

En un pipeline moderno, el flujo ideal se parece a esto:

> *commit -> build -> tests -> entrenamiento/actualización de modelo -> empaquetado (imagen + modelo) -> despliegue -> observabilidad -> realimentación a datos y modelo*.

Desde DevSecOps, eso significa:

* El código de la app, las definiciones de *pipelines* (CI/CD), los manifiestos de infraestructura (IaC) y los *pipelines* de ML se versionan y revisan igual que cualquier otro código.
* Los modelos se empaquetan como artefactos con **metadatos de procedencia**, firma y SBOM, igual que un contenedor. Frameworks como SLSA, Sigstore y Scorecard ya se están adaptando explícitamente al ciclo de ML. 
* La trazabilidad "end-to-end" es obligatoria: poder reconstruir qué *commit*, qué dataset y qué configuración de entrenamiento llevaron a un modelo concreto en producción, y qué métricas funcionales y de seguridad está dando ese modelo.

OpenSSF viene empujando justo esta visión de **MLSecOps**: extender las prácticas de *secure software supply chain* al ciclo de vida de IA/ML, no inventar algo completamente aparte.

#### AIOps aplicado a SRE/operaciones

En operaciones, AIOps no es magia; es **usar modelos para digerir la avalancha de telemetría** (métricas, logs, trazas, eventos) y ayudar al SRE a mantener SLO/SLI sin morir de fatiga de guardia.

Las plataformas de AIOps modernas hacen, sobre todo, tres cosas:

* **Detección de anomalías**, muchas veces multidimensional, donde se correlacionan métricas, logs y trazas para detectar patrones que un ojo humano no vería o vería demasiado tarde.
* **Correlación de eventos y reducción de ruido** (*event correlation*): agrupan alertas relacionadas, colapsan duplicados y señalan el "incidente raíz" en vez de inundar de notificaciones a la persona de *on-call*. 
* **Asistencia al *Root Cause Analysis* (RCA)**: generan hipótesis, sugieren qué servicios mirar primero e incluso proponen *queries* sobre observabilidad (PromQL, LogQL, TraceQL) o *runbooks* automatizados.

Desde DevSecOps, el matiz es que **estas decisiones automáticas también son superficie de ataque**: un modelo que sugiere silenciar alertas o ejecutar *playbooks* debe estar bajo control de permisos, auditoría y revisión humana, igual que un sistema de despliegue continuo.

#### MLOps con mentalidad de seguridad (MLSecOps)

A nivel de MLOps, "ponerle el gorro DevSecOps" significa:

1. **Threat model del pipeline de ML**

   No solo amenazas típicas (vulnerabilidades en dependencias o contenedores), sino también:

   * contaminación de datos de entrenamiento,
   * robo o manipulación de modelos,
   * abuso de servicios de inferencia,
   * alteración de *pipelines* de entrenamiento para producir modelos maliciosos.

2. **Controles DevSecOps en cada etapa**

   * Escaneo de imágenes y dependencias en los *jobs* de entrenamiento y de inferencia.
   * Generación de SBOMs también para artefactos de ML y servicios asociados.
   * Firma de modelos (Sigstore, cosign) y verificación en el despliegue.
   * *Policies* de admisión en K8s (OPA, Kyverno, Pod Security Standards, NetworkPolicies) que controlen **qué modelos** pueden correr, **dónde** y con qué acceso a datos.

3. **Seguridad como parte de la definición de "modelo listo para producción"**

   Un modelo no está "ready" solo porque alcanza cierta métrica de *accuracy*: hace falta también cumplir criterios de:

   * reproducibilidad (las mismas versiones de datos y código),
   * cumplimiento (licencias de datasets, privacidad),
   * robustez y seguridad (no exponer datos sensibles, no reaccionar mal ante *inputs* adversarios).


### 2. LLMOps + *Guardrails* específicos para DevSecOps

Cuando incorporas LLMs dentro del pipeline, empiezas a hablar de **LLMOps**: cómo desplegarlos, gobernarlos y protegerlos. Para que sea "nivel DevSecOps" necesitas pensar tanto en **arquitectura** como en **guardrails**.

#### Patrones de arquitectura: LLM como copiloto y como interfaz de observabilidad

Un desarrollador DevSecOps puede usar LLMs en varios puntos del pipeline:

* Como **copilot**:

  * para revisar *pull requests* con foco en seguridad e infraestructura,
  * para proponer casos de prueba, incluidos tests de regresión de seguridad,
  * para resumir *findings* de SAST, DAST, SCA o escáneres de IaC y sugerir planes de remediación,
  * para generar borradores de políticas en OPA (Rego), Kyverno, PodSecurity o NetworkPolicies que luego se refinan manualmente. 

* Como **interfaz conversacional sobre la observabilidad**:

  El LLM se conecta a Prometheus, Grafana, Loki, Tempo, etc., y permite hacer preguntas del tipo:

  > "¿Qué cambió en la latencia p95 del servicio `payments` después del último despliegue?"

  En interno, el agente genera *queries* PromQL/LogQL/TraceQL, las ejecuta y explica el resultado.

Aquí el patrón importante es que el LLM **no despliega nada directamente**: propone, explica, abre PRs o construye consultas, pero las acciones destructivas o de alto impacto pasan por aprobaciones y *pipelines* ya conocidos.

#### *Guardrails* técnicos: *tooling* y patrones

Para domar a estos LLMs aparecen los **frameworks de guardrails**:

* Toolkits como **NeMo Guardrails** permiten definir "rails" de entrada/salida, estilos de respuesta y políticas de uso de herramientas para chatbots, agentes y copilots.
* Las guías de seguridad recomiendan limitar la "agencia" del modelo: qué comandos puede ejecutar, sobre qué recursos y bajo qué condiciones, para evitar el riesgo de **agencia excesiva** descrito por OWASP en su proyecto de seguridad de GenAI.

En la práctica, estos guardrails incluyen:

* **Validación estructural**: las respuestas deben cumplir un JSON Schema, tipos fuertes o contratos de API; si no, se rechazan o rehacen.
* **Listas blancas de acciones**: el agente solo puede llamar a un conjunto muy limitado de herramientas ("consulta Prometheus", "abre un issue", "genera un diff") y nunca a comandos genéricos de *shell* sin una capa intermedia segura.
* **Límites de agencia y revisiones obligatorias**: por diseño, el agente no puede cerrar un incidente, fusionar una PR o desplegar a producción sin aprobación explícita de un humano o sin pasar por CI/CD y políticas existentes. 
* **Telemetría de guardrails**: se registran *prompts*, decisiones bloqueadas, reintentos y activaciones de filtros de seguridad, lo que permite auditar el comportamiento del sistema.

#### Seguridad de aplicaciones LLM: OWASP LLM Top 10

OWASP ya publicó un **Top 10 específico para aplicaciones LLM**, que incluye vulnerabilidades como *prompt injection*, fuga de información sensible, exfiltración de *system prompts*, *data poisoning* y agencia excesiva del modelo.

Para un equipo DevSecOps, esto se traduce en:

* tratar todos los *inputs* al LLM como **potencialmente hostiles**,
* evitar que el modelo pueda leer `.env`, claves o datos de producción sin una capa de autorización independiente,
* proteger el *system prompt* y las políticas internas para que no sean expuestas ni por error ni por ataques de ingeniería de *prompts*,
* diseñar **tests automatizados de prompts**, donde otros scripts o agentes intentan deliberadamente hacer *prompt injection*, robar configuración, forzar acciones no deseadas, etc.

#### Evaluación continua en contexto de seguridad

Un LLM puede ayudarte a revisar recomendaciones de *hardening*, pero **no debería ser el único juez**. Un patrón razonable es:

1. El LLM actúa como **"LLM-as-a-judge"** (usar un LLM como evaluador automático) y puntúa o prioriza *findings*, sugerencias o cambios.
2. Un **segundo canal**, scripts, linters, SAST, escáneres de políticas, valida objetivamente la propuesta. 

Eso encaja bien con la filosofía DevSecOps: usar IA como acelerador, nunca como autoridad final incontestable.


### 3. IA para mejorar *y proteger* el pipeline DevSecOps

Aquí es donde un desarrollador DevSecOps puede sacarle mayor provecho a la IA, siempre con la consciencia de que **gran parte del código generado por IA es inseguro**.

#### IA para seguridad de código y dependencias

Las herramientas de *AI coding* pueden sugerir código, tests y *refactors*, pero estudios recientes apuntan a que una fracción significativa (en torno al 40-50%) de ese código contiene vulnerabilidades o prácticas débiles de seguridad.

Al mismo tiempo, encuestas muestran que una mayoría de organizaciones siguen desplegando código vulnerable, y que la adopción de IA está aumentando el volumen de código sin un aumento proporcional en controles de seguridad.

Por eso, dentro del pipeline DevSecOps:

* el código generado por IA se trata como **no confiable por defecto**: siempre pasa por revisiones, linters y SAST;
* se integran herramientas que analizan específicamente el código generado por IA y detectan patrones de inseguridad, malas prácticas o uso indebido de dependencias. 

#### IA aplicada a seguridad como código (security as code) y políticas como código (policy as code)

La IA también puede ayudar a escribir y mantener políticas:

* generar plantillas de políticas Rego (OPA/Conftest), reglas Kyverno, Pod Security Standards o NetworkPolicies para Kubernetes basadas en la topología de servicios y el perfil de tráfico,
* refinar esas políticas según el comportamiento observado (*drift*): por ejemplo, un agente sugiere restringir puertos, protocolos o *namespaces* que nunca se usan en producción. 

Aquí el riesgo es que el agente "endurezca demasiado" el entorno y rompa cosas, o que, al contrario, relaje políticas sin entender efectos secundarios. De nuevo, los cambios deben pasar por PRs, revisión y tests.

#### IA para seguridad de la cadena de suministro

En *supply-chain security*, los modelos ayudan a **priorizar findings** de SCA/SAST/DAST, correlándolos con el contexto de negocio, el uso real en producción y la criticidad del componente. Algunos proveedores ya están usando IA para analizar miles de vulnerabilidades y sugerir en qué concentrarse primero.

También se explora el uso de IA para:

* detectar anomalías en imágenes de contenedores, artefactos o modelos (tamaño, dependencias inesperadas, cambios sospechosos),
* generar automáticamente SBOMs enriquecidos y resúmenes ejecutivos de riesgo por servicio.

#### AIOps y detección y respuesta ante amenazas (threat detection & response)

Finalmente, AIOps se cruza con seguridad cuando los modelos:

* correlacionan señales de observabilidad (métricas, logs, trazas) con eventos de seguridad (alertas de IDS/IPS, autenticación, cambios en IaC),
* disparan **playbooks automáticos**: por ejemplo, aislar un pod, rotar una credencial, revertir un despliegue o aumentar el nivel de logging para un servicio concreto.

En DevSecOps, esta automatización siempre se diseña con **límites claros**: qué *playbooks* pueden ejecutarse automáticamente, cuáles requieren aprobación humana y cómo se auditan.

### 4. Gobernanza, cumplimiento y riesgos de usar IA en DevSecOps

Si de aquí a 2030 la IA va a escribir una parte importante del código y gestionar parte de las operaciones, la pregunta no es solo "¿funciona?", sino "¿es **legal, trazable y auditada**?".

#### Riesgos introducidos por la IA en el SDLC

Entre los riesgos más claros:

* **Licencias y propiedad intelectual**

  Herramientas como Black Duck ya se usan para auditar código y generar SBOMs, identificando componentes open source, licencias y obligaciones; hoy empiezan a aplicarse explícitamente también al código generado por IA, analizando fragmentos para detectar coincidencias con proyectos OSS.

  Además, algunos proyectos han optado por políticas extremas de "no aceptar código asistido por IA" para evitar conflictos de licencias y problemas de calidad.

* **Trazabilidad y responsabilidad**

  En un escenario de **"vibe coding"** (aceptar sugerencias de la IA sin diseccionarlas), se vuelve difusa la responsabilidad sobre vulnerabilidades introducidas. Por eso, muchas recomendaciones actuales piden:

  * marcar explícitamente dónde se ha usado IA,
  * exigir que los cambios pasen por revisión humana real,
  * mantener artefactos de auditoría que permitan reconstruir qué se generó con IA y qué no.

* **Agentes con permisos excesivos en CI/CD**

  El riesgo de **agencia excesiva** se agrava cuando un agente tiene acceso directo a credenciales, despliegues o cambios en IaC. La recomendación es aplicar estrictamente el **principio de menor privilegio**, la separación de funciones y *tokens* de vida corta para cualquier herramienta de IA que interactúe con CI/CD.

#### *Governanza* de datos y *prompts*

Las organizaciones empiezan a tratar **prompts, logs de interacción y telemetría de guardrails** como datos sensibles:

* se aplica **data minimization**: solo se manda al modelo la información estrictamente necesaria; se evitan PII y secretos en *prompts*, especialmente si el modelo está en SaaS,
* se clasifican los tipos de datos que pueden entrar/salir de la plataforma de IA, y se decide qué modelos deben estar *on-prem/self-hosted* y cuáles pueden ser servicios externos,
* se definen retenciones claras para logs de *prompts* y respuestas, incluyendo quién puede auditarlos y con qué propósito. 

Todo esto se engloba en una política de uso responsable de IA para el SDLC.

#### "Menos gates, mas guardrails"

Finalmente, la filosofía **"less gates, more guardrails"** propone que la seguridad no se aplique solo como "portones de rechazo" al final del proceso, sino como **barandillas que guían** desde el principio.

Aplicado a IA + DevSecOps:

* en lugar de prohibir el uso de IA, se dan **herramientas, políticas y pipelines** para usarla de forma segura,
* los guardrails orientan la manera correcta de usar IA (plantillas de *prompts* seguras, agentes con permisos mínimos, revisiones obligatorias, etc.) sin frenar por completo la productividad.

### 5. Observabilidad y "AI observability" aplicada a DevSecOps

Si la IA entra en el pipeline, también debe entrar en tu **modelo de observabilidad**. No solo observas microservicios: observas también *modelos*, *agentes* y *copilots*.

#### Observabilidad clásica + AIOps

El primer nivel es el habitual en SRE:

* métricas de rendimiento y fiabilidad (latencia, errores, saturación),
* logs estructurados y trazas distribuidas,
* eventos de despliegue y cambios de infraestructura.

AIOps se apoya en toda esa telemetría para hacer detección de anomalías, correlación de eventos, predicción de incidentes y priorización de alertas.

#### Observabilidad de modelos /observabilidad de LLM

El segundo nivel es la **observabilidad específica de modelos**:

* métricas de **drift** (cambios en la distribución de *inputs* respecto al entrenamiento),
* tasa de errores de modelo (por ejemplo, cuántas sugerencias de un copilot son revertidas, cuántos análisis de seguridad fueron incorrectos),
* métricas de **calidad y seguridad de las respuestas**: toxicidad, alucinaciones, grado de *grounding* en fuentes confiables,
* métricas de uso: quién usa el copilot, para qué tareas, qué ratio de adopción y aceptación tiene. 

Un concepto útil es el **"dashboard de salud del copilot"**:

* paneles que muestran cuántas sugerencias se aceptan vs. se rechazan,
* cuántas sugerencias disparan alertas de SAST o revisiones correctivas,
* cuántos *prompts* son bloqueados por guardrails y por qué categorías (intento de leer secretos, *prompt injection*, operación peligrosa, etc.).

Esta observabilidad cierra el círculo DevSecOps:

* si el copilot está introduciendo muchas vulnerabilidades, lo ves pronto en las métricas y puedes cambiar configuración, modelo, *prompts* o políticas;
* si los guardrails bloquean demasiadas acciones legítimas, puedes ajustar reglas para no frenar la productividad;
* si AIOps se está equivocando en la priorización de incidentes, puedes recalibrar modelos o *features*.


En conjunto, estos cinco bloques definen el perfil de un **desarrollador DevSecOps que usa IA de apoyo** pero no renuncia a la disciplina: trata la IA como un componente más del sistema, con su *supply chain*, sus amenazas, su observabilidad y su gobernanza, en vez de verla como una caja mágica que "hace las cosas más rápido" sin consecuencias.

