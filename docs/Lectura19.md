### Seguridad en Infrastructure as Code (IaC) para DevSecOps

Este informe proporciona un marco completo para integrar seguridad en IaC, con explicaciones claras de conceptos como Cadena de Suministro, SBOM y Secretos, y controles prácticos para DevSecOps.

### Seguridad y cumplimiento (Shift-Left real)

#### Cadena de suministro (Supply Chain)

**Definición**: La cadena de suministro en IaC se refiere al conjunto de procesos, herramientas y dependencias involucradas en la creación, distribución y consumo de código de infraestructura, por ejemplo módulos de Terraform, **proveedores**, scripts.
Una **cadena de suministro** insegura puede introducir vulnerabilidades o código malicioso y comprometer entornos enteros.

**Controles clave**:

* **SBOM (Lista de materiales de Software)**:

  * **¿Qué es?**: Un SBOM es un inventario estructurado que lista todos los componentes de software de un módulo o plantilla IaC, incluyendo dependencias como **proveedores**, versiones y orígenes. Es análogo a una lista de ingredientes para el software.
  * **Implementación**: Generar SBOM con herramientas como **Syft** o **Grype** para módulos Terraform, incluyendo **proveedores** como `aws ~> 4.0` y sus orígenes, por ejemplo el registro de HashiCorp. El SBOM debe estar versionado y auditado en cada **release**.
  * **Ejemplo**: Un módulo Terraform para un bucket S3 incluiría en su SBOM el **proveedor** AWS, su versión, el hash del archivo y cualquier módulo anidado.

* **Verificación de proveedores (checksums de proveedores)**:

  * **¿Qué es?**: Los **proveedores** como AWS y Azure son binarios descargados desde **registros**. Verificar sus checksums asegura que no han sido manipulados.
  * **Implementación**: Usar `terraform providers lock` para generar un archivo de **bloqueo** con checksums verificados. En CI, validar que los **proveedores** descargados coincidan con estos checksums.
  * **Ejemplo**: `terraform init` con `--lockfile=readonly` falla si el hash del **proveedor** no coincide.

* **SLSA y procedencia de artefactos**:

  * **¿Qué es?**: SLSA es un marco para asegurar la integridad de artefactos de software mediante metadatos de **procedencia** que documentan cómo y quién creó un artefacto.
  * **Implementación**: Generar **procedencia** con herramientas como **Cosign** o **in-toto**, registrando el origen del módulo, por ejemplo el commit SHA y el repositorio Git. Almacenar en un registro seguro, por ejemplo un Terraform Registry privado.
  * **Ejemplo**: Un módulo firmado incluye un archivo JSON con el commit SHA y el **pipeline** que lo generó.

* **Firma de releases y política de "solo etiquetas firmadas"**:

  * **¿Qué es?**: Firmar versiones asegura que los módulos consumidos son auténticos. La política de "solo etiquetas firmadas" prohíbe usar versiones no verificadas en producción.
  * **Implementación**: Firmar releases con **GPG** o **Cosign**. **Forzar** en CI que solo se consuman etiquetas firmadas, por ejemplo GitHub Actions verifica la firma antes de `terraform apply`.
  * **Ejemplo**: Un pipeline falla si la etiqueta `v1.0.0` no tiene una firma GPG válida.

* **Cadena de suministro "cerrada" de verdad**:

  * **Espejo interno de proveedores y módulos**: Mantener un **mirror** interno preparado para funcionar en modo aislado para **proveedores** y módulos, configurando `provider_installation` en Terraform para apuntar al espejo.
  * **.terraform.lock.hcl de solo lectura en CI**: Forzar el archivo de bloqueo como de solo lectura para prevenir cambios no autorizados.
  * **Objetivo SLSA**: Alcanzar SLSA nivel mayor o igual a 2 en la actualidad, con plan para nivel 3 en seis meses, con política de "solo consumir del registro interno" para aislar de fuentes externas.
  * **Archivo de configuración de la CLI para mirrors**: Configurar espejos en el archivo de configuración de Terraform CLI, típicamente ubicado en `~/.terraformrc` o `~/.terraform.d/config.tfrc`.
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

    Este archivo asegura que Terraform solo consuma **proveedores** desde el **mirror** interno.


