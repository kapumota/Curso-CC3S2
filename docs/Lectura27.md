### SRE, SLI/SLO/SLA e Ingeniería del Caos: un marco práctico de confiabilidad para DevSecOps

En este texto vamos a conectar SRE, SLI/SLO/SLA e Ingeniería del Caos con un enfoque DevSecOps. 
La idea no es dar definiciones de manual, sino entender cómo estas piezas cambian la forma en que tomamos decisiones sobre confiabilidad y seguridad  en sistemas modernos.


### 1. SRE como cambio de enfoque: de "mantener vivo el sistema" a "diseñar la confiabilidad"

Cuando hablamos de **Site Reliability Engineering (SRE)** no estamos hablando solo de un nuevo rol, sino de un **cambio de marco mental**.

En el modelo clásico, "operaciones" es el equipo que recibe el sistema una vez que desarrollo "terminó". Su trabajo es mantenerlo arriba: monitorear, reiniciar, aplicar parches, responder tickets. Si algo falla, se culpa al sistema o al tráfico, pero pocas veces se cuestiona el diseño.

SRE rompe esa separación. La idea central es:

> *La confiabilidad no es algo que se "opera" al final; es algo que se diseña, se mide y se negocia desde el principio.*

Por eso SRE:

* Toma técnicas de **ingeniería de software** (automatización, pruebas, revisiones de código).
* Las aplica al mundo de **operaciones** (despliegues, monitoreo, gestión de incidentes).
* Y las conecta con el lenguaje del **negocio** (qué nivel de disponibilidad necesita el usuario, cuánto cuesta mantenerla, qué riesgo aceptamos).

En un entorno **DevSecOps**, SRE se convierte en el pegamento entre:

* El **ritmo de cambio** (CI/CD, despliegues frecuentes).
* La **superficie de ataque** y los controles de seguridad.
* La **experiencia del usuario**, que es el juez final: si el sistema es "seguro" pero constantemente lento o caído, sigue siendo un fracaso.

Aquí es donde entran SLI, SLO y SLA: como el lenguaje formal que permite que todas estas partes conversen sin gritarse.

### 2. SLI: mirar la realidad sin autoengaño

Un **Service-Level Indicator (SLI)** parece una simple métrica, pero conceptualmente es más exigente:

* No es "cualquier métrica que expone Prometheus".
* Es una **aproximación cuantitativa a la experiencia del usuario**.

Por eso, un buen SLI no es "CPU al 90 %", sino cosas como:

* "Porcentaje de solicitudes de lectura al API `/orders` que devuelven 2xx en menos de 300 ms."
* "Porcentaje de intentos de login que completan correctamente sin error del servidor."
* "Porcentaje de mensajes procesados sin pérdida en la cola en los últimos 10 minutos."

Lo importante no es tanto la fórmula técnica, sino la **intención**:

> *¿Qué variable puedo medir que se parezca lo más posible a cómo el usuario percibe si mi servicio está "bien" o "mal"?*

Desde una óptica DevSecOps, este punto es clave: puedes tener pipelines impecables, imágenes escaneadas y certificados al día, pero si tus SLIs muestran que el usuario sufre (tiempos enormes, errores aleatorios), el sistema no es confiable.

Además, los SLIs te obligan a hacer algo incómodo: **definir qué es éxito y qué es fracaso** en términos de respuesta del servicio. Eso implica, por ejemplo:

* Elegir qué códigos HTTP se consideran "buenos".
* Decidir si los timeouts del cliente cuentan como fallo del servicio.
* Diferenciar tráfico interno, pruebas y usuarios reales.

Es una disciplina contra el autoengaño: no vale "sentir que todo va bien", hay que demostrarlo con SLIs bien definidos.

### 3. SLO: convertir la intuición en un contrato interno

Todo equipo tiene una intuición de qué significa "funcionar bien":

* "Nuestro sistema casi nunca se cae."
* "Las páginas cargan rápido."
* "Las fallas son raras."

El problema es que esa intuición, sin números, es imposible de gestionar. Aquí entra el **Service-Level Objective (SLO)**: tomar esa intuición y **clavarlo en la pared con un número**.

Por ejemplo:

* "Al menos el 99,9 % de las solicitudes a la API deben ser exitosas en una ventana de 30 días."
* "El 95 % de los logins deben completarse en menos de 400 ms."

