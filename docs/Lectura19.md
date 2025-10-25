### Seguridad en Infrastructure as Code (IaC) para DevSecOps

Este informe proporciona un marco completo para integrar seguridad en IaC, con explicaciones claras de conceptos como **cadena de suministro**, **SBOM** y **secretos**, y con controles prácticos para DevSecOps.

### Seguridad y cumplimiento (shift-left real)

### Cadena de suministro (Supply Chain)

**Definición**: La cadena de suministro en IaC comprende los procesos, herramientas y dependencias involucradas en la creación, distribución y consumo de código de infraestructura (por ejemplo, módulos de Terraform, **proveedores**, scripts). Una cadena de suministro insegura puede introducir vulnerabilidades o código malicioso y comprometer entornos completos.

**Controles clave**:

* **SBOM (Lista de materiales de software)**

  * **¿Qué es?**: Un SBOM es un inventario estructurado que lista todos los componentes de software de un módulo o plantilla IaC, incluidas dependencias como **proveedores**, versiones y orígenes. Es análogo a una lista de ingredientes del software.
  * **Implementación**: Generar el SBOM con **Syft**; escanear vulnerabilidades con **Grype** (puede consumir el SBOM). Para módulos Terraform, incluir **proveedores** como `aws ~> 4.0` y sus orígenes (por ejemplo, el registro de HashiCorp). Versionar y auditar el SBOM en cada **lanzamiento**.
  * **Ejemplo**: Un módulo Terraform para un bucket S3 incluiría en su SBOM el **proveedor** AWS, su versión, el hash del archivo y cualquier módulo anidado.

* **Verificación de proveedores (sumas de verificación)**

  * **¿Qué es?**: Los **proveedores** (AWS, Azure, etc.) son binarios descargados desde registros. Verificar sus sumas de verificación garantiza que no han sido manipulados.
  * **Implementación**: Usar `terraform providers lock` para generar un archivo de **bloqueo** con sumas de verificación. En CI, validar que los **proveedores** descargados coincidan con ese archivo.
  * **Ejemplo**: `terraform init --lockfile=readonly` falla si el hash del **proveedor** no coincide.

* **SLSA y procedencia de artefactos**

  * **¿Qué es?**: **SLSA** es un marco para asegurar la integridad de artefactos mediante metadatos de **procedencia** que documentan cómo y quién creó el artefacto.
  * **Implementación**: Generar **procedencia** con **Cosign** o **in-toto**, registrando el commit SHA, el repositorio Git y el pipeline que produjo el módulo. Almacenar en un registro seguro (por ejemplo, un Terraform Registry privado).
  * **Ejemplo**: Un módulo firmado incluye un JSON de procedencia con el commit SHA y el **pipeline** que lo generó.

* **Firma de versiones y política de "solo etiquetas firmadas"**

  * **¿Qué es?**: Firmar versiones asegura que los módulos consumidos son auténticos. La política de **solo etiquetas firmadas** prohíbe usar versiones no verificadas en producción.
  * **Implementación**: Firmar versiones con **GPG** o **Cosign**. **Forzar** en CI que solo se consuman etiquetas firmadas (por ejemplo, GitHub Actions verifica la firma antes de `terraform apply`).
  * **Ejemplo**: El pipeline falla si la etiqueta `v1.0.0` no tiene una firma GPG válida.

* **Cadena de suministro cerrada**

  * **Espejo interno de proveedores y módulos**: Mantener un **mirror** interno capaz de operar en modo aislado para **proveedores** y módulos; configurar `provider_installation` en Terraform para apuntar al espejo.
  * **`.terraform.lock.hcl` de solo lectura en CI**: Forzar el archivo de bloqueo como solo lectura para evitar cambios no autorizados.
  * **Objetivo SLSA**: Alcanzar **SLSA ≥ 2** de inmediato y **SLSA ≥ 3** **antes del 30/04/2026**, con política de **"solo consumir del registro interno"** para aislarse de fuentes externas.
  * **Archivo de configuración de la CLI para mirrors**: Configurar espejos en el archivo de configuración de Terraform CLI (`~/.terraformrc` o `~/.terraform.d/config.tfrc`).
  * **Ejemplo de configuración de Terraform CLI**:

    ```hcl
    provider_installation {
      filesystem_mirror {
        path    = "/internal/terraform/mirror"
        include = ["*/*"]
      }
      direct {
        exclude = ["*/*"]
      }
    }
    ```

    Esta configuración asegura que Terraform solo consuma **proveedores** desde el **mirror** interno.


### Secretos

**Definición**: Los **secretos** (*secrets*) son datos sensibles, por ejemplo, claves de API, contraseñas y *tokens* que, si se exponen, pueden comprometer la seguridad. En IaC, suelen aparecer en variables, archivos de configuración o scripts.

**Controles clave**:

* **Gestión centralizada**

  * **Qué es**: Centralizar la gestión de secretos en servicios como **AWS KMS**, **AWS Secrets Manager**, **Google Secret Manager** y **Azure Key Vault** evita *hardcoding* y facilita auditoría y rotación.
  * **Implementación**: Almacenar secretos en **AWS Secrets Manager** e inyectarlos en tiempo de ejecución mediante **variables de entorno** o integraciones (por ejemplo, el recurso de Terraform `aws_secretsmanager_secret`). Usar **roles IAM** para limitar el acceso.
  * **Ejemplo**: Un secreto almacenado en AWS Secrets Manager se recupera como `data.aws_secretsmanager_secret_version.my_secret`.

* **Rotación y detección de secretos en commits**

  * **Qué es**: Rotar secretos con regularidad (por ejemplo, cada 90 días) reduce el riesgo de exposición. Detectar secretos en commits evita filtraciones accidentales.
  * **Implementación**: Usar *hooks* **pre-commit** con **GitGuardian** o **TruffleHog** para escanear antes de *push*. En CI, configurar verificaciones que **fallen** si se detectan secretos. Automatizar la rotación con scripts o con el *scheduler* del gestor de secretos.
  * **Ejemplo**: Un *hook* pre-commit bloquea un commit que contiene `AWS_ACCESS_KEY_ID` en un archivo `.tf`.

* **Ámbito mínimo y rotación verificable**

  * **Ámbito mínimo (por entorno)**: Los secretos deben tener alcance por entorno (*env-scoped*). El secreto solo es válido/visible en `dev`, `staging` o `prod`. Recomendado: *namespacing* por entorno en el gestor (por ejemplo, `prod/db/password`), **políticas IAM** separadas con condiciones por entorno, **claves KMS** distintas por entorno y **protecciones** por entorno en CI/GitHub Environments.

  * **TTL (Time To Live)**: Usar secretos y *tokens* de **corta duración** (por ejemplo, 5-60 min) para reducir la ventana de ataque. Preferir **AWS STS**, **GCP Workload Identity / SA impersonation** o **credenciales federadas de Azure**. Habilitar rotación automática y agregar verificaciones en CI que fallen si se detectan secretos con **edad > 90 días**.

  * **Preferir *token exchange* sobre llaves estáticas**: En vez de llaves de larga vida, intercambiar identidad por *tokens* temporales bajo demanda. Ejemplos: **GitHub Actions OIDC -> AWS STS AssumeRole**, **Kubernetes ServiceAccount -> GCP Workload Identity**, **OAuth 2.0 client credentials**. Ventajas: revocación simple, menor superficie (no persistir secretos) y auditoría granular (cada emisión queda trazada).

  * **Rotación comprobable**: Medir **% de secretos rotados en < 90 días** en tableros. Incluir **pruebas de revocación** posteriores a la rotación (las llaves antiguas deben fallar).

  * **No exponer secretos en *outputs* ni en el plan**: Validación con **OPA/Conftest** que falle si un *output* puede contener un secreto (por ejemplo, patrones sensibles).

  * **Ejemplo de política OPA para bloquear *outputs* con posibles secretos**:

    ```rego
    package terraform

    # Requiere entrada tipo tfplan para Conftest/OPA
    deny[msg] {
      some k
      output := input.planned_values.outputs[k]
      val := output.value
      is_string(val)
      re_match("(?i)(key|secret|password|token|api[_-]?key)", val)
      msg := sprintf("El output '%s' puede contener un secreto sensible", [k])
    }
    ```

    Integra en **Conftest** para fallar *plans* con *outputs* riesgosos.

### IAM con privilegio mínimo

**Definición**: El principio de **privilegio mínimo** (*least privilege*) garantiza que las identidades, humanas o de máquina solo cuenten con los permisos estrictamente necesarios para su función.

**Controles clave**

* **Módulos con perfiles de permisos predeterminados**

  * **Qué es**: Los módulos IaC deben incluir **políticas IAM mínimas por defecto**, configurables mediante variables.

    * **"Perfiles de permisos predeterminados"**: Conjunto base y **estricto** de permisos que entrega el módulo por defecto; se puede **ampliar de forma controlada** mediante variables, estandarizando el principio de privilegio mínimo.
  * **Implementación**: Diseñar módulos con **roles/políticas predefinidos** (por ejemplo, solo `s3:PutObject`/`s3:GetObject` sobre un bucket específico). Permitir **ajustes controlados** (antes "overrides") vía variables con límites y revisión.

    * **"Ajustes controlados"**: Mecanismo para modificar valores por defecto **de forma delimitada y auditable**, evitando que un cambio de variables abra permisos excesivos sin revisión.
  * **Ejemplo**: Un módulo de S3 define una política que permite `s3:GetObject` en un prefijo concreto y **no** permite `s3:DeleteBucket`.
* **Analizadores de políticas y pruebas de acceso negativas**

  * **Qué es**: Los **analizadores estáticos** (linters) detectan permisos excesivos; las **pruebas negativas** verifican que accesos no autorizados **fallen** como se espera.
  * **Implementación**: Ejecutar **tfsec** o **Checkov** en CI para analizar políticas y configuraciones; complementar con **Conftest/OPA** o **AWS IAM Access Analyzer/Policy Sentry** para validar condiciones de acceso. Incluir pruebas (por ejemplo, en `terraform test` + evaluaciones de políticas) que confirmen que operaciones no permitidas como `s3:DeleteBucket` resulten denegadas.