#### Secretos

**Definición**: Los secretos(secrets) son datos sensibles, por ejemplo, claves API, contraseñas, tokens, que, si se exponen, pueden comprometer la seguridad. En IaC, los secretos suelen aparecer en variables, archivos de configuración o scripts.

**Controles clave**:

* **Política de manejo centralizado, AWS Key Management Service, KMS, AWS Secrets Manager, ASM, GCP Secret Manager, SM, Azure Key Vault, AKV**:

  * **¿Qué es?**: Centralizar la gestión de secretos en servicios como AWS Key Management Service, KMS, AWS Secrets Manager, ASM, GCP Secret Manager, SM, o Azure Key Vault, AKV, evita hardcoding y facilita auditoría y rotación.
  * **Implementación**: Almacenar secretos en AWS Secrets Manager, ASM, e inyectarlos en tiempo de ejecución mediante variables de entorno o integraciones, por ejemplo, Terraform `aws_secretsmanager_secret`. Usar roles IAM para limitar acceso.
  * **Ejemplo**: Un secreto almacenado en AWS Secrets Manager, ASM, se inyecta como `data.aws_secretsmanager_secret_version.my_secret`.
* **Rotación y detección de secretos en commits**:

  * **¿Qué es?**: Rotar secretos regularmente, por ejemplo, cada 90 días, reduce el riesgo de exposición. Detectar secretos en commits evita filtraciones accidentales.
  * **Implementación**: Usar hooks pre-commit con **GitGuardian** o **TruffleHog** para escanear código antes de subirlo. En CI, configurar verificaciones que fallen si se detectan secretos. Rotar automáticamente con scripts o AWS Secrets Manager, ASM.
  * **Ejemplo**: Un hook pre-commit bloquea un commit con `AWS_ACCESS_KEY_ID` en un archivo `.tf`.
* **Scope mínimo y rotación verificable**:

  * **Scope mínimo**: Secretos con alcance por entorno, env scoped, es decir, el secreto solo es válido y visible dentro de un entorno específico como `dev`, `staging` o `prod`. Esto evita que un pipeline o servicio de desarrollo acceda por error a credenciales de producción y refuerza el principio de menor privilegio. Para aplicarlo, se recomienda namespacing por entorno en el gestor de secretos, por ejemplo, `prod/db/password`, políticas IAM separadas con condiciones por entorno, separación de claves KMS por entorno para cifrado y descifrado, y reglas de protección por entorno en CI o GitHub Environments.
  * **TTL, Time To Live**: Secretos y tokens con expiración automática en un periodo corto, por ejemplo, entre 5 y 60 minutos, reducen la ventana de ataque y limitan el impacto de filtraciones. Se sugiere usar tokens de sesión de corta duración, por ejemplo, AWS STS, GCP Service Account impersonation o credenciales federadas de Azure, habilitar rotación automática en el gestor de secretos y agregar verificaciones en CI que fallen si se detectan secretos con edad mayor a un umbral, por ejemplo, 90 días.
  * **Preferencia por token exchange sobre llaves estáticas**: En lugar de almacenar y reutilizar llaves estáticas de larga duración, se debe intercambiar identidad por tokens temporales bajo demanda. Ejemplos incluyen GitHub Actions OIDC hacia AWS STS AssumeRole, Kubernetes ServiceAccount hacia GCP Workload Identity u OAuth 2.0 client credentials. Las ventajas son revocación simple al deshabilitar la emisión, menor superficie de exposición al no persistir secretos de larga vida y auditoría granular, ya que cada token emitido queda con huella temporal, origen y alcance. Por ejemplo, un job de GitHub presenta un token OIDC y AWS emite credenciales temporales con rol y TTL estricto para aplicar Terraform. En Kubernetes, la Workload Identity intercambia el JWT del ServiceAccount por un token de acceso con permisos limitados y caducidad corta.
  * **Rotación comprobable**: Métrica de porcentaje de secretos rotados en menos de 90 días monitoreada en tableros. Incluir pruebas de revocación posteriores a la rotación para verificar que llaves antiguas fallen.
  * **No secretos en Outputs o plan**: Validación OPA que falle si un output puede contener secreto, por ejemplo, regex para detectar patrones sensibles.
  * **Ejemplo de política OPA para bloquear Outputs con posibles secretos**:

    ```rego
    package terraform

    import rego.v1

    deny contains msg if {
      output := input.planned_values.outputs[_]
      contains_sensitive(output.value)  # Función personalizada para detectar secretos, por ejemplo, regex para API keys
      msg := sprintf("Output '%s' puede contener un secreto sensible", [output.name])
    }

    contains_sensitive(value) if {
      regex.match("(?i)(key|secret|password|token|api_key)", value)
    }
    ```

    Esta política se integra en Conftest para fallar planes con outputs riesgosos.

