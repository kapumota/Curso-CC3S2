### Agentes de IA para DevSecOps: arquitectura, observabilidad y red-teaming

La incorporación de *agentic AI* en entornos de **DevSecOps** marca un cambio de paradigma: pasamos de herramientas que solo asisten mediante sugerencias puntuales (copilots, chatbots) a **sistemas que pueden tomar decisiones, ejecutar acciones y coordinarse entre sí** dentro del ciclo de vida del software. Esto afecta de manera directa la forma en que concebimos la arquitectura de las plataformas, los mecanismos de observabilidad y las prácticas de seguridad.

En contextos donde conviven **microservicios, pipelines CI/CD, Kubernetes, seguridad como código y plataformas de observabilidad** (Prometheus, Grafana, Loki, Tempo, etc.), los agentes de IA se posicionan como una nueva capa lógica capaz de:

* Consumir y correlacionar señales de distintas fuentes (código, findings de SAST/SCA, métricas, trazas, tickets).
* Proponer y, en ciertos casos, ejecutar cambios sobre código, infraestructura y políticas de seguridad.
* Mantener un ciclo continuo de *pensar -> actuar -> observar -> corregir* que se asemeja al trabajo de un equipo de SRE y AppSec, pero orquestado de manera automatizada.

Sin embargo, esta misma capacidad abre **nuevos vectores de riesgo y responsabilidad**. Un agente con agencia mal diseñado, sin guardrails adecuados o sin un modelo de observabilidad propio, puede amplificar fallos, degradar SLO/SLI, introducir vulnerabilidades o incluso provocar incidentes graves (borrado de datos, exposición de secretos, cambios peligrosos en IaC). Por ello, el diseño de agentes para DevSecOps no puede verse solo como un problema de "productividad", sino como un ejercicio completo de **arquitectura, gobierno, seguridad y ética profesional**.

Este documento desarrolla, con mayor detalle, los siguientes ejes:

* La **definición operativa** de agente de IA en clave DevSecOps y la diferencia respecto a un LLM genérico.
* El patrón de comportamiento *pensar -> actuar -> observar -> corregir* aplicado al pipeline de CI/CD y a la gestión de seguridad.
* El diseño de un **ecosistema multi-agente** que funcione como un "equipo virtual" de DevSecOps (seguridad de código, CI/CD, dependencias, cumplimiento, inteligencia de amenazas, observabilidad).
* El papel de la **observabilidad y los SLO/SLI** como "brújula" para las decisiones de los agentes.
* La necesidad de un **red-teaming sistemático** frente a riesgos como prompt injection, exfiltración de datos y excesiva agencia.
* Los aspectos de **ética y responsabilidad profesional**, incluyendo el problema del *vibe coding* y la sobreconfianza en las recomendaciones de la IA.

Con este marco, la intención es ofrecer una base conceptual y práctica para que puedan **evaluar, diseñar y auditar** agentes de IA para DevSecOps, alineando la promesa de automatización inteligente con exigencias de seguridad, cumplimiento y calidad de servicio.

Un **agente de IA para DevSecOps** no es "otro chatbot simpático", sino un componente que **piensa, decide y actúa** dentro de tu SDLC y tus pipelines. Justo por eso abre un campo gigante de oportunidades… y de riesgos si no se diseña bien.

#### 1. Qué es un agente de IA en clave DevSecOps

La diferencia entre un LLM "a secas" y un **agente** es la **agencia**:
un agente no solo responde a un prompt, sino que:

1. **Percibe**: lee código, findings, métricas, logs, tickets.
2. **Piensa/planifica**: decide qué hacer (por ejemplo, "abrir una PR con este fix", "bloquear este despliegue").
3. **Actúa**: llama APIs, ejecuta tests, interactúa con Git, CI/CD o plataformas de observabilidad.
4. **Observa y corrige**: mira el resultado (tests verdes/rojos, métricas, SLO/SLI) y ajusta el plan.

Este bucle *pensar -> actuar -> observar -> corregir* es la versión DevSecOps del clásico ciclo de agente en IA. Gartner llama a esto **agentic AI** y estima que, para 2028, **un tercio de las aplicaciones empresariales** incluirán agentes especializados, y que alrededor del 15% de las decisiones diarias serán tomadas de forma autónoma por estos sistemas. 

