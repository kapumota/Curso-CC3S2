### **Pipelines CI/CD en aplicaciones modernas**

En la actualidad, las organizaciones buscan entregar software con mayor rapidez y fiabilidad, apoyándose en prácticas de integración continua y entrega/despliegue continuo (CI/CD). 
Un pipeline CI/CD orquesta de forma automática cada cambio en el repositorio para compilar, probar, versionar, publicar y desplegar nuevos artefactos, como imágenes de contenedor o paquetes binarios,  minimizando la intervención manual y reduciendo el riesgo de errores al mover código entre entornos. Además, facilita aplicar controles de calidad tempranos (unitarios, de integración, de seguridad) y garantiza que la misma versión de un artefacto se reproduzca de desarrollo a producción.

#### **Estrategias de despliegue**

Para reducir el impacto de un fallo en producción, existen tres grandes técnicas:

* **Canary:** primero se actualiza una pequeña fracción de instancias (por ejemplo, un 5 % del total), exponiendo la nueva versión solo a un subconjunto de usuarios. Durante este periodo se monitorizan métricas clave, errores, latencia, consumo de recursos  y si todo transcurre dentro de los límites aceptables, se va incrementando progresivamente el porcentaje hasta el 100 %.
  En caso de anomalía, el despliegue se detiene y de ser necesario, se revierte por completo.

* **Blue-Green:** se mantienen dos entornos idénticos, "azul" y "verde". El entorno azul atiende al tráfico actual, mientras que la versión nueva se despliega y valida en el verde.
  Una vez confirmada su estabilidad, todo el tráfico se redirige de un entorno al otro, dejando la versión anterior en espera para un rollback instantáneo si se detecta un problema.

* **Rolling:** el orquestador (por ejemplo, Kubernetes, ECS o Nomad) reemplaza gradualmente las réplicas antiguas con las nuevas. Se controlan parámetros como el número máximo de pods fuera de servicio y la cantidad mínima de pods nuevos listos, de modo que la aplicación nunca pierda disponibilidad. Este enfoque equilibra velocidad de despliegue y estabilidad, permitiendo una reversión sencilla aplicando de nuevo la versión estable anterior.


#### **Rollout y gestión de revisiones**

Las plataformas de orquestación suelen llevar un historial de revisiones de despliegue. 
Con un simple comando, por ejemplo `kubectl rollout history deployment/mi-app`,  se listan las versiones previas, y con `kubectl rollout undo deployment/mi-app --to-revision=N` se restaura exactamente la revisión deseada. 
Esta capacidad de rollback inmediato reduce drásticamente el tiempo medio de recuperación (MTTR) ante cualquier incidente.


#### **Preparando tu pipeline CI/CD**

Para diseñar un pipeline genérico y reutilizable, conviene seguir estos pasos:

1. **Seleccionar la herramienta** de CI/CD adecuada (Jenkins, GitHub Actions, GitLab CI/CD, CircleCI, etc.) según tu ecosistema y necesidades.
2. **Definir las etapas** principales:

   * *Checkout:* clonar el repositorio y cargar credenciales.
   * *Build:* compilar el código y generar los artefactos (por ejemplo, imágenes Docker).
   * *Test:* ejecutar pruebas unitarias, de integración y escaneos de seguridad.
   * *Publish:* publicar los artefactos en un registro o repositorio de paquetes.
   * *Deploy:* aplicar las plantillas de infraestructura o manifiestos para desplegar la nueva versión.
3. **Gestionar secretos y variables** de entorno de forma segura, empleando vaults o gestores de secretos.
4. **Configurar notificaciones y gates**, de modo que fallos en pruebas bloqueen el despliegue y se alerte al equipo correspondiente.
5. **Habilitar rollback automático** si las métricas post-deploy superan umbrales críticos, devolviendo la aplicación a un estado saludable sin intervención manual.


#### **Revisando el archivo de configuración**

La definición de un pipeline suele residir en un único archivo de texto , por ejemplo, un `Jenkinsfile`, un `.gitlab-ci.yml` o un workflow YAML de GitHub Actions,  que se versiona junto al código. 
En él se declaran los jobs, las dependencias entre etapas, los runners o agentes, y las instrucciones precisas de compilación, test y despliegue. 
Mantener este archivo claro y modular permite adaptarlo fácilmente a nuevos microservicios o proyectos.

### **Pruebas de contenedor**

Aunque no se use una herramienta específica, todo proceso CI/CD que construya contenedores (Docker, Buildx, Kaniko, etc.) debe incluir validaciones que garanticen:

* La funcionalidad básica del servicio dentro del contenedor (por ejemplo, comprobando que el binario arranca y responde a un comando "health").
* La presencia de variables de entorno críticas (como puertos expuestos o rutas de configuración).
* La estructura de archivos: que config, certificados o scripts estén ubicados donde se espera.
* Los healthchecks definidos en el Dockerfile y validados tras el despliegue, asegurando que la plataforma orquestadora pueda detectar instancias no saludables.