#### IAM mínimamente privilegiado

**Definición**: El principio de privilegio mínimo (least privilege) asegura que las identidades (humanas o máquinas) solo tengan los permisos necesarios para su función.

**Controles clave**:

* **Módulos con perfiles de permisos predeterminados**:

  * **¿Qué es?**: Los módulos IaC deben incluir políticas IAM con permisos mínimos, configurables mediante variables.

    * **Explicación de "perfiles de permisos predeterminados"**: Conjunto base de permisos estrictos entregados por defecto por un módulo, que se pueden ampliar de forma controlada por variables. Ayuda a estandarizar el principio de privilegio mínimo.
  * **Implementación**: Diseñar módulos con roles IAM predefinidos, por ejemplo, solo `s3:PutObject` para un bucket. Usar variables para overrides controlados.

    * **Explicación de "overrides controlados"**: Mecanismo para ajustar parámetros por defecto de un módulo de forma delimitada y auditada. Previene que un cambio de variables abra permisos excesivos sin revisión.
  * **Ejemplo**: Un módulo S3 define un rol con `s3:GetObject` pero no `s3:DeleteBucket`.
* **Linters de políticas y pruebas de acceso negativas**:

  * **¿Qué es?**: Linters analizan políticas para detectar permisos excesivos. Pruebas negativas verifican que accesos no autorizados fallen.

  * **Implementación**: Usar **tfsec** o **Checkov** en CI para lintear políticas. Incluir tests en `terraform test` que validen accesos denegados, por ejemplo, intentar `s3:DeleteBucket` y esperar error.

#### Cifrado y PKI

**Definición**: El cifrado protege datos en reposo, por ejemplo, discos, y en tránsito, por ejemplo, red. PKI, Public Key Infrastructure, gestiona claves y certificados para autenticación y encriptado.
- **Explicación de "en reposo" at rest**: Son datos almacenados en discos, bases o snapshots protegidos mediante cifrado en el almacenamiento.
- **Explicación de "en tránsito" in transit**: Son datos que viajan por redes entre clientes y servicios protegidos por protocolos como TLS.
- **Explicación de "PKI"**: Conjunto de procesos y componentes que emiten, validan y revocan certificados digitales, gestionan autoridades certificadoras y pares de claves públicas y privadas.

**Controles clave**:

* **Defaults de encriptado en reposo y tránsito**:

  * **¿Qué es?**: Encriptado en reposo protege datos almacenados y en tránsito protege datos en movimiento.
  * **Implementación**: Configurar recursos como S3 o RDS con encriptado por defecto, AES 256. Forzar el cumplimiento mediante políticas o configuración que impida degradar la seguridad, por ejemplo rechazar conexiones sin TLS moderno (TLS 1.3 plus para APIs y endpoints).
    * **Explicación de "TLS 1.3 plus"**: Protocolo de cifrado de transporte en su versión 1.3 o superior que mejora privacidad y rendimiento frente a versiones anteriores.
    * **Explicación de "APIs" y "endpoints"**: Interfaces de programación y puntos de acceso de red donde clientes consumen servicios. Deben exigir TLS para proteger credenciales y datos.
  * **Ejemplo**: `aws_s3_bucket` con `server_side_encryption_configuration` habilitado.
