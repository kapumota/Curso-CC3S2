### 1. Introducción a las historias de usuario

Las **historias de usuario** son descripciones breves de una funcionalidad del sistema desde la perspectiva del usuario final. En el desarrollo ágil, son esenciales para identificar y priorizar características que aporten valor real. Siguen una estructura narrativa estándar:

> "Como _[rol]_, quiero _[funcionalidad]_ para _[beneficio]_."

Esta fórmula destaca al actor, la funcionalidad deseada y el beneficio esperado, asegurando que el desarrollo se centre en las necesidades del usuario. Las historias fomentan la colaboración entre negocio, desarrollo, diseño y pruebas, alineando al equipo en torno a una visión compartida.

Por su brevedad, facilitan discusiones y refinamientos iterativos. En metodologías como Scrum o Kanban, se integran al backlog del producto, priorizándose según su valor y permitiendo ciclos de desarrollo cortos. 
Su flexibilidad permite actualizarlas a partir de feedback o nuevas necesidades, manteniendo el enfoque en el usuario.

**Checks prácticos:**
- ¿La historia describe un beneficio claro para el usuario?
- ¿Es lo suficientemente breve para evitar detalles técnicos excesivos?
- ¿El equipo comprende el rol, la funcionalidad y el valor?


### 2. Given-When-Then

El formato **Given-When-Then** estructura escenarios de prueba en un lenguaje claro y accesible, conectando requisitos con validaciones. Define:

- **Given (Dado que):** Contexto o estado inicial (condiciones, datos, configuraciones).
- **When (Cuando):** Acción que desencadena el comportamiento a probar.
- **Then (Entonces):** Resultado esperado tras la acción.

Este formato reduce barreras de comunicación entre equipos técnicos y no técnicos. Por ejemplo:

```gherkin
Scenario: Inicio de sesión exitoso
  Given usuario "kapumota" está registrado
  And la contraseña es correcta
  When el usuario inicia sesión
  Then el sistema muestra el dashboard principal
```

**Checks prácticos:**
- ¿El Given establece un contexto claro y reproducible?
- ¿El When describe una sola acción específica?
- ¿El Then define un resultado medible y verificable?


### 3. Importancia de las historias de usuario

Las historias de usuario son clave en el desarrollo ágil porque:

- **Centran el desarrollo en el usuario:** Priorizan necesidades reales, evitando soluciones técnicas innecesarias.
- **Fomentan colaboración:** Su lenguaje accesible alinea a negocio, desarrollo y pruebas en objetivos comunes.
- **Simplifican planificación:** Permiten estimar esfuerzo (por ejemplo, en puntos de historia) y priorizar según valor.
- **Soportan validación:** Se integran con criterios de aceptación para verificar que el sistema cumple expectativas.
- **Facilitan evolución:** Su concisión permite actualizarlas iterativamente con nuevos requisitos o feedback.

**Antipatrones comunes:**
- Historias demasiado técnicas, que pierden el enfoque en el usuario.
- Historias vagas, sin un beneficio claro o medible.

**Checks prácticos:**
- ¿La historia refleja una necesidad real del usuario?
- ¿Es comprensible para todos los involucrados?
- ¿Se puede priorizar según su valor para el negocio?


### 4. Criterios de aceptación

Los **criterios de aceptación** son condiciones específicas que determinan cuándo una historia de usuario está completa y cumple con las expectativas del usuario. Actúan como validaciones objetivas para asegurar la calidad de la funcionalidad.

#### Características
1. **Específicos y medibles:** Claros y evaluables objetivamente (por ejemplo, "El sistema muestra un mensaje de error si el correo está vacío").
2. **Centrados en el usuario:** Priorizan la experiencia y el valor práctico.
3. **Concisos:** Evitan jerga técnica innecesaria para ser entendibles por todos.
4. **Verificables:** Pueden probarse manual o automáticamente.

#### Tipos
- **Positivos:** Comportamiento en condiciones ideales (por ejemplo, "Credenciales válidas permiten acceso").
- **Negativos:** Respuesta ante errores (por ejemplo, "Contraseña incorrecta muestra un mensaje de error").
- **Maliciosos:** Pruebas de robustez (por ejemplo, "El sistema rechaza inyecciones SQL").

