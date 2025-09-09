### Terminología de Git para DevOps y DevSecOps

#### 1. Rama

Una rama representa una línea de desarrollo independiente que permite trabajar en cambios sin afectar otras partes del proyecto. Actúa como una abstracción del proceso de editar, preparar y confirmar (commit) cambios, proporcionando un directorio de trabajo, área de preparación e historial nuevos. Los commits se registran en la rama activa, creando bifurcaciones en el historial.

```
      commit A
         |
      commit B
       / 
commit C (rama secundaria)
```

- **Convenciones de nombres y vida útil:** Usar prefijos como feature/*, bugfix/*, hotfix/\* para ramas cortas, promoviendo un lead time bajo (métricas DORA). Ejemplo: feature/login-v2.
- **Reglas de protección:** Impedir force-push y exigir revisiones/checks (CI, SAST) antes de fusionar para garantizar calidad y seguridad.
- **Feature flags:** Desacoplan "desplegar" de "exponer", habilitando trunk-based development sin ramas largas, reduciendo riesgos en producción.

#### 2. Flujo de trabajo centralizado

El flujo de trabajo centralizado permite a equipos acostumbrados a Subversion adoptar Git sin grandes cambios. Todos los desarrolladores trabajan contra un repositorio central, facilitando la transición hacia flujos más avanzados.

```
 [Dev1]      [Dev2]
    \          /
     \        /
    [Servidor Central]
```

- **Riesgo operativo:** El servidor central es un punto único de fallo (SPOF); mitigar con CI/CD distribuido y backups probados.
- **Menor aprovechamiento DVCS:** Limita trabajo offline y revisiones paralelas. Recomendado para equipos pequeños o adopción inicial.

#### 3. Flujo de trabajo con ramas de funcionalidades

Basado en el flujo centralizado, el flujo de trabajo con ramas de funcionalidades encapsula nuevas funcionalidades en ramas dedicadas, usando pull requests (PRs) para discutir e integrar cambios al proyecto oficial.

```
        main
         |
         +----> feature (nueva funcionalidad)
```

- **Límites de tamaño:** PRs pequeños con checklist de riesgos, SAST e impacto para facilitar revisiones.
- **Merge queue:** Revalida cambios en la punta de main (rebase/merge automático) para evitar builds obsoletos aunque estuvieran "verdes".
- **Tiempo objetivo:** Mantener ramas vivas idealmente no más de 2–5 días para reducir conflictos y acelerar entrega continua (CD).

#### 4. Bifurcación (Forking)

El forking otorga a cada desarrollador su propio repositorio público en el servidor, además de uno local privado, en lugar de un único repositorio central.

```
   [Repositorio local]  <---->  [Repositorio público en servidor]
```

- **Fronteras de confianza:** Ejecutar CI en forks sin secretos, usando jobs con permisos mínimos y sin credenciales. Usar pull\_request en lugar de pull\_request\_target para evitar exposición de secretos.
- **CODEOWNERS y revisión obligatoria:** En el repositorio central, aplicar políticas para controlar calidad y seguridad.

#### 5. Flujo de trabajo Gitflow

El flujo de trabajo Gitflow organiza el desarrollo con ramas aisladas para características, lanzamientos y mantenimiento, ideal para proyectos con ciclos de lanzamiento estructurados.

```
           feature
              \
           develop --- release --- main/master
              /
         hotfix (mantenimiento)
```

- **Trade-off:** Proporciona estabilidad a costa de latencia en la integración.
- **Uso típico:** Proyectos con versiones "largas" o requisitos de compliance. En CD moderno, trunk-based con feature flags es más ágil.

#### 6. HEAD

HEAD es la referencia a la instantánea actual en Git. El comando git checkout actualiza HEAD para apuntar a una rama o commit. En modo "detached HEAD", se trabaja en un commit específico sin rama asociada. El nombre de la rama inicial se define en git init (init.defaultBranch). Antes del primer commit, HEAD apunta a esa rama "unborn"; la rama se materializa con el primer commit.

```
HEAD --> commit actual
```

- **Usos seguros:** Reproducir builds, realizar bisect o inspeccionar tags de releases.
- **Precaución:** En "detached HEAD", los commits pueden perderse si no se crea una rama o etiqueta antes de cambiar de contexto.

#### 7. Hook

Un hook es un script que se ejecuta automáticamente ante eventos específicos en Git, permitiendo personalizar flujos y automatizar tareas.

```
[Evento Git] --> [Script Hook] --> [Acción personalizada]
```

- **Local vs servidor:** Los hooks locales (client-side) educan a los desarrolladores (linters, detección de secretos); las políticas vinculantes deben implementarse en el servidor (pre-receive, branch protection, required checks) o en CI para garantizar cumplimiento.
- **Seguridad:** Usar pre-commit para validaciones ligeras (secrets, linters); SAST pesado en CI para evitar fricción local.

#### 8. Main (principal)

"main" suele ser la rama por defecto configurada en init.defaultBranch; se materializa con el primer commit.

```
main: commit1 --> commit2 --> commit3
```

- **Configuración:** El nombre depende de la configuración del proveedor o Git. Personalizable en plataformas como GitHub.
- **Reglas típicas:** Exigir firmas, checks verdes, bloquear force-push y opcionalmente forzar historial lineal.

#### 9. Solicitud de extracción (Pull request)

Las solicitudes de extracción (o Merge Requests en GitLab) facilitan la colaboración al permitir revisiones antes de integrar cambios al proyecto oficial.

```
(feature branch) ---> [Pull Request] ---> (main branch)
```

- **Plantillas:** Incluir checklists para pruebas, riesgos de seguridad, rollback plan y SBOM/attestations.
- **Automatización:** Vincular con CI/CD para pruebas y escaneos automáticos.

#### 10. Repositorio

Un repositorio almacena commits, ramas y etiquetas, representando el historial y estado del proyecto.

```
[Repositorio]
 |-- Commit A
 |-- Commit B
 |-- Ramas: main, feature, etc.
 |-- Etiquetas: v1.0, v2.0, etc.
```

- **Monorepo vs polyrepo:** Monorepos simplifican dependencias pero complican permisos; polyrepos dividen lógica pero requieren sincronización. Usar git sparse-checkout para CI eficiente.
- **Retención:** Políticas de archives, mirrors y recuperación ante desastres (RPO/RTO).

#### 11. Etiqueta (Tag)

Una etiqueta marca un punto específico en el historial, comúnmente para releases, sin actualizarse con nuevos commits.

```
commit ---[Tag v1.0]
```

- **Anotadas vs ligeras:** Preferir etiquetas anotadas y firmadas para auditoría en releases.
- **SemVer:** Usar v1.0.0, -rc, -hotfix para claridad en canales de liberación.

#### 12. Control de versiones

El control de versiones registra cambios en archivos, permitiendo recuperar versiones específicas.

```
[Versión 1] --> [Versión 2] --> [Versión 3]
```

- **DVCS:** Clones completos, trabajo offline y trazabilidad con SHA para auditorías y forensics.

#### 13. Árbol de trabajo (Working tree)

El árbol de trabajo contiene los archivos extraídos (checkout) del commit al que apunta HEAD, más cambios locales no confirmados.

```
Working Tree:
 ├── file1.txt (modificado)
 ├── file2.txt
 └── carpeta/
      └── file3.txt
```

- **Index/staging:** Capa para preparar commits atómicos, mejorando control.
- **CI efímero:** Usar shallow clone y clean checkout para builds reproducibles.

#### 14. Fusión (Merge)

La fusión integra cambios de una rama en otra, combinando historiales. En DevOps/DevSecOps, asegura estabilidad mediante CI y verificaciones de seguridad.

```
rama fuente
   |
   +--> [Fusión] --> rama destino
```

- **FF vs no-FF:** Fast-forward para linealidad; no-FF para preservar contexto de rama, útil en reverts.
- **Estrategia por defecto:** El motor de merge por defecto moderno es ort (antes recursive).
**Resolución de conflictos:** Definir owners técnicos y de seguridad para cambios sensibles. Usar -X ours/theirs con ort para sesgos puntuales; evitar la estrategia ours salvo casos documentados (p. ej., monorepo con zonas aisladas). Nota: -X ours/theirs son opciones de la estrategia (p. ej., ort). No confundir con la estrategia ours, que descarta todo el lado "theirs".

#### 15. Rebase

El rebase reescribe el historial aplicando commits sobre una nueva base, creando una historia lineal.

```
commit antiguo --> [Rebase] --> commit nuevo (sobre base actualizada)
```

- **Regla de oro:** Solo en ramas locales no compartidas para evitar conflictos colaborativos.
- **Cumplimiento:** Evitar en main/release; usar revert para deshacer con trazabilidad.

#### 16. Cherry-pick

El cherry-pick aplica un commit específico de una rama a otra sin fusionar todo el historial.

```
rama A: commit X
          |
        [Cherry-pick] --> rama B
```

- **Backports de seguridad:** Documentar tracking de parches para consistencia.
- **Riesgo:** Evitar abuso para no duplicar historial; preferir hotfixes encapsulados.

#### 17. Stash

El stash guarda temporalmente cambios no confirmados, permitiendo cambiar de contexto sin perder trabajo.

```
[Cambios locales] --> [Stash] --> [Aplicar más tarde]
```

- **Uso moderado:** Usar -u para archivos no rastreados; evitar stashes huérfanos.
- **Alternativa:** Crear ramas temporales para mejor trazabilidad.

#### 18. Bisect

El bisect realiza una búsqueda binaria para identificar el commit que introdujo un error.

```
commit bueno --> [Bisect] --> commit malo (identificado)
```

- **Automatización:** Usar git bisect run con pruebas/escaneos para acelerar MTTR y localizar vulnerabilidades.

#### 19. Submódulo (Submodule)

Un submódulo es un repositorio Git incrustado, usado para gestionar dependencias externas.

```
[Repositorio principal]
  └── [Submódulo: repositorio dependiente]
```

- **Inmutabilidad:** Fijar submódulos a commits específicos para auditoría y SBOM.
- **Desafíos:** Sincronización, nested submodules y permisos. Considerar git subtree o artefactos versionados como alternativas.

#### 20. GitOps

GitOps usa Git como fuente de verdad para configuraciones e infraestructura, aplicando cambios declarativamente.

```
[Repositorio Git] --> [Operador GitOps] --> [Infraestructura declarada]
```

- **Policy-as-Code:** Usar OPA/Conftest para reglas como "denegar imágenes con tag latest", cobertura mínima u owners por rutas.
- **Provenance y attestations:** Vincular commits/tags con SLSA/in-toto para trazabilidad.

#### 21. Reglas de protección de ramas

Las reglas de protección de ramas restringen acciones en ramas sensibles, exigiendo revisiones y checks.

```
rama protegida
  ├── Requiere: revisiones
  ├── Requiere: pruebas CI
  └── Requiere: escaneos de seguridad
```

- **Configuración estricta:** Firmas obligatorias, cobertura mínima, límites de tamaño de PR y bloqueo si falla SAST/SCA/IaC.

#### 22. Commits firmados

Los commits firmados usan firmas criptográficas (GPG) para verificar autenticidad e integridad.

```
commit --> [Firma GPG] --> commit verificado
```

- **Gestión de claves:** Rotar/expirar claves, usar DCO/CLA si aplica, exigir tags firmados en releases.
- **Firmas de artefactos:** Firmar imágenes/paquetes con provenance enlazada al SHA/tag.

#### 23. Estrategias de fusión

Las estrategias de fusión determinan cómo Git resuelve conflictos al combinar ramas (fast-forward, ort por defecto, recursive —legado—, ours/theirs).

```
estrategia: fast-forward
rama A --> [Fusión sin commit extra] --> rama B
```

- **Ours/Theirs:** Usar -X ours/theirs en ort para resolución específica; evitar la estrategia ours salvo casos documentados en monorepos.

#### 24. Shift Left Security

Shift Left Security integra prácticas de seguridad desde las primeras etapas del SDLC, como en commits o PRs.

```
[Desarrollo temprano] --> [Seguridad integrada] --> [Ciclo SDLC]
```

- **Orden recomendado:** Pre-commit (secrets/lint ligero), PR (SAST/SCA/IaC), post-merge (DAST en staging).
- **Trazabilidad:** Adjuntar reportes de seguridad como artefactos versionados.

#### 25. SAST (Static Application Security Testing)

SAST analiza el código fuente estáticamente para detectar vulnerabilidades, como inyecciones SQL.

```
[Código fuente] --> [Análisis SAST] --> [Reporte de vulnerabilidades]
```

- **Integración:** Reglas rápidas en pre-commit; análisis profundo en CI de PR para evitar fricción.

#### 26. DAST (Dynamic Application Security Testing)

DAST evalúa aplicaciones en ejecución para detectar vulnerabilidades runtime, como XSS.

```
[Aplicación en ejecución] --> [Pruebas DAST] --> [Detección de exploits]
```

- **Uso:** En CI/CD post-merge, en staging con gates claros para producción y criterios de rollback observables (error rate/latencia).

#### 27. SCA (Software Composition Analysis)

SCA identifica vulnerabilidades en dependencias de terceros, como bibliotecas externas.

```
[Dependencias] --> [Análisis SCA] --> [Reporte de riesgos]
```

- **Integración:** En PRs para submódulos o archivos de dependencias, alertando sobre CVEs.

#### 28. Secrets Management

Secrets Management maneja credenciales sensibles de forma segura, evitando su exposición en Git.

```
[Secrets sensibles] --> [Gestión segura] --> [Inyección en runtime]
```

- **Respuesta a incidentes:** Rotar claves, limpiar historial con BFG/filter-repo, notificar.
**Inyección segura:** Usar vaults (p. ej., HashiCorp Vault) en runtime, no en Git.

#### 29. Bash Scripting en Git

Bash Scripting automatiza tareas en Git mediante scripts, comunes en hooks y CI/CD, ejecutando validaciones o integraciones.

```
[Evento Git] --> [Script Bash ejecutado] --> [Validación o acción]
```

- **Calidad:** Usar opciones seguras como set -euo pipefail, validar con herramientas como ShellCheck, generar salidas claras.
- **Portabilidad:** Preferir orquestación en CI (YAML) para políticas independientes del entorno.

#### 30. Pre-commit Hook

El pre-commit hook valida cambios antes de un commit, ideal para linters, detección de secretos y SAST ligero.

```
[git commit] --> [Pre-commit Hook] --> [Validar y proceder/abortar]
```

- **Ejemplo:** Escanear secretos con herramientas como git-secrets o validar formato con Prettier.

#### 31. Post-merge Hook

El post-merge hook se ejecuta tras una fusión, útil para builds, notificaciones o escaneos DAST.

```
[Fusión completada] --> [Post-merge Hook] --> [Acciones posteriores]
```

- **Uso:** Integrar con CI para validar integridad post-fusión.

#### 32. Pre-push Hook

El pre-push hook valida cambios antes de un push al repositorio remoto.

```
[git push] --> [Pre-push Hook] --> [Verificar antes de remoto]
```

- **Aplicación:** Pruebas unitarias, chequeos de firmas o compliance en DevSecOps.

#### 33. Algoritmo de Hashing en Git (SHA)

Git usa SHA-1 (migrando a SHA-256) para generar IDs únicos de objetos, asegurando integridad.

```
[Objeto Git] --> [Hash SHA] --> [ID único: 40 (SHA-1) o 64 (SHA-256) dígitos hex]
```

- **Seguridad:** SHA-256 mejora resistencia a colisiones; amplia compatibilidad con SHA-1. Firmas de commits/tags y attestations son clave para integridad.

#### 34. Algoritmo de Diff en Git

El algoritmo de diff (Myers, patience) compara cambios entre versiones para revisiones y auditorías.

```
[Versión A] --> [Diff Algorithm] --> [Cambios vs. Versión B]
```

- **Opciones:** --patience/--word-diff mejoran legibilidad en refactors; -M detecta renombres y -C ayuda a detectar copias para revisiones de seguridad en refactors grandes.

#### 35. Compresión Delta en Git

La compresión delta almacena diferencias entre objetos en packfiles, optimizando espacio.

```
[Objeto base] --> [Delta] --> [Objeto comprimido]
```

- **Balance:** Optimiza almacenamiento pero consume CPU en CI; usar caching para eficiencia.

#### 36. Integración Continua (CI)

CI integra cambios frecuentemente al repositorio principal, ejecutando builds y pruebas automáticas.

```
[Commit/Pull Request] --> [Pipeline CI] --> [Build & Test]
```

- **Seguridad:** Incluir SAST/SCA como checks obligatorios.

#### 37. Entrega Continua (CD)

CD automatiza o permite despliegues a producción tras validaciones exitosas.

```
[CI exitosa] --> [Pipeline CD] --> [Despliegue a producción]
```

- **Gates:** Aprobaciones y monitoreo post-despliegue para rollback.
- **Estrategia de releases:** Usar "release trains" o calendarios; definir criterios de promoción/rollback con SLO/SLA.

#### 38. Pipeline CI/CD

Un pipeline CI/CD orquesta etapas automatizadas (build, test, deploy) definidas en YAML.

```
Etapa 1: Build --> Etapa 2: Test/Seguridad --> Etapa 3: Deploy
```

- **Seguridad:** Incluir SAST, DAST, SCA y gates de aprobación.

#### 39. Webhook

Un webhook notifica servicios externos ante eventos Git, como push o merge.

```
[Evento Git] --> [Webhook] --> [Servicio externo]
```

- **Seguridad:** Verificar firma/HMAC para evitar ejecuciones no autorizadas.

#### 40. Artefacto (Artifact)

Un artefacto es un output de CI/CD, como binarios o reportes, almacenado para reutilización.

```
[Pipeline] --> [Generar Artefacto] --> [Almacenamiento/Despliegue]
```

- **DevSecOps:** Incluir SBOM, provenance y reportes de seguridad; prohibir latest para inmutabilidad. Firmar artefactos con enlace al SHA/tag.

#### 41. Conventional Commits

Conventional Commits es un estándar para mensajes de commit que facilita la generación automática de changelogs y versionado semántico (SemVer).

```
fix: corregir error en autenticación
feat: añadir soporte para OAuth2
```

- **Uso:** Automatizar release notes y versionado; mejora trazabilidad en auditorías.

#### 42. Respuesta a incidentes

La respuesta a incidentes en Git implica mitigar errores o vulnerabilidades con trazabilidad.

```
[Incidente detectado] --> [Revert/Parche] --> [PR documentado]
```

**Práctica:** Preferir revert (auditable) sobre reset en ramas compartidas; enlazar incidentes a PRs/commits para forensics.