* **Claves administradas, AWS Key Management Service KMS, con rotación y políticas de clave opinadas**:

  * **¿Qué es?**: AWS Key Management Service KMS gestiona claves criptográficas con políticas estrictas y rotación programada. Las políticas de claves con una postura explícita y restrictiva, definen quién puede usar, administrar y rotar la clave. Evitan configuraciones laxas por defecto.
  * **Implementación**: Usar KMS para claves con políticas que denieguen acceso no autorizado. Rotar claves anualmente o tras incidentes, con auditoría vía CloudTrail.

    * **Explicación de "rotación"**: Proceso de reemplazar claves de cifrado por nuevas en periodos definidos o después de incidentes para reducir el riesgo por exposición o desgaste criptográfico.
    * **Explicación de "CloudTrail"**: Servicio de registro de auditoría de AWS que captura eventos de uso de API y cambios de configuración, útil para trazabilidad y cumplimiento.
  * **Ejemplo**: Una política KMS permite solo `kms:Decrypt` a un rol específico.

#### Regulación

**Definición**: Cumplir con regulaciones ISO 27001, NIST, PCI DSS implica alinear controles de seguridad con estándares específicos y gestionar excepciones.
**Explicación de "ISO 27001"**: Norma internacional para sistemas de gestión de seguridad de la información que define controles y procesos para proteger activos.
**Explicación de "PCI DSS"**: Estándar de seguridad para la industria de tarjetas de pago que regula la protección de datos de titulares y la operación de sistemas que los procesan.

**Controles clave**:

* **Mapear gates a controles**:

  * **¿Qué es?**: Cada gate en el pipeline debe corresponder a un control regulatorio.

    * **Explicación de "gates"**: Puntos de verificación que se deben aprobar para avanzar en el pipeline, por ejemplo escaneo de secretos o verificación de cifrado.
    * **Explicación de "pipeline"**: Flujo automatizado de construcción, validación y despliegue de cambios que integra pruebas, análisis y controles de seguridad.
  * **Implementación**: Crear una matriz que asocie gates, por ejemplo secrets scan, con controles como ISO A 10.1 protección criptográfica.

    * **Explicación de "secrets scan"**: Escaneo automatizado del repositorio y artefactos para detectar credenciales, claves o tokens expuestos y fallar si se encuentran.
    * **Explicación de "ISO A 10.1" y "NIST SC 28"**: Referencias a controles específicos dentro de los marcos ISO y NIST. NIST SC 28 protege la confidencialidad de la información en reposo mediante mecanismos de cifrado y gestión de claves.
  * **Ejemplo**: Gate de encriptado mapea a NIST SC 28.
* **Proceso de excepciones con vencimiento, aceptación de riesgos con límite de tiempo (time boxed risk acceptance)**:

  * **¿Qué es?**: Excepciones permiten desviaciones temporales de políticas con vencimiento definido.

    * **Explicación de "time boxed risk acceptance"**: Aceptación consciente de un riesgo por un periodo limitado y documentado con condiciones de expiración y revisión.
  * **Implementación**: Usar un sistema de tickets, por ejemplo Jira, para aprobar excepciones con vencimiento de 30 a 90 días y auditoría trimestral.

#### Estado y backend de Terraform

**Definición**: El estado de Terraform almacena la configuración de la infraestructura, un backend seguro es crítico para prevenir corrupción, leaks o accesos no autorizados.

**Controles clave**:

* Usar backends cifrados como S3 con AWS Key Management Service (KMS), Azure Storage o GCS, habilitar versioning y Object Lock (WORM) para inmutabilidad.
* Implementar locking con DynamoDB (para AWS) o tablas de locks equivalentes para prevenir applies concurrentes.
* Usar workspaces para segregar estados, aplicar principio de menor privilegio (por ejemplo, roles para plan vs. apply).
* Solo los roles de CI pueden ejecutar cambios en la infraestructura, las personas solo pueden generar planes mediante cuentas break-glass con MFA y expiración, y los outputs sensibles deben enmascararse en los planes.
* **Evidencia**: Hash del state (SHA256), logs de lock/unlock, trail de plan/apply (por ejemplo, via CloudTrail).
* **Ejemplo**: Backend en `main.tf`:

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

**Definición**: Las brechas (gaps) en IaC son vulnerabilidades o debilidades comunes que pueden exponer la infraestructura a riesgos. Identificarlas y cerrarlas es esencial para una postura de seguridad robusta.

**Brechas comunes y estrategias de cierre**:

* **Brecha: Falta de validación en en la cadena de suministros**: Dependencias no verificadas pueden introducir malware.

 * **Cierre**: Implementar SBOM, checksums y SLSA en todos los módulos. Usar gates CI que bloqueen deploys sin verificación.
* **Brecha: Exposición de secretos en repositorios**: Secretos hardcoded en commits históricos.
  * **Cierre**: Escanear repositorios existentes con TruffleHog y rotar todos los secretos detectados. Enforce pre-commit hooks y CI gates obligatorios.
* **Brecha: IAM sobredimensionado**: Permisos excesivos permiten escalación de privilegios.

  * **Cierre**: Aplicar linters automáticos (tfsec) y pruebas negativas en cada PR. Revisar periódicamente con herramientas como AWS IAM Access Analyzer.
* **Brecha: encriptado inconsistente**: Datos no encriptados en reposo/tránsito.

  * **Cierre**: Definir defaults en módulos y validar con OPA/Conftest. Monitorear post-deploy con CSPM para drifts.
* **Brecha: Cumplimiento no documentado**: Falta de mapeo a regulaciones lleva a auditorías fallidas.

  * **Cierre**: Mantener una matriz viva de gates vs. controles, con revisiones trimestrales y evidencia automatizada.
* **Brecha: Drift no gestionado**: Cambios manuales en la nube ignoran IaC.

  * **Cierre**: Jobs diarios de detección con remediación automática para drifts menores, escalación para críticos.
* **Brecha: Pruebas insuficientes**: Módulos no probados fallan en producción.

  * **Cierre**: Requerir cobertura >80% en unit/integration tests, con datos sintéticos para simular escenarios reales.

#### Evidencia & Auditoría

**Definición**: La evidencia y auditoría aseguran trazabilidad y cumplimiento, permitiendo verificar que los controles se aplicaron correctamente.

**Controles clave**:

* **Evidencia conservada por gate**: Cada gate en el pipeline genera artefactos para auditoría.

  * **Gate de cadena de suministro (SBOM/Checksums)**: Artefacto (SBOM JSON), hash (SHA256 del módulo), log (CI output), adjunto (provenance file). Retención: 12 meses en almacenamiento immutable (por ejemplo, S3 con Object Lock).
  * **Gate de secretos**: Artefacto (scan report), hash (N/A), log (pre-commit/CI logs), adjunto (lista de secretos detectados, anonimizada). Retención: 6 meses.
  * **Gate de IAM**: Artefacto (lint report), hash (política IAM), log (test results), adjunto (negative test outputs). Retención: 12 meses.
  * **Gate de encriptado**: Artefacto (OPA output), hash (key policy), log (plan diff), adjunto (certificados PKI). Retención: 24 meses para regulaciones financieras.
  * **Gate de drift**: Artefacto (drift report), hash (state file), log (job execution), adjunto (remediation playbook). Retención: 12 meses.
* **Nombres de artefactos reproducibles**:

  * SBOM: `sbom-<modulo_nombre>-<tag_version>-sha256.json` (por ejemplo, `sbom-s3-bucket-v1.2.0-sha256.json`).
  * Atestación (Provenance): `attestation-<modulo_nombre>-<tag_version>.intoto` (por ejemplo, `attestation-iam-role-v2.0.0.intoto`).
  * **Implementación**: Generar automáticamente en CI con herramientas como in-toto, almacenados en un artifact repository (por ejemplo, Artifactory) con firma digital.

#### RACI y excepciones

**Definición**: RACI (Responsible, Accountable, Consulted, Informed) define roles claros para cada control. Las excepciones formalizadas gestionan riesgos temporales.

**Tabla RACI por control**:

| Control                  | Responsible (Ejecuta) | Accountable (Responde) | Consulted (Opina) | Informed (Se Notifica) |
| ------------------------ | --------------------- | ---------------------- | ----------------- | ---------------------- |
| Supply Chain (SBOM/SLSA) | Platform Team         | SecOps                 | Owners            | Todos                  |
| Manejo de Secrets        | Owners                | Platform Team          | SecOps            | Todos                  |
| IAM Least-Privilege      | Owners                | SecOps                 | Platform Team     | Todos                  |
| Encriptado/PKI           | Platform Team         | SecOps                 | Owners            | Todos                  |
| Drift Detection          | Platform Team         | Owners                 | SecOps            | Todos                  |
| Pruebas IaC              | Owners                | Platform Team          | SecOps            | Todos                  |