#### Beneficios
- Traducen criterios en escenarios de prueba automatizados.
- Reducen malentendidos al clarificar expectativas.
- Guían revisiones de stakeholders durante demostraciones.

**Antipatrones comunes:**
- Criterios ambiguos o no verificables (por ejemplo, "El sistema debe ser rápido").
- Múltiples acciones combinadas en un solo criterio, complicando la validación.

**Checks prácticos:**
- ¿Cada criterio es medible y verificable?
- ¿Se centra en la experiencia del usuario?
- ¿Es claro para todos los miembros del equipo?



### 5. Introducción a BDD (Behavior Driven Development)

**BDD** (Desarrollo Guiado por Comportamiento) es una metodología ágil que extiende el TDD, enfocándose en el comportamiento del sistema desde la perspectiva del usuario. Utiliza especificaciones ejecutables en lenguaje natural para definir cómo debe actuar el software, promoviendo colaboración entre desarrolladores, testers y negocio.

En BDD, las historias de usuario se convierten en escenarios que se automatizan como pruebas, asegurando que el sistema cumpla con los requisitos. La comunicación continua y la retroalimentación iterativa refinan los escenarios, manteniendo el software alineado con las expectativas.

**Checks prácticos:**
- ¿Los escenarios reflejan comportamientos observables del sistema?
- ¿Involucran a todos los roles (desarrollo, pruebas, negocio)?
- ¿Se actualizan con nuevos aprendizajes o feedback?


### 6. Gherkin

**Gherkin** es un lenguaje de dominio específico para escribir escenarios de BDD en un formato legible y estructurado. Permite que equipos técnicos y no técnicos definan comportamientos que luego se automatizan con herramientas como Cucumber.

#### Sintaxis
- **Feature:** Agrupa escenarios relacionados con una funcionalidad.
- **Scenario:** Describe un caso específico con Given-When-Then.
- **And/But:** Añaden detalles a cada sección.

Ejemplo:

```gherkin
Feature: Autenticación de usuario
  Scenario: Inicio de sesión válido
    Given  el usuario "motita" está registrado
    And la contraseña es "contrasena123"
    When el usuario inicia sesión
    Then el sistema muestra "Bienvenida, motita"
```

**Checks prácticos:**
- ¿El escenario tiene un solo When para una acción clara?
- ¿Es comprensible para no técnicos?
- ¿La Feature agrupa escenarios coherentes?


**Etiquetado (tags) en Gherkin**
Los *tags* permiten agrupar o filtrar escenarios en CI/CD. Se declaran en la línea anterior a `Feature` o `Scenario`, comienzan con `@` y se pueden combinar.

```gherkin
@feature @auth
Feature: Autenticación de usuario
  Como usuario registrado, quiero iniciar sesión para acceder a mi cuenta.

  @smoke @positivo @ui
  Scenario: Inicio de sesión válido
    Given  usuario "kapu" está registrado
    And la contraseña es "pass123"
    When el usuario inicia sesión
    Then el sistema muestra el dashboard

  @negativo @seguridad
  Scenario: Rechazo de inyección SQL en usuario
    Given usuario "admin' OR '1'='1" intenta iniciar sesión
    When el sistema procesa la solicitud
    Then el sistema rechaza la solicitud
    And registra un intento de ataque

  @performance @load
  Scenario: Soporte a 1000 usuarios concurrentes
    Given 1000 usuarios intentan iniciar sesión simultáneamente
    When el sistema procesa las solicitudes
    Then el tiempo de respuesta promedio es menor a 2 segundos
    And no se producen errores 500
```

### 7. BDD en Python con Behave

**Behave** es una herramienta Python para implementar BDD, conectando escenarios Gherkin con código Python para pruebas automatizadas. Vincula historias de usuario con validaciones, mejorando la trazabilidad y adaptabilidad.

#### Estructura de un proyecto Behave
- **Features:** Archivos `.feature` con escenarios Gherkin.
- **Steps:** Archivos Python que mapean pasos a funciones.
- **Configuración:** Archivos para parámetros o hooks.

#### Expresiones regulares
Behave usa expresiones regulares para capturar parámetros dinámicos, haciendo los pasos reutilizables:

```python
from behave import given

@given(r'Dado que el usuario "([^"]+)" está registrado')
def step_impl(context, username):
    context.username = username
```

**Checks prácticos:**
- ¿Los pasos son reutilizables con expresiones regulares?
- ¿La estructura del proyecto es clara y modular?
- ¿Los escenarios se mapean correctamente a funciones Python?

**Ejecución por tags**
Puedes filtrar escenarios por tags:

* Solo *smoke*: `behave -t @smoke`
* Excluir *wip*: `behave -t ~@wip`
* Varios tags (AND): `behave -t @ui -t @negativo`
* Cualquiera de varios (OR): `behave -t "@smoke or @regression"`
  
### 8. Hilo rojo end-to-end

A continuación, un ejemplo práctico que conecta una historia de usuario con su implementación y verificación:

1. **Historia de usuario:**
   > Como usuario registrado, quiero iniciar sesión en el sistema para acceder a mi cuenta personal.

2. **Criterios de aceptación:**
   - Si las credenciales son válidas, el sistema muestra el dashboard.
   - Si la contraseña es incorrecta, se muestra un mensaje de error.
   - El sistema bloquea el acceso tras tres intentos fallidos.

3. **Escenario Gherkin:**
   ```gherkin
   Feature: Autenticación de usuario
     Scenario: Inicio de sesión con credenciales válidas
       Given que el usuario "kapu" está registrado
       And la contraseña es "pass123"
       When el usuario inicia sesión
       Then el sistema muestra el dashboard
   ```

4. **Paso Behave con regex:**
   ```python
   from behave import given, when, then

   @given(r'que el usuario "([^"]+)" está registrado')
   def step_user_registered(context, username):
       context.user = {"username": username, "registered": True}

   @given(r'la contraseña es "([^"]+)"')
   def step_password_set(context, password):
       context.password = password

   @when(r'el usuario inicia sesión')
   def step_user_logs_in(context):
       context.result = login(context.user, context.password)

   @then(r'el sistema muestra el dashboard')
   def step_dashboard_shown(context):
       assert context.result == "dashboard", "Expected dashboard, but got {}".format(context.result)
   ```

5. **Nota de verificación:**
   Este escenario se ejecuta automáticamente con Behave, validando que el sistema cumple el criterio positivo de la historia. Las pruebas de integración y sistema verifican la conexión con la base de datos y la interfaz, mientras que las pruebas unitarias aseguran que la función `login` procesa correctamente las credenciales.


### 9. Cuatro niveles de prueba

 Se asegura una validación completa del sistema mediante cuatro niveles de pruebas, cada una con un propósito y responsable claros:

1. **Pruebas unitarias** (Desarrolladores): Verifican funciones o métodos individuales, detectando errores en componentes aislados.
2. **Pruebas de integración** (Desarrolladores/Testers): Validan la interacción entre módulos, asegurando un comportamiento coherente.
3. **Pruebas de sistema** (Testers): Evalúan el sistema completo en condiciones cercanas a producción, verificando requisitos funcionales y no funcionales.
4. **Pruebas de aceptación** (Testers/Stakeholders): Confirman que los criterios de aceptación de las historias de usuario se cumplen, usando escenarios Gherkin automatizados.

#### Beneficios en BDD
- Cobertura exhaustiva, desde unidades hasta comportamientos de usuario.
- Retroalimentación temprana mediante CI/CD.
- Documentación viva con escenarios Gherkin.
- Soporte para refactorización segura.

#### Buenas prácticas
- Escenarios Gherkin concisos y reutilizables con parámetros dinámicos.
- Automatización en pipelines CI/CD.
- Código modular para facilitar pruebas.
- Revisión iterativa de escenarios con stakeholders.
- Reportes de pruebas para monitoreo.

**Antipatrones comunes:**
- Escenarios con múltiples acciones en un solo When, dificultando la claridad.
- Criterios de aceptación no verificables o demasiado subjetivos.

**Checks prácticos:**
- ¿Las pruebas cubren los cuatro niveles de prueba?
- ¿Los escenarios son modulares y reutilizables?
- ¿Los reportes de pruebas son claros para todos los involucrados?