Para DevSecOps esto significa que una parte relevante de las decisiones sobre **seguridad, calidad y despliegue** ya no pasan solo por humanos o scripts estáticos, sino por agentes capaces de razonar, coordinarse y aprender del contexto. GitLab, Checkmarx y otros vendors están justamente empujando esta visión de agentes que se integran en CI/CD, AppSec y observabilidad.


#### 2. El patrón "pensar -> actuar -> observar -> corregir" aplicado al pipeline

Llevemos ese patrón al terreno concreto de DevSecOps. Imagina un **agente de seguridad de código** integrado en tu repositorio y tu pipeline:

1. **Pensar (planificar)**
   El agente recibe como input:

   * un nuevo *pull request*,
   * findings de SAST/SCA,
   * y quizá contexto de arquitectura (microservicio, entorno, criticidad).

   Con eso construye un plan:
   "estas tres vulnerabilidades son críticas, sugiero este cambio en el código, esta actualización de dependencia y esta regla nueva de OPA".

2. **Actuar**
   El agente:

   * añade comentarios en la PR,
   * genera un commit de prueba con el fix,
   * dispara una ejecución de tests y escáneres de seguridad,
   * o propone una regla de *policy-as-code*.

3. **Observar**
   Revisa el resultado:

   * ¿los tests pasan?
   * ¿bajó el número de findings?
   * ¿cambió algo en métricas de rendimiento o error rate?

   Aquí entra la integración con **Prometheus, Grafana, Loki, Tempo**: el agente puede lanzar consultas PromQL/LogQL/TraceQL para comprobar si el cambio impactó en latencia, error rate, SLO/SLI, etc.

4. **Corregir**
   Si algo salió mal (tests rotos, métricas degradadas), el agente:

   * revierte el cambio,
   * propone una variante del fix,
   * o escala la situación a un humano (approval gate).

La clave es que el agente **no actúa a ciegas**: cada iteración está guiada por la observabilidad y por los SLO/SLI del servicio, igual que haría un SRE, pero automatizado. Esto se alinea con propuestas recientes de "Agentic AI para DevSecOps": usar agentes no solo para detectar problemas, sino para **cerrar el loop** de forma controlada.

#### 3. Ecosistema de agentes: multi-agent AI como "equipo" DevSecOps

La visión de Checkmarx, GitLab y otros proveedores es que no habrá "un agente mago", sino una **red de agentes especializados** que colaboran, similar a un equipo de ingeniería: 

* **Agente de seguridad de código**
  Inspecciona PRs, busca vulnerabilidades, patrones inseguros, malas prácticas en *frameworks*, genera parches y *tests* asociados.

* **Agente de seguridad de CI/CD**
  Se sienta dentro del *pipeline*:

  * orquesta SAST/SCA/DAST,
  * interpreta sus resultados,
  * ajusta los *security gates* (por ejemplo, permitir *deploy* con ciertos riesgos conocidos y mitigados, bloquear otros).

* **Agente de gestión de dependencias**
  Vigila vulnerabilidades en paquetes, planifica actualizaciones, lanza pruebas de regresión y gestiona compatibilidad y licencias.

* **Agente de cumplimiento y documentación**
  Genera y mantiene documentación de seguridad, evidencias de cumplimiento, reportes para auditorías y trazas de quién aprobó qué y cuándo.

* **Agente de inteligencia de amenazas**
  Consume *feeds* de CVEs y amenazas, los cruza con tu *stack* y tu SBOM, evalúa qué realmente te afecta y dispara tareas al resto de agentes.


* (Opcional, pero muy útil) **Agente de observabilidad**
  Integra métricas, logs y trazas para:

  * detectar anomalías,
  * sugerir cambios en SLO/SLI,
  * dar contexto a los fixes (por ejemplo, "esta vulnerabilidad está en un endpoint casi sin tráfico, esta otra está en el *hot path*").