* **Responsible**: Ejecuta la tarea, por ejemplo, Platform Team genera SBOM.
* **Accountable**: Aprueba y responde por el resultado, por ejemplo, SecOps valida seguridad.
* **Consulted**: Proporciona input, por ejemplo, Owners en IAM para necesidades de negocio.
* **Informed**: Recibe updates, por ejemplo, notificaciones Slack.

#### Operabilidad y confiabilidad (Run It)

#### Observabilidad de IaC

**Definición**: La observabilidad permite monitorear y auditar cambios en IaC para garantizar trazabilidad y rendimiento.

**Controles clave**:

* **Tracing de Plan/Apply por módulo/sprint**:

  * **¿Qué es?**: Registrar cada `terraform plan/apply` para rastrear cambios por módulo o sprint.
  * **Implementación**: Usar Terraform Cloud o logs centralizados (por ejemplo, ELK) con tracing via Jaeger.
  * **Ejemplo**: Un log muestra que el módulo `s3` fue aplicado el 23/10/2025 con cambios en `versioning`.
* **Audit logging de cambios**:

  * **¿Qué es?**: Registro immutable de todas las acciones IaC.
  * **Implementación**: Usar AWS CloudTrail o equivalente con retención de 1 año.
  * **Ejemplo**: CloudTrail registra un `Apply` con el usuario y timestamp.
* **Tableros DORA**:

  * **¿Qué es?**: Métricas DORA (DevOps Research and Assessment) miden eficiencia: Lead Time, Change Failure Rate, MTTR, Deployment Frequency.
  * **Implementación**: Configurar dashboards en Grafana con métricas como tiempo desde commit hasta apply.
  * **Ejemplo**: Un dashboard muestra un Change Failure Rate de 5% en el último sprint.

#### Gestión de Drift

**Definición**: El drift ocurre cuando el estado real de los recursos (en la nube) difiere del estado definido en IaC.

**Controles clave**:

* **Job Recurrente de detección de drift**:

  * **¿Qué es?**: Detectar diferencias entre el código IaC y el estado real.
  * **Implementación**: Programar `terraform plan -detailed-exitcode` en CI diariamente.
  * **Ejemplo**: Un job detecta que un bucket S3 cambió su `acl` manualmente.
* **Severidad por tipo de recurso y playbook de remediación**:

  * **¿Qué es?**: Clasificar drifts por impacto y definir remediaciones automáticas o manuales.
  * **Implementación**: Alta severidad para IAM drifts, baja para tags. Playbooks incluyen `terraform apply` para auto-remediación o notificación Slack para manual.
  * **Ejemplo**: Un drift en IAM dispara una alerta crítica, un tag faltante se corrige automáticamente.

#### Resiliencia

**Definición**: La resiliencia asegura que los recursos IaC puedan recuperarse de fallos con mínimas interrupciones.

**Controles clave**:

* **Patrones de DR/Backup (RPO/RTO por módulo)**:

  * **¿Qué es?**: RPO (Recovery Point Objective) mide datos perdidos, RTO (Recovery Time Objective), tiempo de recuperación.
  * **Implementación**: Definir RPO/RTO por módulo (por ejemplo, RTO <4h para RDS). Usar multi-AZ o cross-region replication.
  * **Ejemplo**: Un módulo RDS con backup diario (RPO=24h).
* **Pruebas de restauración en pipeline**:

  * **¿Qué es?**: Verificar que los backups sean restaurables.
  * **Implementación**: Incluir steps en CI para `terraform import` y pruebas funcionales (por ejemplo, conectar a DB restaurada).
  * **Ejemplo**: Un pipeline restaura un snapshot RDS y valida conectividad.

#### Runtime Posture

**Definición**: La postura en runtime monitorea la infraestructura post-deploy para detectar y remediar amenazas en tiempo real.

**Controles clave**:

* **Integración de CSPM/CNAPP**: Usar Cloud Security Posture Management (CSPM) o Cloud Native Application Protection Platform (CNAPP) como gates post-apply (por ejemplo, AWS CloudTrail para logs, Config para conformidad, GuardDuty para detección de amenazas). No limitarse a OPA pre-apply, ejecutar scans post-deploy.

  * **Implementación**: Configurar jobs post-apply que integren con CSPM tools, fallando si se detectan violaciones (por ejemplo, recurso no encriptado).
  * **Ejemplo**: GuardDuty alerta sobre accesos sospechosos, Config verifica conformidad con NIST.
* **KPI: % de Findings Críticos Auto-Remediados en <24h**: Medir la tasa de remediación automática (por ejemplo, via AWS Lambda triggers). Objetivo: >90% en <24h.

  * **Implementación**: Usar métricas en Datadog, alertar si KPI cae por debajo del umbral.
* **Observabilidad y Cumplimiento "Runtime"**:

  * **SLO de Remediación**: Crítico <24h, Alto <72h, definido por severidad.
  * **Métricas**: MTTD/MTTR (Mean Time to Detect/Remediate) por dominio (IAM, red, datos) + % auto-remediado.
  * **Control**: Si un finding crítico persiste >24h, bloquear apply del módulo afectado via CI gates.
  * **Ejemplo**: Dashboard muestra MTTR de 12h para IAM findings, con 80% auto-remediados.

#### Gestión de cambios y "break-glass"

**Definición**: Gestionar cambios de forma controlada, break-glass para emergencias.

**Controles clave**:

* **Flujo de Cambio**: PR con plan firmado -> aprobación -> apply por bot/role técnico (no humanos).
* **Break-Glass**: Rol de emergencia con MFA, expiración (por ejemplo, 1h) y post-mortem obligatorio (incluye diff exacto aplicado).
* **Evidencia**: Ticket de cambio, firmas/verificación de tag, registro de quién aplicó y por qué.
* **Ejemplo**: En emergencia, activar rol con MFA, registrar diff en Jira y realizar post-mortem en 24.

#### Glosario rápido solo en español

* Backend: repositorio o servicio de almacenamiento del estado remoto.
* State: archivo de estado de la infraestructura.
* Remote state: estado remoto colaborativo.
* Versioning: control de versiones de objetos.
* Object Lock, WORM: bloqueo inmutable de objetos, escribir una vez leer muchas veces.
* State locking: bloqueo del estado para evitar concurrencia.
* Workspace: espacio lógico de estado por entorno o proyecto.
* Plan y Apply: planificar cambios y aplicarlos.
* Least privilege: privilegio mínimo.
* CI: integración continua.
* Break glass: acceso de emergencia temporal.
* MFA: autenticación multifactor.
* Outputs sensibles: salidas con datos confidenciales enmascaradas.
* Hash SHA256: huella criptográfica de integridad.
* CloudTrail: auditoría de eventos en la nube de AWS.
* Supply chain: cadena de suministro de software.
* SBOM: lista de materiales de software.
* SLSA: niveles de seguridad de la cadena de suministro.
* Gate: punto de control obligatorio del pipeline.
* Enforce: forzar el cumplimiento.
* Pre-commit hook: validación previa al commit.
* PR, pull request: solicitud de integración para revisión.
* OPA y Conftest: motor y herramienta para validar políticas.
* CSPM: gestión de postura de seguridad en la nube.
* Drift: deriva entre IaC y la realidad.
* RACI: matriz de responsabilidades.
* ELK: stack de logs y visualización.
* Jaeger: sistema de trazas distribuidas.
* DORA: métricas de desempeño DevOps.
* Lead time, change failure rate, MTTR, deployment frequency: tiempo a producción, tasa de fallos por cambio, tiempo medio de recuperación, frecuencia de despliegue.
* Detailed exit code: código de salida detallado del plan.
* Multi AZ: múltiples zonas de disponibilidad.
* Snapshot: copia de seguridad puntual.
* CNAPP: plataforma de protección de aplicaciones nativas en la nube.
* GuardDuty: detección de amenazas en AWS.
* KPI: indicador clave de desempeño.
* SLO: objetivo de nivel de servicio.
* MTTD y MTTR: tiempo medio de detección y de remediación.
* Diff: diferencia exacta entre estados.
* Tag: etiqueta de versión.