Estas pruebas pueden implementarse con scripts Bash, Bats, Python o frameworks específicos; lo esencial es que se ejecuten automáticamente como parte del pipeline.

#### **Simulando un pipeline en local**

Antes de integrar un servidor CI completo, resulta muy instructivo recrear el pipeline en local, por ejemplo con un
**Makefile**:

```make
build:
    docker build -t app:local .

test: build
    docker run --rm app:local go test ./...

deploy: test
    kubectl apply -f k8s/
    kubectl rollout status deployment/app
```

Y combinándolo con herramientas como `watch` o `entr` para detectar cambios en el código y volver a lanzar `make deploy`. De este modo se comprenden y pulen los pasos individuales sin depender de infraestructuras externas.


#### **Haciendo un cambio de código**

Cada vez que se modifica el código , por ejemplo, actualizando un mensaje de bienvenida o añadiendo una nueva ruta,  se sigue el flujo: editar el archivo, confirmar en Git (`git commit`), lanzar `make test` localmente y, si pasa, `git push`. 
En tu plataforma CI, el push disparará automáticamente el pipeline completo: build, test, publish y deploy sobre el entorno de staging o producción, según tengas configurado.


#### **Probando el cambio**

Durante la ejecución automática del pipeline:

1. **Build (construir):** se construye la nueva imagen con la etiqueta asociada al commit.
2. **Test (prueba):** si cualquier prueba falla, el job se detiene y notifica al equipo.
3. **Publish (publicar):** al superar los tests, la imagen se publica en el registro.
4. **Deploy (desplegar):** se actualiza el entorno y se espera a que la implementación alcance un estado "Ready".

Los registros de cada etapa, junto con el historial de artefactos, permiten auditar con precisión dónde y por qué se produjo cualquier fallo.


#### **Probando el rollback**

Para asegurarse de que la reversión funciona:

1. **Desplegar** intencionadamente una versión con un fallo (por ejemplo, provocando un error 500 en `/health`).
2. **Observar** alertas o peticiones fallidas detectadas por tu sistema de monitorización.
3. **Ejecutar rollback** (por ejemplo, `kubectl rollout undo deployment/app`).
4. **Verificar** que la ruta `/health` vuelve a comportarse correctamente y que el tráfico regresa a las instancias estables.

Esta lectura confirma que tu estrategia de rollback está bien parametrizada y operativa en situaciones reales.

#### **Otras herramientas de CI/CD**

Más allá de las soluciones integradas en repositorios, existen plataformas especializadas:

* **Jenkins:** con infinidad de plugins, ideal para pipelines complejos, aunque requiere mantenimiento y control de versiones de plugins.
* **Argo CD:** orientado solo a Continuous Delivery en Kubernetes, sincroniza el estado del clúster con Git y trae canary/blue-green incorporados.
* **GitLab CI/CD:** profundamente integrado con GitLab, ofrece runners, gestión de secretos y entornos de review dinámicos ("Review Apps").
* **CircleCI, Travis CI, Azure DevOps, TeamCity, Bamboo:** cada uno aporta distintos modos de ejecución (cloud u on-premise) y extensiones para tareas especializadas (análisis de seguridad, serverless, etc.).

La elección debe basarse en la complejidad de tu organización, las herramientas que ya utilizas y los requisitos de escalabilidad y mantenimiento a largo plazo.

### **Entrega progresiva (*progressive delivery*) y seguridad en pipelines CI/CD**

Las estrategias de canary, blue-green y rolling son la base de los despliegues controlados. Sobre ellas se construye un enfoque más amplio llamado **entrega progresiva (*progressive delivery*)**, que combina cambios graduales, segmentación de usuarios y métricas de negocio para decidir si una versión se promueve o se revierte.

#### **De canary a entrega progresiva (*progressive delivery*)**

En un canary clásico se envía un pequeño porcentaje de tráfico a la nueva versión y se observan métricas técnicas (errores, latencia, consumo de CPU/RAM). La **entrega progresiva (*progressive delivery*)** da un paso más:

- **Define objetivos explícitos** (SLO/SLI): por ejemplo, *tasa de error < 1 %* y *latencia p95 < 300 ms*.
- **Automatiza la progresión** de tráfico: 5 % -> 25 % -> 50 % -> 100 %, siempre que las métricas se mantengan dentro de los umbrales definidos.
- **Incluye métricas de negocio**: conversión, abandono de carrito, clics, etc., no solo respuestas "200 OK".
- **Integra rollback automático**: si cualquier métrica cruza el umbral, el sistema revierte al estado previo sin esperar intervención humana.

En Kubernetes esto se implementa típicamente con herramientas como **Argo Rollouts** o **Flagger**, que se apoyan en recursos adicionales (CRDs) para definir cómo subir/bajar el porcentaje de tráfico, qué métricas observar y qué hacer en caso de fallo.