### Cifrado y PKI

**Definición**: El **cifrado** protege datos **en reposo** (por ejemplo, discos) y **en tránsito** (por ejemplo, redes). La **PKI (Infraestructura de Clave Pública)** gestiona claves y certificados para **autenticación** y **cifrado**.

* **"En reposo" (at rest)**: Datos almacenados (discos, bases de datos, snapshots) protegidos mediante cifrado en el medio de almacenamiento.
* **"En tránsito" (in transit)**: Datos que viajan por redes entre clientes y servicios, protegidos por protocolos como **TLS**.
* **"PKI"**: Conjunto de procesos y componentes que **emiten**, **validan** y **revocan** certificados digitales; administran **autoridades certificadoras** y **pares de claves** pública/privada.

**Controles clave**

* **Cifrado por defecto en reposo y en tránsito**

  * **¿Qué es?**: Cifrar datos almacenados y datos en movimiento de forma predeterminada.
  * **Implementación**: Configurar recursos (por ejemplo, **S3** o **RDS**) con cifrado por defecto (**AES-256**). Forzar el cumplimiento mediante políticas que impidan degradar la seguridad; por ejemplo, **rechazar** conexiones sin **TLS** moderno (**TLS 1.3+**) en **APIs** y **endpoints**.

    * **"TLS 1.3+"**: Versión 1.3 o superior del protocolo TLS, que mejora privacidad y rendimiento respecto de versiones anteriores.
    * **"APIs" y "endpoints"**: Interfaces y puntos de acceso de red por donde los clientes consumen servicios; deben exigir TLS para proteger credenciales y datos.
  * **Ejemplo**: Recurso `aws_s3_bucket` con `server_side_encryption_configuration` habilitado.

* **Claves administradas con AWS Key Management Service (KMS), rotación y políticas de clave opinadas**

  * **¿Qué es?**: **AWS KMS** gestiona claves criptográficas con políticas estrictas y **rotación** programada. Las políticas de clave con postura explícita y restrictiva definen quién puede **usar**, **administrar** y **rotar** la clave, evitando configuraciones laxas.
  * **Implementación**: Usar **KMS** para claves con políticas que **denieguen** acceso no autorizado. **Rotar** claves **anualmente** o tras incidentes, con auditoría vía **AWS CloudTrail**.

    * **"Rotación"**: Reemplazar claves de cifrado por otras nuevas de forma periódica o tras incidentes para reducir riesgo por exposición.
    * **"CloudTrail"**: Servicio de auditoría de AWS que registra uso de APIs y cambios de configuración, útil para trazabilidad y cumplimiento.
  * **Ejemplo**: Política KMS que permite `kms:Decrypt` únicamente a un rol específico.


#### Regulación

**Definición**: Cumplir con **ISO/IEC 27001**, **NIST** y **PCI DSS** implica alinear controles de seguridad con estándares específicos y gestionar **excepciones** formalmente.

* **"ISO/IEC 27001"**: Norma para sistemas de gestión de seguridad de la información, con controles y procesos para proteger activos.
* **"PCI DSS"**: Estándar de seguridad para la industria de tarjetas de pago que regula la protección de datos de titulares y la operación de los sistemas que los procesan.

**Controles clave**

* **Mapear "gates" de pipeline a controles**

  * **¿Qué es?**: Cada **gate** del pipeline debe corresponder a un control regulatorio.

    * **"Gates"**: Puntos de verificación que deben aprobarse para avanzar (por ejemplo, **escaneo de secretos** o verificación de **cifrado**).
    * **"Pipeline"**: Flujo automatizado de construcción, validación y despliegue que integra pruebas, análisis y controles de seguridad.
  * **Implementación**: Crear una **matriz** que asocie gates (por ejemplo, *secrets scan*) con controles (por ejemplo, **ISO Anexo A** control de criptografía, o **NIST SP 800-53 SC-28** para protección de información en reposo mediante cifrado y gestión de claves).

    * **"Secrets scan"**: Escaneo automatizado de repositorios y artefactos para detectar credenciales, claves o tokens expuestos y **fallar** si se encuentran.
  * **Ejemplo**: El gate de **cifrado en reposo** se mapea a **NIST SC-28**.

* **Proceso de excepciones con vencimiento (time-boxed risk acceptance)**

  * **¿Qué es?**: Excepciones que permiten **desviaciones temporales** de políticas con un vencimiento definido y condiciones claras.

    * **"Time-boxed risk acceptance"**: Aceptación consciente de un riesgo por un **periodo limitado** y documentado, con fecha de expiración y revisión.
  * **Implementación**: Gestionar excepciones en un sistema de tickets (por ejemplo, **Jira**), con vencimiento de **30-90 días** y **auditoría trimestral**.


#### Estado y backend de Terraform