### 10. Integración de historias de usuario y BDD en pipelines CI/CD

En un entorno DevOps, las historias de usuario y los escenarios Gherkin se integran en pipelines de integración continua/entrega continua (CI/CD) para automatizar la validación y despliegue del software. 
Esto asegura que cada cambio en el código cumpla con los criterios de aceptación antes de llegar a producción.


#### Prácticas clave
- **Suites por tags**: el pipeline ejecuta *smoke* en cada commit (`-t @smoke`), *regression* en PRs (`-t @regression`) y *performance* bajo demanda (`-t @performance`) para equilibrar velocidad y cobertura.
- **Automatización de pruebas:** Los escenarios Gherkin definidos en BDD (usando herramientas como Behave o Cucumber) se ejecutan automáticamente en el pipeline CI/CD tras cada commit o pull request. Esto valida que las historias de usuario se implementen correctamente.
- **Feedback rápido:** Los pipelines proporcionan reportes inmediatos de pruebas (unitarias, de integración, de sistema y de aceptación) para identificar errores temprano.
- **Despliegue continuo:** Una vez validadas las historias de usuario, el pipeline puede desplegar automáticamente a entornos de prueba, staging o producción, dependiendo de la configuración.
- **Trazabilidad:** Los resultados de las pruebas Gherkin se vinculan a historias de usuario en herramientas como Jira o Azure DevOps, asegurando que los requisitos del usuario se cumplen en cada despliegue.

#### Herramientas Comunes
- **CI/CD:** Jenkins, GitHub Actions, GitLab CI/CD, CircleCI.
- **Gestión de requisitos:** Jira, Trello, Azure DevOps.
- **Automatización de pruebas:** Behave, Cucumber, Selenium, pytest.
- **Monitoreo de pipelines:** Los reportes de pruebas se integran con herramientas como Allure o TestRail para facilitar la revisión por parte de stakeholders.

#### Ejemplo de pipeline con Behave
Un pipeline en GitHub Actions para ejecutar pruebas BDD podría configurarse así:

```yaml
name: CI Pipeline with Behave
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install behave
    - name: Run Behave tests
      run: behave features/
    - name: Publish test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: reports/
```

**Checks prácticos:**
- ¿El pipeline ejecuta automáticamente pruebas Gherkin para validar historias de usuario?
- ¿Los reportes de pruebas son accesibles y claros para todos los equipos?
- ¿El pipeline asegura que solo los cambios validados se despliegan?


### 11. Infraestructura como Código (IaC) para soporte de historias de usuario

En DevOps, la infraestructura como código (IaC) permite gestionar entornos de prueba y producción de manera reproducible, lo que es crucial para validar historias de usuario en diferentes contextos.

#### Relación con historias de usuario
- **Entornos consistentes:** IaC (usando herramientas como Terraform, Ansible o AWS CloudFormation) asegura que los entornos de prueba reflejen producción, permitiendo que las pruebas Gherkin sean confiables.
- **Escalabilidad:** Las historias de usuario que requieren pruebas de carga o rendimiento (por ejemplo, "Como usuario, quiero que la página cargue en menos de 2 segundos") se validan en entornos escalables creados con IaC.
- **Automatización:** Los entornos se crean o destruyen automáticamente en el pipeline CI/CD, alineándose con los ciclos de desarrollo ágil.

#### Ejemplo con Terraform
Un archivo Terraform para crear un entorno de prueba podría incluir:

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "test_env" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  tags = {
    Name = "Test-Environment-BDD"
  }
}