#### **Despliegues por anillos (*ring-based deployments*) y segmentación de usuarios**

El enfoque de **despliegues por anillos (*ring-based*)** organiza el despliegue en "anillos" o grupos de usuarios:

- **Ring 0:** equipo interno /QA/entornos preproducción.
- **Ring 1:** canary en producción (porcentaje pequeño de usuarios reales).
- **Ring 2:** una región o segmento mayor.
- **Ring N:** despliegue global.

Cada anillo actúa como un filtro: solo se pasa al siguiente si las métricas del anillo actual son aceptables. Esto se puede combinar con:

- **Ruteo por cabeceras** (feature flags, "beta users").
- **Service Mesh** (Istio, Linkerd), que permite repartir tráfico por peso (por ejemplo, 90 % v1, 10 % v2).
- **Segmentación geográfica** (por zona/región en el balanceador).

La idea clave es que el riesgo se controla no solo por porcentaje de tráfico, sino por **tipo de usuario**: primero personal interno, luego early adopters, después usuarios generales.

#### **Papel en un pipeline DevOps moderno**

En un pipeline CI/CD moderno, estas estrategias no son pasos aislados, sino parte del diseño global:

1. **CI (Integración continua)**  
   - Compila, prueba y analiza el código en cada cambio.
   - Genera artefactos inmutables (imágenes de contenedor, paquetes) versionados por commit/tag.

2. **CD (Entrega/Despliegue continuo)**  
   - Toma ese artefacto y define **cómo** entrar en producción:
     - Despliegue rolling para cambios pequeños y frecuentes.
     - Blue-green para cambios disruptivos o migraciones de infraestructura.
     - Canary / despliegues por anillos (*ring-based*) / entrega progresiva (*progressive delivery*) para validar hipótesis de negocio y estabilidad.

3. **Observabilidad y bucle de retroalimentación (*feedback loop*)**  
   - Integración con métricas (Prometheus), logs centralizados y trazas.
   - Reglas automáticas que deciden, a partir de ese **bucle de retroalimentación (*feedback loop*)**, si el despliegue continúa, se congela o se revierte.

4. **GitOps y trazabilidad**  
   - El estado deseado del entorno se define en repositorios Git.
   - Herramientas como Argo CD sincronizan los clústeres con lo declarado en Git.
   - Cada cambio de configuración o versión queda auditado como un *commit* más.

Así, las estrategias de despliegue se convierten en **políticas reproducibles**, no en "magia manual" ejecutada desde la consola del operador.

#### **Buenas prácticas de seguridad en CI/CD para equipos DevSecOps**

Además de fiabilidad y velocidad, un pipeline moderno debe proteger la **cadena de suministro de software**. Algunas prácticas clave:

- **Gestión segura de secretos**  
  - Nunca guardar credenciales en el repositorio.  
  - Usar *secret managers* (Vault, AWS Secrets Manager, secretos de la plataforma CI) y aplicar *least privilege* a los tokens de acceso.

- **Aislamiento y endurecimiento de *runners***  
  - Usar runners efímeros o aislados para evitar que un pipeline comprometido afecte a otros proyectos.
  - Mantener el sistema operativo y las dependencias de los runners actualizados.

- **Análisis de código y dependencias**  
  - **SAST**: análisis estático del código (búsqueda de patrones inseguros, inyecciones, etc.).
  - **SCA**: análisis de dependencias para detectar vulnerabilidades conocidas (CVE) en librerías y frameworks.
  - **DAST** (cuando aplique): pruebas dinámicas contra entornos de *staging*.

- **Seguridad de contenedores y *software supply chain***  
  - Escanear imágenes Docker en busca de vulnerabilidades y configuraciones inseguras (usuarios root, puertos innecesarios, paquetes de más).
  - Generar y almacenar **SBOM** (*Software Bill of Materials*) para saber exactamente qué se despliega.
  - Firmar imágenes y artefactos (por ejemplo, `cosign`) y verificar la firma en el entorno de despliegue.

- **Políticas como código y *gates* de seguridad**  
  - Definir políticas (OPA/Rego, Conftest, reglas específicas de la plataforma) que puedan **negar** despliegues inseguros: contenedores privilegiados, puertos abiertos al mundo, buckets públicos, etc.
  - Convertir estas políticas en pasos obligatorios del pipeline, de manera que un fallo de seguridad bloquee el "Deploy".

- **Gobernanza y auditoría**  
  - Habilitar logs de auditoría en la plataforma CI/CD (quién ejecutó qué pipeline, con qué cambios, contra qué entorno).
  - Mantener un historial de artefactos, versiones y resultados de escaneos para poder investigar incidentes a posteriori.

Integrando estas prácticas, el pipeline no solo entrega software de forma rápida y sin *downtime*, sino que se convierte en un **control de seguridad automatizado**, alineado con los principios de DevSecOps: *"security as code"*, *"shift-left"* y responsabilidad compartida entre desarrollo, operaciones y seguridad.