**Definición**: El **estado de Terraform** representa el mapa fuente->recurso de la infraestructura. **Un backend seguro** es crítico para evitar **corrupción**, **filtraciones** o **accesos no autorizados**.

**Controles clave**:

* Usar **backends cifrados** (S3 con **AWS KMS** y **Object Lock (WORM)**, Azure Storage, o GCS), habilitando **versionado** del bucket/contenedor.
* Implementar **locking** (por ejemplo, **DynamoDB** en AWS) o mecanismos equivalentes para **prevenir aplicaciones simultáneas de `terraform apply`**.
* Usar **workspaces** para segregar estados y aplicar **principio de privilegio mínimo** (roles diferenciados para **plan** vs **apply**).
* **Solo** los **roles de CI** pueden ejecutar cambios en infraestructura; las personas **solo** generan **planes** mediante **cuentas de emergencia (*break-glass*) con MFA y expiración**. **Oculta** salidas sensibles en **planes y logs**.
* **Evidencia**: **hash** del archivo de estado (SHA-256), **trazas de lock/unlock**, y **traza de plan/apply** (por ejemplo, con **AWS CloudTrail**).
* **Ejemplo** (backend en `main.tf`):

  ```hcl
  terraform {
    backend "s3" {
      bucket         = "tf-state"
      key            = "prod.tfstate"
      dynamodb_table = "tf-locks"
      encrypt        = true
    }
  }
  ```

#### Brechas y cómo cerrarlas

**Definición**: Las **brechas** en IaC son debilidades que exponen la infraestructura a riesgos. **Detectarlas y cerrarlas** mantiene una postura de seguridad robusta.

**Brechas comunes y cierres**:

* **Brecha: Falta de validación en la cadena de suministro** (dependencias no verificadas).

  * **Cierre**: Implementar **SBOM**, **checksums** y **SLSA** en todos los módulos. Añadir **gates de CI** que bloqueen despliegues sin verificación.
* **Brecha: Exposición de secretos en repositorios** (historial con *hardcode*).

  * **Cierre**: Escanear con **TruffleHog**; **rotar** secretos detectados. Forzar **pre-commit hooks** y **gates** en CI.
* **Brecha: IAM sobredimensionado** (permisos excesivos).

  * **Cierre**: **Linters** automáticos (por ejemplo, `tfsec`) y **pruebas negativas** en cada PR; revisión periódica con **IAM Access Analyzer**.
* **Brecha: Cifrado inconsistente** (en reposo/tránsito).

  * **Cierre**: Definir **defaults seguros** en módulos y validar con **OPA/Conftest**; monitorear **post-deploy** con **CSPM** para *drift*.
* **Brecha: Cumplimiento no documentado**.

  * **Cierre**: Mantener una **matriz viva** de **gates ↔ controles** con revisiones trimestrales y **evidencia automatizada**.
* **Brecha: *Drift* no gestionado** (cambios manuales fuera de IaC).

  * **Cierre**: **Jobs diarios** de detección con remediación automática en casos menores y **escalación** en críticos.
* **Brecha: Pruebas insuficientes** (fallos en producción).

  * **Cierre**: Exigir **cobertura ≥ 80 %** en **unit/integration tests** con **datos sintéticos** representativos.

#### Evidencia & Auditoría

**Definición**: La **evidencia** y **auditoría** garantizan **trazabilidad** y **cumplimiento**, verificando que los controles se aplicaron correctamente.

**Controles clave**:

* **Evidencia por gate** (artefactos y retención):

  * **Cadena de suministro (SBOM/Checksums)**: **SBOM (JSON)**, **SHA-256** del módulo, **logs de CI**, **archivo de procedencia** (*provenance*). **Retención**: 12 meses en almacenamiento **inmutable** (por ejemplo, S3 con **Object Lock**).
  * **Secretos**: **Reporte de escaneo**, **logs** (pre-commit/CI), **lista anonimizada** de hallazgos. **Retención**: 6 meses.
  * **IAM**: **Reporte de lint**, **hash** de la **política IAM**, **resultados de pruebas negativas**. **Retención**: 12 meses.
  * **Cifrado**: **Salida de OPA**, **hash** de la **política de claves**, **diff del plan**, **certificados PKI**. **Retención**: 24 meses (sectores financieros).
  * **Drift**: **Reporte de drift**, **hash** del **state file**, **logs del job**, **playbook de remediación**. **Retención**: 12 meses.
* **Nombres de artefactos reproducibles**:

  * **SBOM**: `sbom-<modulo>-<tag>-sha256.json` (por ejemplo: `sbom-s3-bucket-v1.2.0-sha256.json`).
  * **Atestación (provenance)**: `attestation-<modulo>-<tag>.intoto` (por ejemplo: `attestation-iam-role-v2.0.0.intoto`).
  * **Implementación**: Generación **automática en CI** (por ejemplo, **in-toto**) y almacenamiento en un **repositorio de artefactos** (por ejemplo, Artifactory) con **firma digital**.


#### RACI y excepciones

