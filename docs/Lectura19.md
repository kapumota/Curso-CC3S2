### Seguridad en Infrastructure as Code (IaC) para DevSecOps

Este informe proporciona un marco completo para integrar seguridad en IaC, con explicaciones claras de conceptos como Cadena de suministro, SBOM y Secretos, y controles prácticos para DevSecOps.

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