output "instance_ip" {
  value = aws_instance.test_env.public_ip
}
```

**Checks prácticos:**
- ¿El entorno de prueba refleja las condiciones de producción?
- ¿La infraestructura se crea/destruye automáticamente para optimizar costos?
- ¿Los escenarios Gherkin se ejecutan en entornos gestionados por IaC?


### 12. Monitoreo y feedback continuo en producción

DevOps enfatiza el monitoreo continuo para asegurar que las historias de usuario entreguen valor en producción. Esto implica medir el comportamiento del sistema y recopilar feedback de usuarios reales.

#### Enfoque
- **Monitoreo de métricas:** Herramientas como Prometheus, Grafana o New Relic rastrean métricas clave (por ejemplo, tiempo de respuesta, tasa de errores) vinculadas a los criterios de aceptación de las historias de usuario.
- **Feedback del usuario:** Las historias de usuario pueden incluir criterios para monitorear la experiencia del usuario en producción (por ejemplo, "El 95% de los usuarios deben completar el flujo de registro sin errores").
- **Alertas automatizadas:** Configurar alertas para detectar desviaciones en los criterios de aceptación (por ejemplo, fallos en el inicio de sesión).
- **Logs centralizados:** Herramientas como ELK Stack o Datadog permiten rastrear problemas relacionados con escenarios Gherkin en producción.

#### Ejemplo de métrica
Para la historia "Como usuario registrado, quiero iniciar sesión en el sistema para acceder a mi cuenta personal", se pueden monitorear:
- Tasa de éxito de inicios de sesión.
- Tiempo promedio de respuesta del endpoint de autenticación.
- Errores 500 o 401 en el sistema.

**Checks prácticos:**
- ¿Las métricas monitoreadas reflejan los criterios de aceptación de las historias?
- ¿El feedback de producción se usa para actualizar historias de usuario?
- ¿Las alertas son accionables y específicas?

### 13. Colaboración DevOps en historias de usuario

DevOps fomenta una cultura de colaboración entre desarrollo, operaciones y otros equipos. Las historias de usuario y los escenarios Gherkin actúan como un lenguaje común para alinear a todos los involucrados.

#### Prácticas
- **Revisión conjunta:** Los equipos de operaciones participan en la definición de criterios de aceptación para incluir requisitos no funcionales (por ejemplo, "El sistema soporta 1000 usuarios concurrentes").
- **Automatización de despliegues:** Operaciones colabora en la configuración de pipelines CI/CD para asegurar que los despliegues sean rápidos y seguros.
- **Documentación viva:** Los escenarios Gherkin sirven como documentación ejecutable, accesible para desarrollo, operaciones y negocio.
- **Retrospección:** Las retrospectivas ágiles incluyen a operaciones para identificar mejoras en el proceso de desarrollo y despliegue.

**Checks prácticos:**
- ¿Los equipos de operaciones están involucrados en la definición de historias y criterios?
- ¿Los escenarios Gherkin son accesibles y comprensibles para todos?
- ¿Las retrospectivas incluyen feedback sobre despliegues y monitoreo?

### 14. Seguridad en historias de usuario (DevSecOps)

Incorporar seguridad en las historias de usuario asegura que el sistema sea robusto frente a amenazas. Esto es clave en DevOps bajo el enfoque de DevSecOps.

#### Enfoque
- **Criterios de aceptación de seguridad:** Incluir criterios como "El sistema rechaza inyecciones SQL" o "Las credenciales se almacenan cifradas".
- **Pruebas de seguridad automatizadas:** Usar herramientas como OWASP ZAP o Snyk en el pipeline para validar escenarios de seguridad definidos en Gherkin.
- **Monitoreo de vulnerabilidades:** Escanear imágenes de contenedores (por ejemplo, con Trivy) y dependencias en cada despliegue.

#### Ejemplo de escenario Gherkin
```gherkin
Feature: Seguridad en autenticación
  Scenario: Prevención de inyecciones SQL
    Given que el usuario intenta iniciar sesión con una entrada maliciosa
    When el sistema procesa la entrada
    Then el sistema rechaza la solicitud
    And registra un intento de ataque
```

**Checks prácticos:**
- ¿Las historias incluyen criterios de seguridad claros?
- ¿El pipeline ejecuta pruebas de seguridad automatizadas?
- ¿Se monitorean vulnerabilidades en producción?


### 15. Escalabilidad y rendimiento en historias de usuario

DevOps también aborda requisitos no funcionales como escalabilidad y rendimiento, que pueden integrarse en las historias de usuario y validarse mediante pruebas automatizadas.

#### Enfoque
- **Historias no funcionales:** Definir historias como "Como administrador, quiero que el sistema soporte 1000 usuarios concurrentes para garantizar una experiencia fluida".
- **Pruebas de carga:** Usar herramientas como JMeter o Locust para validar criterios de rendimiento en entornos gestionados por IaC.
- **Optimización continua:** Monitorear métricas de rendimiento en producción y ajustar la infraestructura según feedback.

#### Ejemplo de Escenario Gherkin
```gherkin
Feature: Escalabilidad del sistema
  Scenario: Soporte de múltiples usuarios concurrentes
    Given que 1000 usuarios intentan iniciar sesión simultáneamente
    When el sistema procesa las solicitudes
    Then el tiempo de respuesta promedio es menor a 2 segundos
    And no se producen errores 500