**Definición.** RACI (Responsible, Accountable, Consulted, Informed) define roles claros por control. Las **excepciones formalizadas** documentan y aceptan riesgos **temporales**, con fecha de expiración, mitigaciones y responsables.

**Tabla RACI por control**

| Control                          | Responsible (ejecuta) | Accountable (responde) | Consulted (opina)    | Informed (notificado) |
| -------------------------------- | --------------------- | ---------------------- | -------------------- | --------------------- |
| Cadena de suministro (SBOM/SLSA) | Equipo de Plataforma  | SecOps                 | Equipos dueños       | Todos                 |
| Manejo de secretos               | Equipos dueños        | Equipo de Plataforma   | SecOps               | Todos                 |
| IAM (menor privilegio)           | Equipos dueños        | SecOps                 | Equipo de Plataforma | Todos                 |
| Cifrado/PKI                      | Equipo de Plataforma  | SecOps                 | Equipos dueños       | Todos                 |
| Detección de drift      | Equipo de Plataforma  | Equipos dueños         | SecOps               | Todos                 |
| Pruebas de IaC                   | Equipos dueños        | Equipo de Plataforma   | SecOps               | Todos                 |

* **Responsible (R):** ejecuta la tarea (por ejemplo, el Equipo de Plataforma genera el SBOM).
* **Accountable (A):** aprueba y responde por el resultado (por ejemplo, SecOps valida seguridad). *A debe ser único por control.*
* **Consulted (C):** aporta criterios (por ejemplo, equipos dueños para requisitos de IAM).
* **Informed (I):** recibe notificaciones (por ejemplo, avisos en Slack).


### Operabilidad y confiabilidad (Run It)

#### Observabilidad de IaC

**Definición.** La observabilidad permite **monitorizar y auditar** cambios de IaC para garantizar **trazabilidad, desempeño y cumplimiento**.

**Controles clave**

* **Trazabilidad de `plan/apply` por módulo/sprint**
  **¿Qué es?** Registro de cada `terraform plan/apply` por módulo y por sprint.
  **Implementación.** Terraform Cloud/Enterprise o logs centralizados (ELK) con trazas (por ejemplo, Jaeger).
  **Ejemplo.** El 23/10/2025 se aplicó el módulo `s3` con cambios en `versioning`.

* **Audit logging de cambios**
  **¿Qué es?** Registro **inmutable** de acciones de IaC.
  **Implementación.** AWS CloudTrail (o equivalente) con retención ≥ 1 año.
  **Ejemplo.** CloudTrail registra un `Apply` con usuario, timestamp y recursos afectados.

* **Tableros DORA**
  **¿Qué es?** Métricas DORA: **Lead Time**, **Change Failure Rate**, **MTTR**, **Deployment Frequency**.
  **Implementación.** Dashboards en Grafana con **tiempo desde commit hasta apply** y alertas.
  **Ejemplo.** En el último sprint, **Change Failure Rate = 5 %** y **MTTR = 45 min**.


#### Gestión de *Drift*

**Definición:** El *drift* ocurre cuando el estado real de los recursos en la nube difiere del estado definido en IaC.

**Controles clave:**

* **Tarea recurrente de detección de *drift***

  * **¿Qué es?** Detectar diferencias entre el código IaC y el estado real.
  * **Implementación:** Programar `terraform plan -detailed-exitcode` en CI (diario o por cambio en main). Opcional: `-out=plan.tfplan` para auditoría (0 = sin cambios, 2 = *drift*/cambios).
  * **Ejemplo:** Un *job* detecta que un bucket S3 cambió su `acl` manualmente.

* **Severidad por tipo de recurso y *playbook* de remediación**

  * **¿Qué es?** Clasificar *drifts* por impacto y definir remediaciones automáticas o manuales.
  * **Implementación:** Alta severidad para *drifts* en IAM; baja para *tags*. Los *playbooks* incluyen `terraform apply` para autorremediación o notificación a Slack para remediación manual.
  * **Ejemplo:** Un *drift* en IAM dispara una alerta crítica; un *tag* faltante se corrige automáticamente.

#### Resiliencia

**Definición:** La resiliencia asegura que la infraestructura definida como código pueda recuperarse de fallos con mínima interrupción.

**Controles clave:**

* **Patrones de DR/Backup (RPO/RTO por módulo)**

  * **¿Qué es?** RPO (*Recovery Point Objective*): ventana máxima de pérdida de datos. RTO (*Recovery Time Objective*): tiempo máximo de recuperación.
  * **Implementación:** Definir RPO/RTO por módulo (por ejemplo, RTO < 4 h para RDS). Usar Multi-AZ o replicación entre regiones.
  * **Ejemplo:** Módulo RDS con backup diario (RPO = 24 h).

* **Pruebas de restauración en el *pipeline***

  * **¿Qué es?** Verificar que los respaldos sean restaurables.
  * **Implementación:** Incluir *steps* en CI para restaurar (por ejemplo, `terraform import`/restauración de snapshot) y pruebas funcionales (conexión a la DB restaurada).
  * **Ejemplo:** El *pipeline* restaura un snapshot de RDS y valida la conectividad.

