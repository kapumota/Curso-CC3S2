### Hardening de Kubernetes en clave DevSecOps: RBAC, Policies, NetworkPolicies y Secrets

En muchos equipos modernos, **Kubernetes** se ha convertido en la capa central donde se juntan aplicaciones, datos, CI/CD,  operaciones y seguridad. 

Eso significa que, si el clúster está mal diseñado o poco endurecido, cualquier error de configuración, un rol demasiado amplio, un Pod privilegiado, un Secret expuesto, puede convertirse en una puerta de entrada hacia *todo* el entorno.

Desde una mirada **DevSecOps**, la pregunta ya no es solo *"¿cómo despliego rápido en Kubernetes?"*, sino *"¿cómo diseño el clústery mis pipelines para que la seguridad sea parte del flujo normal de trabajo?"*. No se trata de agregar parches de seguridad al final, sino de definir desde el inicio **quién puede hacer qué**, **qué se admite en el clúster**, **quién puede hablar con quién en la red** y **cómo manejamos credenciales y datos sensibles**.

En este texto vamos a ver Kubernetes "en clave DevSecOps", enfocándonos en cuatro pilares prácticos de hardening:

* **RBAC** para controlar accesos e identidades.
* **Policies / admission control** para decidir qué workloads se aceptan.
* **NetworkPolicies** para pasar de una red "todo abierto" a un modelo cercano a **zero-trust**.
* **Secrets** para gestionar credenciales de forma segura en un entorno dinámico.

La idea es mostrar cómo estas piezas encajan entre sí y cómo se integran en los pipelines de CI/CD, de modo que el resultado no sea solo "un clúster que funciona", sino **un clúster que funciona y está razonablemente protegido por diseño**.


#### 1. Por qué la seguridad en Kubernetes es distinta

Kubernetes no es solo "otro runtime de contenedores": es una **plataforma distribuida** donde conviven *control plane*, nodos, pods, aplicaciones, pipelines de CI/CD y equipos distintos tocando el mismo clúster. Eso multiplica la superficie de ataque.

Imagina un clúster donde una sola aplicación comprometida puede escanear toda la red interna, leer Secrets de otros namespaces y crear Pods privilegiados. No hace falta una vulnerabilidad "de ciencia ficción": muchas veces basta con RBAC demasiado amplio, ausencia de NetworkPolicies y Secrets sin un hardening mínimo. Justamente ahí entra en juego el diseño de seguridad desde DevSecOps.

Hoy, la seguridad de un clúster se piensa como un modelo de "4 Cs": **Cloud, Cluster, Container y Code**. La nube (o el datacenter) da la base, el clúster es el plano de control y de datos, los contenedores empacan las apps y el código es donde viven las vulnerabilidades lógicas. Un fallo grave en cualquiera de estas capas puede, en la práctica, equivaler a comprometer todo el clúster. 

En un enfoque **DevSecOps**, la idea no es "levantar un clúster y luego endurecerlo a golpes", sino **diseñar la seguridad como parte del ciclo de vida**:

* Definir políticas desde el inicio (RBAC, políticas de admisión, network policies, manejo de secretos).
* Automatizar comprobaciones en CI/CD.
* Usar *policy-as-code* y benchmarks como CIS Kubernetes para verificar que el clúster se mantiene endurecido en el tiempo.

En ese marco, cuatro piezas son centrales: **RBAC**, las **políticas** (admission controllers, Pod Security Standards, ValidatingAdmissionPolicy, etc.), las **NetworkPolicies** y los **Secrets**.

#### 2. Accesos, identidades y RBAC: quién puede hacer qué

Toda llamada al API de Kubernetes pasa por una cadena:

1. **Autenticación** (¿quién eres?).
2. **Autorización** (¿puedes hacer esto?).
3. **Control de admisión** (¿esta petición cumple las políticas del clúster?). 

RBAC vive en el paso 2 y es el corazón del control de acceso fino.

**2.1. RBAC como eje del hardening**

Con **Role-Based Access Control (RBAC)** definimos:

* **Roles / ClusterRoles**: describen permisos sobre recursos ("puede listar pods", "puede crear secrets en este namespace", etc.).
* **RoleBinding / ClusterRoleBinding**: vinculan esos roles con *subjects* (usuarios, grupos, ServiceAccounts).

Un ejemplo clásico de *least privilege* sería un `Role` que solo puede leer Pods en un namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

Este rol luego se asocia a una `ServiceAccount` o usuario mediante un `RoleBinding`. RBAC nos permite expresar en YAML: *"esta app solo puede leer sus propios Pods, nada más"*.

Desde la mirada **DevSecOps**, estos roles y bindings se tratan como **código versionado**: viven en el repositorio, pasan por *pull requests* y se validan mediante linters y herramientas de seguridad antes de llegar al clúster.

**2.2. ServiceAccounts y tokens: identidades de las apps**

Las **ServiceAccounts** son las identidades de las aplicaciones dentro del clúster. La recomendación moderna es: 