```

**Checks prácticos:**
- ¿Las historias incluyen criterios de rendimiento y escalabilidad?
- ¿Las pruebas de carga están integradas en el pipeline?
- ¿El monitoreo en producción valida estos criterios?


### 16. Buenas prácticas DevOps para historias de usuario

Para alinear las historias de usuario con los principios de DevOps, se pueden adoptar las siguientes prácticas:

- **Automatización total:** Automatizar pruebas, despliegues, y monitoreo para reducir errores manuales.
- **Entrega incremental:** Dividir historias grandes en historias más pequeñas para facilitar despliegues frecuentes.
- **Cultura de colaboración:** Involucrar a todos los equipos (desarrollo, operaciones, seguridad, negocio) en la definición y validación de historias.
- **Observabilidad:** Usar herramientas de monitoreo para vincular el comportamiento en producción con los criterios de aceptación.
- **Mejora continua:** Iterar sobre historias de usuario y escenarios Gherkin con base en feedback de producción y retrospectivas.

**Antipatrones comunes:**
- Pipelines CI/CD sin pruebas automatizadas de historias de usuario.
- Entornos de prueba inconsistentes con producción.
- Falta de monitoreo para validar criterios de aceptación en producción.

**Checks prácticos:**
- ¿El proceso asegura entregas frecuentes y seguras?
- ¿Los equipos colaboran efectivamente en las historias?
- ¿El feedback de producción se refleja en nuevas historias?


### 17. Ejemplo de Hilo Rojo DevOps

Un ejemplo práctico que conecta una historia de usuario con DevOps:

1. **Historia de usuario:**
   > Como usuario registrado, quiero iniciar sesión en el sistema para acceder a mi cuenta personal.

2. **Criterios de aceptación:**
   - Las credenciales válidas permiten acceso al dashboard.
   - La contraseña incorrecta muestra un mensaje de error.
   - El sistema soporta 1000 inicios de sesión concurrentes con un tiempo de respuesta menor a 2 segundos.

3. **Escenario Gherkin:**
   ```gherkin
   Feature: Autenticación de usuario
     Scenario: Inicio de sesión con credenciales válidas
       Given usuario "kapu" está registrado
       And la contraseña es "pass123"
       When el usuario inicia sesión
       Then el sistema muestra el dashboard
     Scenario: Soporte a carga alta
       Given 1000 usuarios intentan iniciar sesión simultáneamente
       When el sistema procesa las solicitudes
       Then el tiempo de respuesta promedio es menor a 2 segundos
   ```

4. **Pipeline CI/CD:**
   - Ejecuta pruebas unitarias, de integración y Gherkin con Behave.
   - Despliega un entorno de prueba con Terraform.
   - Valida rendimiento con JMeter.
   - Escanea vulnerabilidades con OWASP ZAP.
   - Despliega a producción si todas las pruebas pasan.

5. **Monitoreo en producción:**
   - Configura Prometheus para rastrear el tiempo de respuesta y errores.
   - Usa alertas para detectar fallos en el inicio de sesión.
   - Recopila feedback de usuarios para iterar en la historia.

**Checks prácticos:**
- ¿El pipeline cubre todos los niveles de prueba y seguridad?
- ¿El monitoreo valida los criterios de aceptación en producción?
- ¿El feedback se usa para mejorar historias futuras?


**Checks prácticos finales:**
- ¿El proceso de DevOps soporta la entrega continua de historias de usuario?
- ¿Los equipos colaboran en todas las fases, desde la definición hasta el monitoreo?
- ¿Las herramientas y prácticas aseguran calidad, seguridad y escalabilidad?