#### Postura en *runtime*

**Definición:** La postura en *runtime* monitorea la infraestructura tras el *deploy* para detectar y remediar amenazas en tiempo real.

**Controles clave:**

* **Integración de CSPM/CNAPP**
  Usar *Cloud Security Posture Management* (CSPM) o *Cloud Native Application Protection Platform* (CNAPP) como *gates* post-apply (por ejemplo, CloudTrail para logs, Config para conformidad, GuardDuty para detección). No limitarse a OPA pre-apply; ejecutar *scans* post-deploy.

  * **Implementación:** Jobs post-apply que integren con la herramienta de CSPM; fallar si hay violaciones (por ejemplo, recurso sin cifrado).
  * **Ejemplo:** GuardDuty alerta sobre accesos sospechosos; Config verifica conformidad con NIST.

* **KPI: % de hallazgos críticos autorremediados en < 24 h**
  Medir la tasa de autorremediación (por ejemplo, con *triggers* de AWS Lambda). **Objetivo:** > 90 % en < 24 h.

  * **Implementación:** Exponer métricas (Datadog/CloudWatch) y alertar si el KPI cae bajo el umbral.

* **Observabilidad y cumplimiento en *runtime***

  * **SLO de remediación:** Crítico < 24 h; Alto < 72 h (según severidad).
  * **Métricas:** MTTD/MTTR (*Mean Time to Detect/Remediate*) por dominio (IAM, red, datos) y % autorremediado.
  * **Control:** Si un hallazgo crítico persiste > 24 h, bloquear el *apply* del módulo afectado mediante *gates* en CI.
  * **Ejemplo:** El *dashboard* muestra MTTR de 12 h en hallazgos de IAM, con 80 % autorremediados.


#### Gestión de cambios y "break-glass"

**Definición**: Gestionar cambios de forma controlada; "break-glass" para emergencias.

**Controles clave**:

* **Flujo de cambio**: PR con plan firmado -> aprobación -> aplicación por bot o *role* técnico (no humanos).
* **Break-glass**: Rol de emergencia con MFA, expiración (por ejemplo, 1 h) y **post-mortem** obligatorio (incluye el **diff** exacto aplicado).
* **Evidencia**: Ticket de cambio, firmas/verificación del **tag**, registro de quién aplicó y por qué.
* **Ejemplo**: En emergencia, activar el rol con MFA, registrar el **diff** en Jira y realizar el post-mortem dentro de 24 horas.


### Diseño seguro de módulos

#### Interfaces mínimas

**Definición**: Los módulos deben exponer solo lo necesario para reducir la superficie de ataque.

**Controles clave**:

* Limitar variables de entrada y usar valores predeterminados seguros.
* Banderas booleanas de funcionalidad (**feature flags**/**toggles**) para activar o desactivar características sin romper compatibilidad.
* **Ejemplos probados + `terraform validate` + tests**: Incluir ejemplos en `/examples` con pruebas que también funcionen como documentación.
* **Ejemplo**: Un módulo EC2 solo expone `instance_type` y usa `enable_encryption = true` por defecto.

#### Políticas declarativas por dominio

**Definición**: Políticas en **OPA** (**Open Policy Agent**) y **Conftest** que definen reglas por dominio (red, identidad, datos).

**Controles clave**:

* **Implementación**: Incluir archivos **Rego** en el repositorio, por ejemplo, denegar `public_ip` en EC2.
* **Ejemplo**: Una política OPA falla si un módulo crea un bucket S3 público.

#### Compatibilidad y ruptura

**Controles clave**:

* **Matriz Terraform y proveedor + política SemVer**: Mantener por módulo una matriz de compatibilidad (por ejemplo, Terraform 1.0–1.5 y proveedor AWS 4.0–5.0). Política **SemVer** (**versionado semántico**): **Major** = cambios rompientes (**breaking changes**, por ejemplo, remover una variable), **Minor** = nuevas funciones compatibles, **Patch** = correcciones.

  * **Implementación**: Documentar en el **README** y validar en **CI** (**integración continua**).
* **"BREAKING CHANGE" requerido**: Usar **conventional commits** (por ejemplo, `BREAKING CHANGE: remove var.old_param`) y sección fija en las **release notes** (**notas de versión**) con impactos y **migration guide** (**guía de migración**).

  * **Ejemplo**: Notas de versión con "Breaking Changes: Variable `legacy_encryption` removida; migrar a `encryption_enabled`".
* **Compatibilidad y ruptura operativa**:

  * **Cumplimiento de SemVer**: Forzar SemVer en CI; sección fija "BREAKING CHANGES" con **playbook** de migración y **smoke test** posterior a la actualización.
  * **Matriz de compatibilidad verificada en CI**: Probar combinaciones (por ejemplo, Terraform 1.5 y 1.9 con proveedores 4.x y 5.x) de forma automática.
  * **Ejemplo**: El pipeline de CI falla si un cambio introduce incompatibilidad con Terraform 1.5.

#### *Cloud-agnostic* vs. específico

**Definición**: Diseñar módulos portables (**cloud-agnostic**) cuando sea posible, con secciones específicas claramente marcadas.

**Controles clave**:

* **Secciones agnósticas**: Lógica general (variables, *outputs*) sin referencias a proveedores específicos.
* **Secciones específicas (por ejemplo, AWS-only)**: Marcar con comentarios (por ejemplo, "# Específico de AWS: usar KMS"). Sugerir equivalentes una sola vez por línea: Azure Key Vault (**AKV**), GCP Secret Manager (**SM**), Cloud KMS (GCP), o en AWS: Secrets Manager (**ASM**) y KMS.
* **Implementación**: Usar proveedores variables y condicionales multinube; documentar portabilidad en el **README**.


#### Threat modeling y clasificación de datos

**Definición**: El **threat modeling (modelado de amenazas)** identifica riesgos; la **clasificación de datos** alinea controles con la sensibilidad.

**Controles clave**:

* **STRIDE o LINDDUN por dominio**: Aplicar **STRIDE** (**suplantación, manipulación, repudio, divulgación, denegación, elevación de privilegios**) o **LINDDUN** (**vinculabilidad, identificabilidad, no repudio, detectabilidad, divulgación de información, desconocimiento del usuario, incumplimiento**) para dominios de red, identidad y datos, con controles compensatorios.
* **Clasificación**: **Public**, **Internal**, **Confidential**, **Restricted**, con **etiquetas obligatorias** y **requisitos mínimos**. Ejemplo: **Restricted** implica **KMS dedicado**, **rotación ≤ 180 días**, **TLS 1.3** y **logging** reforzado.
* **Evidencia**: Matriz que mapea **recurso -> clasificación -> controles**; por ejemplo, bucket **S3** clasificado **Restricted** con **cifrado KMS dedicado** y **logs** enviados al **SIEM** (**gestión de información y eventos de seguridad**).
* **Ejemplo**: Modelo de amenazas de identidad: mitigar **elevación de privilegios** con **principio de mínimo privilegio** y **MFA** (**autenticación multifactor**).


### Flujo de trabajo y calidad

#### Convenciones de PR

**Definición**: Estandarizar **pull requests (PR)** para consistencia y seguridad.

**Controles clave**:

* **Conventional Commits**: Usar formato como `feat: add encryption` para **changelogs** automáticos (**historial de cambios**).
* **Checklist de seguridad y CODEOWNERS**: Requerir revisiones en rutas sensibles (por ejemplo, `/modules/iam`) mediante el archivo **CODEOWNERS** (**propietarios de código**).
* **Ejemplo**: Un PR que toca `/modules/iam` sin revisión de SecOps **no** puede integrarse.

#### Pre-commit homogéneo

**Definición**: Los **hooks de pre-commit** aseguran calidad local y se replican en CI.

**Controles clave**:

* **Implementación**: Usar **pre-commit** con `terraform fmt`, **tfsec**, **TruffleHog** y **Conftest**.
* **Ejemplo**: Un hook **bloquea** un commit con formato incorrecto o un secreto detectado.

### Catálogo interno de módulos y adopción

**Definición**: Registro centralizado de módulos con metadatos para promover adopción.

**Controles clave**:

* **Estados**: **Experimental** (beta, sin SLO), **Stable** (listo para producción), **Deprecated** (fin de soporte en **6 meses**).
* **SLO de soporte** (**objetivo de nivel de servicio**): **Stable** con **99 %** de disponibilidad y **respuesta a issues < 24 h**; **Deprecated** solo recibe **correcciones críticas**.
* **Telemetría de uso**: Monitorear consumidores (por ejemplo, **Terraform Cloud workspaces**) y versión en uso (métricas **Prometheus**). **KPI** (**indicador clave de rendimiento**): porcentaje de adopción por equipo.
* **Implementación**: **Terraform Registry** privado integrado con **Grafana** para tableros de uso.
* **Catálogo y adopción:**:

  * **Estados con SLO y fecha de EoL** (**End of Life, fin de vida**): Incluir fecha de retiro para **Deprecated**.
  * **Telemetría**: Alertas de desuso si hay **> 2 versiones** de diferencia con la última.
  * **Ejemplo**: Módulo **v1.0** marcado **Deprecated** con **EoL 2026-04-01** y alerta a consumidores en **v0.9**.


### Pruebas IaC más nítidas

**Definición:** Distinguir los tipos de pruebas para lograr **cobertura completa**.

**Controles clave:**

* **Unit, Contract:** Verificar interfaces de entrada y salida con **datos sintéticos** (por ejemplo, variables simuladas). **Criterio:** validar variables y salidas **sin desplegar** recursos.
* **Plan Policy:** Ejecutar `terraform plan` y evaluar con **OPA** (políticas **Rego**). **Criterio:** **sin drift** en el plan y reglas Rego **aprobadas**.
* **Integration, post-deploy:** Desplegar en entorno **sandbox** y verificar funcionalidad (por ejemplo, acceso a base de datos). **Criterio:** pruebas **end-to-end** con **limpieza automática (cleanup)**.
* **Medir cobertura de políticas:** Usar **Rego coverage** para el **porcentaje de reglas ejercitadas por módulo** con **objetivo ≥ 90 %**.
* **Implementación:** Integrar en el **pipeline** con **tftest** y **datos sintéticos** generados con **Faker**.

**Pruebas IaC, cobertura de políticas y datos sintéticos**

* **Policy coverage:** **Cobertura Rego ≥ 90 %** por módulo.
* **Fixtures sintéticos obligatorios:** Nombres descriptivos (por ejemplo, `public_s3_bucket_fixture`).
* **Gate de regresión de plan:** No permitir **drift** introducido por cambios, **plan diff** estable para **entradas iguales**.
* **Ejemplo:** La prueba **falla** si un cambio **altera el plan** sin modificar las entradas.

### Costos y gobierno financiero

#### Etiquetado consistente

**Definición:** Las **etiquetas (tags)** permiten rastrear **costos** y cumplir **políticas**.

**Controles clave:**

* **Implementación:** **Forzar etiquetas** como `owner`, `cost-center`, `env` con **OPA/Conftest**. Configurar **alertas de presupuesto** (por ejemplo, **AWS Budgets**).
* **Ejemplo:** Un **gate** **falla** si un recurso no tiene la etiqueta `confidentiality`.


### Controles obligatorios de seguridad en IaC

* **Modelado de amenazas por dominio:** Analizar riesgos de **red** (por ejemplo, *DDoS*), **identidad** (por ejemplo, **escalación**), y **datos** (por ejemplo, **filtraciones**).
* **Mínimos criptográficos:** **AES-256** y **TLS 1.3 o superior**.
* **IAM de privilegio mínimo:** Políticas con **denegación por defecto (deny by default)**.
* **Etiquetas obligatorias:** En **todos** los recursos.
* **SBOM y procedencia (*provenance*):** Por cada **versión (release)**.
* **Firma de artefactos:** **Obligatoria**.
* **OPA y Conftest:** **Validación en CI**.
* **Excepciones con vencimiento:** Máximo **90 días**.


### Plantilla de módulo opinada

**Estructura de módulo Terraform (opinada)**

```
/main.tf           # Lógica principal
/variables.tf      # Variables mínimas
/outputs.tf        # Salidas sensibles enmascaradas
/examples/         # Ejemplos probados
/tests/            # Pruebas con tftest
/policies/         # Reglas Rego para OPA
```

* **Valores predeterminados seguros:** Cifrado habilitado e **IAM** con privilegio mínimo.
* **Pruebas:** `terraform validate` y **pruebas unitarias**.
* **OPA:** Política para **denegar exposición pública**.

#### Matriz de gates

```
| Recurso | Gate                         | Severidad | Mapeo normativo | Descripción                          |
|---------|------------------------------|-----------|------------------|--------------------------------------|
| IAM     | Linter de privilegio mínimo  | Alta      | ISO A.9.2.3      | Verificar permisos mínimos.          |
| Storage | Verificación de cifrado      | Alta      | NIST SC-28       | Forzar cifrado en reposo.            |
| Redes   | OPA: sin exposición pública  | Media     | PCI 1.3          | Denegar acceso público.              |
| Todos   | Etiquetas y presupuesto      | Baja      | ISO A.8.2        | Etiquetas obligatorias y alertas.    |
```


#### Dashboard mínimo

```
- DORA: Lead Time, Change Failure Rate, MTTR, Deployment Frequency.
- KPIs de IaC: Adopción de módulos y drifts detectados.
- Rechazos por política: % de compilaciones fallidas por OPA o secretos expuestos.
```

#### Glosario breve

* **SBOM (Software Bill of Materials):** Inventario estructurado de todos los componentes, versiones y orígenes de un artefacto/software para transparencia y gestión de vulnerabilidades en la cadena de suministro.
* **SLSA (Supply-chain Levels for Software Artifacts):** Marco de niveles que exige procedencia verificable y controles anti-manipulación sobre artefactos (builds reproducibles, firmas, trazabilidad de pipeline).
* **OPA (Open Policy Agent):** Motor de *policy-as-code* que usa **Rego** para evaluar y hacer cumplir políticas en planes IaC, Kubernetes, APIs y más.
* **PKI (Public Key Infrastructure):** Conjunto de CAs, certificados y claves que habilitan autenticación, cifrado y firmas digitales, con emisión y revocación gestionadas (CRL/OCSP).
* **CNAPP (Cloud-Native Application Protection Platform):** Plataforma integrada que combina CSPM/CIEM/KSPM/CWPP para seguridad de configuración y *runtime* en entornos *cloud-native*.
* **CSPM (Cloud Security Posture Management):** Monitoreo continuo de configuraciones en la nube contra *benchmarks* y políticas para detectar desviaciones y misconfiguraciones (incluido *drift*).