* **Una ServiceAccount por aplicación o por despliegue**, con permisos mínimos.
* **No usar la `default` ServiceAccount** que se monta automáticamente en todos los Pods.
* **Desactivar el montaje automático** del token por defecto si no se necesita.
* Usar **tokens de vida corta** (TokenRequest API) y evitar credenciales "eternas".

En un flujo DevSecOps:

* Las ServiceAccounts, Roles y RoleBindings se definen como YAML en el repo.
* Un job de CI valida que no aparezcan nuevos `ClusterRoleBinding` peligrosos (por ejemplo, unidos a `system:masters`).
* Los cambios de permisos se revisan como cualquier cambio de código crítico.

#### 3. Policies y admission control: la "aduana" del clúster

Mientras RBAC responde *"¿quién puede hacer qué?"*, las **políticas de admisión** responden *"¿en qué condiciones acepto este recurso?"*. Ahí entran los **admission controllers**.

**3.1. Admission controllers internos y externos**

Un **admission controller** intercepta una petición que ya pasó autenticación y autorización, y puede:

* Aceptarla tal cual.
* Modificarla (mutación).
* Rechazarla si viola una política.

Kubernetes trae controladores internos (como el **Pod Security Admission**) y permite conectarse a controladores externos vía *webhooks*, como **OPA Gatekeeper** o **Kyverno**, que implementan *policy-as-code*.

Ejemplos típicos de políticas:

* Bloquear Pods que se ejecutan como `root` o privilegiados.
* Exigir `readOnlyRootFilesystem: true`.
* Obligar a que todos los Pods definan requests/limits de CPU y memoria.
* Restringir qué registries de imágenes se pueden usar (solo registries internos, o solo imágenes firmadas).

En DevSecOps, estas políticas se prueban *antes* de desplegar: el pipeline de CI ejecuta las mismas reglas de Gatekeeper/Kyverno sobre los manifiestos que luego hará cumplir el clúster en tiempo de ejecución.

**3.2. De PodSecurityPolicy a Pod Security Standards y VAP**

El antiguo recurso **PodSecurityPolicy (PSP)** fue deprecado y eliminado en v1.25. En su lugar, hoy se usan: 

* **Pod Security Standards (PSS)**: tres perfiles predefinidos (Privileged, Baseline, Restricted) que describen distintos niveles de endurecimiento.
* **Pod Security Admission (PSA)**: un admission controller nativo que hace cumplir esos perfiles por *namespace*, mediante labels como
  `pod-security.kubernetes.io/enforce: restricted`.

Para necesidades más granulares, Kubernetes introdujo **ValidatingAdmissionPolicy (VAP)**, que permite escribir reglas en **CEL (Common Expression Language)** directamente en el API, sin depender necesariamente de un webhook externo. CEL es un lenguaje de expresiones diseñado para escribir condiciones lógicas de forma declarativa (por ejemplo, "solo acepto Pods cuya imagen provenga de este registry y que no corran como root").


En clave DevSecOps, estas políticas se tratan como **código versionado** y se prueban en CI: los manifiestos de despliegue se validan contra las mismas reglas que el clúster usará en producción, reduciendo sorpresas al aplicar.

#### 4. Network Policies: segmentación y modelo zero-trust

Por defecto, un clúster Kubernetes se comporta como una gran LAN: **todos los Pods pueden hablar con todos**, mientras el CNI lo permita. Eso es cómodo para desarrollo, pero desastroso para producción.

Las **NetworkPolicies** son el mecanismo nativo para convertir ese "todo abierto" en un modelo **zero-trust** interno:

* Se definen por *namespace*.
* Seleccionan Pods con `podSelector`.
* Declaran qué tráfico *ingress* y *egress* se permite: desde qué Pods/namespaces/IPs, a qué puertos y protocolos.

La idea práctica es pasar de:

> "Si un atacante compromete un microservicio, puede escanear y hablar con todo el clúster"

a:

> "Si compromete un microservicio, solo puede hablar con lo mínimo que necesita (por ejemplo, su base de datos en el puerto 5432), y nada más".

Un patrón típico de hardening es:

* Crear una NetworkPolicy **por defecto tipo "deny all"** para un namespace (con `podSelector: {}`).
* Añadir políticas específicas que permitan solo el tráfico necesario (por etiquetas, namespaces o rangos IP).

En clústeres multi-tenant, combinar **namespaces + RBAC + NetworkPolicies** permite que cada equipo, aplicación o entorno (dev/stage/prod) tenga fronteras claras: no solo a nivel lógico, sino **a nivel de red**.

En DevSecOps, estas NetworkPolicies:

* Se definen en el repo junto con los deployments.
* Pasan por revisión en PR.
* Pueden validarse en CI con herramientas que simulan caminos de red y comprueban que el modelo "deny all + permisos explícitos" se mantiene coherente.

#### 5. Secretos: proteger credenciales en un entorno dinámico

En Kubernetes, un **Secret** es un objeto pensado para almacenar pequeñas cantidades de información sensible: contraseñas, tokens, claves, certificados, etc. Son similares a los ConfigMaps, pero con medidas extra de protección y tratamiento especial en el control plane.


Hay varios matices críticos para DevSecOps:

**5.1. Base64 no es cifrado**

Por defecto, los datos de un Secret se guardan **codificados en Base64**, lo cual **no aporta confidencialidad**; es solo un formato para representar datos binarios. Sin medidas adicionales, esos valores se almacenan en *etcd* prácticamente en claro. 


Por eso, los pasos mínimos de hardening son:

* **Activar cifrado en reposo (encryption at rest)** para Secrets en el API server, ya sea con un proveedor local (aescbc, secretbox, etc.) o mediante **KMS** del proveedor cloud.
* **Restringir fuertemente quién puede leer Secrets vía RBAC**, aplicando least privilege.
* Evitar exponer secretos en logs o salidas de `kubectl` compartidas.

**5.2. Cómo usar secretos en las apps sin "regar" credenciales**

Buenas prácticas orientadas a DevSecOps: 

* Preferir **montar Secrets como volúmenes de solo lectura** y leerlos como archivos, en lugar de pasarlos como variables de entorno (las env vars se filtran más fácilmente a logs, *crash dumps* o tooling).
* No incluir los valores de los secretos (ni siquiera en base64) en repositorios Git; usar herramientas como SOPS, External Secrets, Vault u operadores de secretos para integrarlos de forma segura.
* Limitar el acceso a Secrets por *namespace* y por `ServiceAccount`: una app solo debería poder leer **sus propios secretos**.
* Auditar operaciones sobre Secrets con los **audit logs** del API server.

En la práctica DevSecOps, esto se integra con:

* **Escáneres de secretos en código y repos** (evitar subir API keys).
* **Rotación periódica** y automatizada de credenciales.
* Cifrado de Secrets en repos GitOps y descifrado solo en el clúster (por ejemplo, con SOPS + KMS).

#### 6. Seguridad contextual: SecurityContext y Pod-level hardening

Aunque el foco suela ponerse en RBAC, políticas de admisión, NetworkPolicies y secretos, merece mención el **SecurityContext**, porque es donde se terminan de concretar muchas de esas políticas en cada Pod/contendor.

Con `securityContext` puedes definir, entre otras cosas:

* Si el contenedor corre como `root` o como un usuario no privilegiado (`runAsNonRoot`, `runAsUser`).
* Si el filesystem raíz es de solo lectura (`readOnlyRootFilesystem`).
* Qué *capabilities* de Linux se eliminan o se agregan.
* Si se permite escalada de privilegios (`allowPrivilegeEscalation: false`).
* Opciones de SELinux/AppArmor.

Las Pod Security Standards y tus políticas de admisión deberían **forzar** ciertos valores seguros (por ejemplo, "no se admiten Pods privilegiados, ni que corran como root"), mientras que el `securityContext` es la forma concreta en que el manifiesto de la app expresa esos requisitos.


Desde DevSecOps, esto se traduce en:

* Plantillas de deployment (Helm, Kustomize) que ya vienen endurecidas de serie.
* Validaciones automáticas que rechazan manifiestos sin `securityContext` apropiado.
* Tests en CI que fallan si un nuevo manifiesto pretende introducir contenedores privilegiados o sin límites de recursos.

#### 7. Integrando todo en una estrategia DevSecOps

Si juntamos las piezas:

* **RBAC** controla **quién puede hablar con el API y qué operaciones puede hacer**.
* **Políticas de admisión** (PSA, VAP, Gatekeeper/Kyverno) controlan **qué puede entrar al clúster y bajo qué condiciones**.
* **NetworkPolicies** controlan **quién puede hablar con quién en la red interna del clúster**.
* **Secrets** controlan **cómo manejamos credenciales y datos sensibles en un entorno distribuido y efímero**.
* **SecurityContext** aterriza muchas de esas reglas en cada Pod/contendor de forma concreta.

En un pipeline DevSecOps maduro, el flujo típico sería algo así:

1. **En diseño** se definen boundaries: namespaces, roles, perfiles de Pod Security, patrones de NetworkPolicy, estándares para secretos y `securityContext`.
2. **En código y build** se generan imágenes endurecidas, se firman, se crean manifests con RBAC, políticas de admisión, NetworkPolicies y uso correcto de Secrets.
3. **En CI** se ejecutan:

   * Chequeos estáticos de manifiestos (con policy-as-code).
   * Escáneres de vulnerabilidades de imágenes.
   * Validaciones contra benchmarks (CIS Kubernetes, etc.).
   * Escáneres de secretos sobre el repositorio.
4. **En CD y runtime**, el clúster aplica:

   * RBAC y TLS para los accesos al API.
   * Admission controllers que bloquean workloads inseguros.
   * NetworkPolicies de tipo "default deny + reglas explícitas".
   * Secrets cifrados en reposo, con RBAC estricto y auditoría.
   * `securityContext` coherentes con los estándares definidos.

El resultado es un clúster donde **un error puntual (un Pod vulnerable, una credencial filtrada) no debería convertirse automáticamente en un compromiso total de la plataforma**. El hardening no es una lista de checks aislados, sino un sistema coherente de barreras defensivas alineadas con el ciclo DevSecOps.