Cuando defines un SLO, estás haciendo tres cosas a la vez:

1. **Negociando con el negocio**
   Estás diciendo: "Este es el nivel de experiencia que podemos ofrecer de manera sostenible". Más disponibilidad implica más costo (más réplicas, más redundancias, más complejidad). Menos disponibilidad implica perder usuarios o confianza. El SLO es un equilibrio explícito, no un ideal vago.

2. **Delimitando el espacio de trabajo técnico**
   SRE usa el SLO como criterio para debatir cambios:

   * "¿Esta nueva feature pone en riesgo nuestro SLO?"
   * "¿Esta deuda técnica está contribuyendo a salirse de SLO?"
     Sin SLO, cada discusión se vuelve subjetiva y política.

3. **Creando un "presupuesto de error"**
   Si tu SLO es 99,9 % de disponibilidad mensual, implícitamente estás aceptando 0,1 % de no disponibilidad. Ese 0,1 % es tu **error budget**.

   * Si lo consumes muy rápido, frenas el ritmo de cambios y priorizas estabilidad.
   * Si nunca lo consumes, quizás estás siendo "demasiado confiable" a un costo innecesario.

En DevSecOps, el SLO también puede incluir dimensiones de seguridad, no solo disponibilidad: tiempo máximo aceptable para corregir vulnerabilidades críticas, tasa máxima de fallos de autenticación debido a errores del sistema, etc.


### 4. SLA: cuando la confiabilidad se convierte en obligación legal

El **Service-Level Agreement (SLA)** es una extensión "legal" de todo lo anterior: toma SLOs (o derivadas de estos) y los transforma en un **compromiso contractual**.

Lo que lo diferencia del SLO no es la idea, sino las consecuencias:

* SLO: compromiso interno del equipo, herramienta de gestión.
* SLA: promesa explícita al cliente, con penalizaciones en caso de incumplimiento.

Por eso, casi siempre:

* El SLO interno es **más estricto** que el SLA.
* El SLA elige con cuidado qué SLIs y qué ventanas temporales contar.
* Se especifica qué entra en el cálculo y qué no (por ejemplo, excluir tráfico de pruebas, abusos evidentes, ataques, uso fuera de contrato).

Esto tiene un efecto interesante en la cultura DevSecOps:

* Operar "por debajo" del SLA puede dar una sensación falsa de seguridad: "no hay penalización, todo ok".
* Pero si el equipo está mirando sus propios SLO internos, sabe que quizá ya está en zona roja aunque el SLA no se haya roto todavía.

En otras palabras, el SLA es para afuera; el SLO es para adentro. Y ambos deben estar alineados, pero no ser idénticos.

### 5. SRE como marco de decisiones en DevSecOps

Si juntamos todo:

* SLIs definen **cómo miramos** el comportamiento del sistema.
* SLOs definen **qué consideramos aceptable**.
* SLAs definen **qué prometemos al mundo externo**.

SRE pone esto en el centro de la conversación. Y en un contexto DevSecOps pasa algo muy interesante: los **dilemas clásicos** (¿desplegar ya o esperar?, ¿priorizar seguridad o features?, ¿aceptar deuda técnica?) dejan de ser puramente emocionales y se vuelven **decisiones guiadas por SLO**.

Ejemplos:

* Si tus SLIs muestran que estás cerca de romper el SLO de disponibilidad, quizá pospones una feature que introduce mucha complejidad.
* Si tus SLIs de seguridad (por ejemplo, vulnerabilidades críticas abiertas en producción) están fuera de lo aceptable, se activa un modo "pagar deuda" incluso si el backlog de features es grande.
* Si llevas meses cumpliendo SLOs con margen, puedes permitirte experimentar más agresivamente con nuevas features o refactors.

En lugar de "Dev quiere ir rápido y Ops quiere ir lento", el marco es:

> "Vamos tan rápido como nuestro error budget (y nuestros SLO de seguridad) nos lo permitan."


### 6. Ingeniería del Caos: poner a prueba la narrativa de la confiabilidad

La **Ingeniería del Caos** es, en el fondo, una forma radical de honestidad técnica.

Todos decimos que nuestros sistemas son:

* Resilientes,
* Tolerantes a fallos,
* Preparados para caídas de servicios externos,
* Diseñados para degradación elegante.