Estas arquitecturas multi-agente ya se estudian en la literatura reciente como una forma de **integrar la seguridad como código (*security as code*) de forma proactiva**, reduciendo trabajo manual y aumentando la capacidad de respuesta en tiempo real. 

#### Cómo colaboran en la práctica

Un flujo típico podría ser:

1. El **agente de inteligencia de amenazas** detecta una CVE crítica en una librería que usas.
2. Notifica al **agente de dependencias**, que calcula qué servicios y qué versiones están afectados.
3. El **agente de dependencias** propone actualizaciones y abre *pull requests* (PRs) automatizadas.
4. El **agente de seguridad de código** revisa el impacto, ajusta el código si hace falta y añade tests.
5. El **agente de seguridad de CI/CD** sube temporalmente el nivel de los *security gates* y bloquea despliegues con versiones vulnerables hasta que las PRs se fusionan.
6. El **agente de cumplimiento** registra todo el proceso en documentación y evidencias para auditoría.
7. El **agente de observabilidad** verifica en producción que el *fix* no rompió los SLO/SLI.

Desde la perspectiva de los desarrolladores, el objetivo es que **"arreglar seguridad" se parezca a aceptar un cambio sugerido**: integrar la seguridad en el flujo de trabajo de Dev sin exigir que todos se vuelvan expertos en AppSec o *compliance*. 

#### 4. Agentes y observabilidad: SLO/SLI como brújula de la IA

Si los agentes van a tocar código, pipelines y configuración, necesitan una **brújula** para no optimizar solo "eliminar findings", sino *mantener el sistema sano*.

Ahí entran **SLO/SLI + observabilidad**:

* El agente no solo pregunta "¿SAST está en verde?", sino:

  * "¿Cómo cambió la latencia p95 del endpoint después del fix?"
  * "¿Aumentó el error rate en este servicio después de aplicar una regla más restrictiva de NetworkPolicy?"
  * "¿Se mantiene el SLO de disponibilidad después de añadir más controles de seguridad?"

* La observabilidad se convierte en **feature para modelos de AIOps**:

  * detección de anomalías,
  * predicción de incidentes,
  * correlación de cambios de seguridad con degradaciones.

La literatura actual de AIOps insiste en que los modelos pueden reducir ruido de alertas, correlacionar eventos y acelerar el *Root Cause Analysis*, siempre que tengan acceso a métricas, logs y trazas bien diseñadas.

Un **DevSecOps con agentes** debería, por diseño:

* Loggear y trazar las acciones del agente (qué decisión tomó, por qué, con qué inputs).
* Usar Prometheus/Grafana/Loki no solo para la app, sino para el propio **comportamiento del agente**: ratio de aciertos, reversión de cambios, acciones bloqueadas por *guardrails*, etc.
* Definir SLO/SLI también para el "copilot": por ejemplo, porcentaje de sugerencias aceptadas, bugs o vulnerabilidades introducidas por código sugerido, etc.

#### 5. Red-teaming de agentes y LLMs: romperlos antes de que nos rompan

La otra cara de los agentes es que **amplifican el impacto de errores y ataques**. Si un LLM alucina en un chat, molesta. Si un agente con permisos de CI/CD alucina, puede borrar un disco o abrir un acceso inseguro. Casos recientes de agentes que han ejecutado comandos destructivos en IDE y sistemas operativos muestran que esto no es ciencia ficción.

El OWASP Top 10 para aplicaciones LLM (versión 2025) lista riesgos específicos como **inyeccíon de prompts, exfiltración de datos, fuga de prompts internos, excesiva agencia y sobre-dependencia en las respuestas del modelo**. 

Para DevSecOps esto lleva a una práctica obligatoria: el **red-teaming de LLMs y agentes**.

### Qué significa red-teamear un agente

* **Inyección de Prompts**
  Construir inputs (cadenas de commits, comentarios, documentos, logs, páginas HTML) que intenten:

  * engañar al agente para saltarse controles,
  * desactivar validaciones,
  * extraer secretos o *system prompts*,
  * ejecutar comandos no previstos.

* **Abuso de herramientas**
  Ver si el agente puede:

  * ejecutar comandos de shell más allá del *scope* permitido,
  * acceder a recursos de producción que deberían estar vedados,
  * crear cambios irreversibles sin pasar por los *approval gates*.