Pero hasta que no **introduces fallos reales de manera controlada** y miras qué pasa, eso es solo narrativa.

La Ingeniería del Caos propone:

1. **Asumir que todo puede fallar**: redes, discos, DNS, colas, certificados, secretos, librerías, servicios externos.
2. **Diseñar experimentos** en entorno controlado (idealmente producción con límites) que provoquen estos fallos: matar pods, degradar la red, romper dependencias, expirar certificados, etc.
3. **Observar el impacto en los SLIs**:

   * ¿Se mantiene dentro del SLO?
   * ¿Las alertas saltan a tiempo?
   * ¿Los dashboards permiten entender qué pasa?
   * ¿Los playbooks y runbooks son útiles?

Lo central no es el "truco" de matar una instancia con un demonio (tipo Chaos Monkey), sino la **reflexión posterior**:

> "Este experimento nos mostró que, en realidad, no teníamos ninguna alerta útil cuando la latencia entre servicios se disparó"
> "Descubrimos que si falla el proveedor de OAuth, todo el sistema cae en cascada."

Es decir, el caos no se introduce para volver el sistema "caótico", sino para revelar las **fragilidades ocultas** que una operación "normal" no muestra.

### 7. Ingeniería del Caos y DevSecOps: más allá de la disponibilidad

Cuando llevas el caos al mundo **DevSecOps**, ya no solo pruebas disponibilidad y latencia:

* Puedes simular que un servicio **pierde acceso a secretos** (el vault se cae, el secret en Kubernetes se borra por error).
* Puedes provocar que un nodo se quede sin espacio en disco y ver si los logs y métricas te lo dicen a tiempo antes de corromper algo.
* Puedes degradar el rendimiento de tu **sistema de autenticación** y observar si el resto de servicios falla con códigos de error claros y seguros, o si empiezan a filtrar información rara.

Esto te obliga a enfrentar la pregunta que muchas arquitecturas evitan:

> *¿Qué pasa con la seguridad cuando las cosas salen mal?*

Una arquitectura verdaderamente DevSecOps no solo dice "tenemos TLS y un WAF", sino:

* "Si cae el proveedor de identidad, el sistema falla de forma segura y conocida."
* "Si se corta el acceso al sistema de escaneo de imágenes, el pipeline se comporta conforme a política: o frena el despliegue o entra en un modo explícito, controlado y registrado."
* "Si hay un pico de tráfico tipo DDoS, los límites de tasa protegen a los sistemas críticos y los SLIs de disponibilidad se degradan de forma controlada."

La Ingeniería del Caos se vuelve así un **laboratorio** para tus políticas DevSecOps: no solo verificas que existen en YAML o en código, sino que se comportan como crees bajo estrés real.

### 8. La capa cultural: SLOs y caos como antídoto contra la culpa

Hay un componente cultural muy fuerte en todo esto.

Sin SLOs y sin experimentos de caos, la conversación sobre incidentes tiende a:

* "¿Quién rompió producción?"
* "Fue la última feature."
* "Operaciones no hizo monitoreo."
* "Seguridad bloquea todo."

Con SLOs claros y con una práctica adulta de Ingeniería del Caos, la conversación cambia:

* Un incidente no es un escándalo moral, es un dato: "estamos fuera de SLO, hay que entender por qué".
* Un experimento fallido no es una vergüenza, es un avance: "el caos nos mostró que nuestra arquitectura no se comporta como creíamos, buen descubrimiento".
* Las decisiones de riesgo son más transparentes: "aceptamos esta deuda técnica sabiendo que nos acerca al borde del SLO, y lo hacemos conscientemente".

Ese cambio cultural es quizá el aporte más profundo de SRE/DevSecOps:

> Transformar la operación de sistemas de una cultura de **culpa y heroísmo espontáneo** a una cultura de **experimento, medición y aprendizaje continuo**.

Y SLI/SLO/SLA más Ingeniería del Caos son las herramientas concretas para ello: miden, tensan y verifican que la confiabilidad y la seguridad no sean slogans, sino prácticas vivas.


En resumen, SRE, SLI/SLO/SLA e Ingeniería del Caos no son herramientas aisladas, sino partes de un mismo lenguaje: cómo hablar de riesgo, cambio, seguridad y confiabilidad sin caer en culpas ni heroísmos, sino en experimentos y aprendizaje continuo.