* **Exfiltración de datos**
  Intentar hacer que el agente:

  * copie contenidos sensibles desde repos privados, bases de datos o logs,
  * los envíe hacia fuera (por ejemplo, hacia un modelo SaaS) violando políticas de *data minimization*.

* **Evasión de guardrails**
  Probar si el agente puede:

  * reescribir sus propios prompts,
  * ignorar reglas de uso de herramientas,
  * eludir validaciones estructurales (por ejemplo, generando JSON parcialmente malformado para saltarse chequeos simples).

OWASP y varias guías recientes recomiendan generar **baterías de tests automatizados de prompts y acciones**, no solo pruebas manuales, para someter a los agentes a ataques de forma continua.


#### 6. Ética y responsabilidad profesional: contra el "vibe coding"

En paralelo a los riesgos técnicos aparece un tema más incómodo: el **"vibe coding"**. Es esa práctica de aceptar sugerencias del copilot o del agente sin comprenderlas realmente ("total, pasó los tests"). En seguridad esto es peligrosísimo.

OWASP lo recoge como riesgo de **Overreliance**: confiar ciegamente en las salidas de un LLM o agente sin validación crítica.

Desde una mirada profesional y ética en DevSecOps, emergen varios principios:

1. **El humano sigue siendo responsable**
   Aunque Checkmarx y otros muestran que los agentes pueden mejorar la productividad y las métricas DORA (menos tiempo en tareas de seguridad, fixes más rápidos, mejor MTTR), la responsabilidad profesional frente a vulnerabilidades, fugas o fallos sigue recayendo en los equipos humanos.

3. **Transparencia y trazabilidad de la IA**

   * Marcar qué cambios vienen de un agente.
   * Mantener logs y evidencias de decisiones automatizadas.
   * Explicar a auditores y *stakeholders* cómo se entrenan, configuran y evalúan esos agentes.

4. **Principio de menor privilegio y "no matar al mensajero"**

   * El agente debe tener permisos estrictamente necesarios.
   * Las acciones de alto riesgo (borrados, cambios en producción, rotación masiva de credenciales) exigen aprobación humana y, idealmente, una "two-person rule".

5. **Educación de los desarrolladores**

   * Enseñar a leer y cuestionar recomendaciones de IA.
   * Entrenar en riesgos específicos de *agentic AI* y OWASP LLM Top 10.
   * Trabajar con casos reales como los incidentes de agentes que han borrado datos o ejecutado comandos peligrosos.

[Gartner](https://www.reuters.com/business/over-40-agentic-ai-projects-will-be-scrapped-by-2027-gartner-says-2025-06-25/) incluso anticipa que **más del 40% de los proyectos de *agentic AI* serán cancelados** antes de 2027 por costes, falta de valor real o diseño deficiente, lo que refuerza la idea de que no basta "poner agentes por moda"; hay que alinearlos con objetivos claros y controles sólidos.


#### 7. Conclusión: agentes como "equipo de seguridad aumentado", no como piloto automático

Si juntamos todo:

* El patrón **pensar -> actuar -> observar -> corregir** permite agentes que trabajan como SREs y AppSec virtuales, integrados en tus pipelines y en tu observabilidad.
* Las arquitecturas **multi-agente** reparten el trabajo: seguridad de código, CI/CD, dependencias, *compliance*, inteligencia de amenazas, observabilidad, todos coordinados.
* La promesa es clara: **menos tiempo perdido en "security busywork"**, mejor MTTR, mejores métricas DORA y seguridad más profundamente integrada en el flujo de desarrollo.
* Pero, a cambio, introduces un nuevo tipo de riesgo: sistemas con capacidad real de acción, sujetos a *prompt injection*, excesiva agencia, sobre-confianza y fallos de diseño.

Un **DevSecOps con agentes** no ve la IA como piloto automático, sino como un **equipo de asistentes expertos** que:

* está instrumentado y observado,
* tiene permisos limitados,
* es sometido a *red-teaming* continuo,
* y trabaja bajo la supervisión de ingenieros que entienden tanto de seguridad como de IA.

