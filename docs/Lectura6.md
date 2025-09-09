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
- **Reglas de protección:** Impedir **force-push** y exigir revisiones/checks (CI, SAST) antes de fusionar para garantizar calidad y seguridad.
- **Feature flags:** desacoplan el despliegue de la exposición al usuario, posibilitando trunk-based development (TBD) sin ramas de larga vida y mitigando riesgos en producción.

#### 2. Flujo de trabajo centralizado

El flujo de trabajo centralizado permite a equipos acostumbrados a *Subversion* adoptar *Git* sin grandes cambios. Todos los desarrolladores trabajan contra un repositorio central, facilitando la transición hacia flujos más avanzados.

```
 [Dev1]      [Dev2]
    \          /
     \        /
    [Servidor central]
```

- **Riesgo operativo:** El servidor central es un punto único de fallo ([SPOF](https://apolitical.co/solution-articles/es/punto-unico-de-falla-de-un-concepto-critico-para-el-exito-de-la-mision)), por lo que debe mitigarse con CI/CD distribuido y respaldos (backups) probados.
- **Menor aprovechamiento DVCS:** Limita trabajo offline y revisiones paralelas. Recomendado para equipos pequeños o adopción inicial.

#### 3. Flujo de trabajo con ramas de funcionalidades

Basado en el flujo centralizado, el flujo de trabajo con ramas de funcionalidades encapsula nuevas funcionalidades en ramas dedicadas, usando **pull requests** (PRs) para discutir e integrar cambios al proyecto oficial.

```
        main
         |
         +----> feature (nueva funcionalidad)
```

- **Límites de tamaño:** PRs pequeños con checklist de riesgos, SAST e impacto para facilitar revisiones.
- **Cola de fusión (merge queue):** Revalida cada PR sobre la última punta de `main` haciendo rebase/merge automático y re-ejecutando la CI antes de integrarlo. Así se evita fusionar cambios basados en pipelines "verdes" **(estado de CI exitosa: todas las pruebas y checks pasaron)** pero desactualizados.
- **Tiempo objetivo:** Mantener ramas vivas idealmente no más de 2-5 días para reducir conflictos y acelerar entrega continua (CD).

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
- **Uso típico:**  En entornos de **CD** actuales, **trunk-based development** con **banderas de características (feature flags)** permite **integrar a diario en `main`**, **desplegar continuamente** y **activar funcionalidades de forma gradual** (canary, *gradual rollout*, A/B, *kill switches*). Esto reduce la **latencia** y el **riesgo** siempre que exista **CI robusta**, buena cobertura de pruebas, *merge queue* y **observabilidad con rollback rápido**.

#### 6. HEAD
HEAD es la referencia a la instantánea actual en Git. El comando `git checkout` actualiza HEAD para apuntar a una rama o a un commit. En modo "detached HEAD" se trabaja en un commit específico sin rama asociada. El nombre de la rama inicial se define en `git init` (`init.defaultBranch`). Antes del primer commit, HEAD apunta a esa rama "unborn". La rama se materializa con el primer commit.

```
HEAD --> commit actual
```

- **Usos seguros:** Reproducir builds, realizar bisect o inspeccionar tags de releases.
- **Precaución:** En "[detached HEAD](https://www.git-tower.com/learn/git/faq/detached-head-when-checkout-commit)", los commits pueden perderse si no se crea una rama o etiqueta antes de cambiar de contexto.

#### 7. Hook

Un hook es un script que se ejecuta automáticamente ante eventos específicos en Git, permitiendo personalizar flujos y automatizar tareas.

```
[Evento Git] --> [Script Hook] --> [Acción personalizada]
```

- **Local vs servidor:** Los **hooks locales (client-side)** brindan **feedback rápido** y ayudan a **educar a los desarrolladores**. Se deben usar para tareas como **linters**, **formateo** y **detección de secretos** antes del commit. Aun así, **no garantizan el cumplimiento** porque cada persona puede desactivarlos o ignorarlos en su entorno. Las **políticas vinculantes** deben vivir en el **servidor** o en la **CI** para asegurar cumplimiento.

  -  **En el servidor:** reglas **pre-receive**, **protección de ramas**, **CODEOWNERS**, **revisiones obligatorias**, **firmas requeridas** y **estados de verificación** que impiden integrar cambios si no se cumplen.
  -  **En la CI:** **checks obligatorios** como **pruebas**, **cobertura mínima**, **SAST**, **SCA** e **IaC**, que actúan como **gates** y **bloquean el merge o el push** cuando fallan.

- **Seguridad:** Usar **pre-commit** para validaciones ligeras (detección de secretos, linters y formateo) y así dar feedback inmediato sin frenar el flujo local. Dejar el **SAST** más pesado para la **CI**, donde puede ejecutarse con reglas completas y tiempos de análisis mayores sin afectar la productividad y garantizando el cumplimiento de forma uniforme.

#### 8. Main (principal)

"main" suele ser el nombre de la rama por defecto definido en `init.defaultBranch` y se materializa con el primer commit.

```
main: commit1 --> commit2 --> commit3
```

- **Configuración:** El nombre depende de la configuración del proveedor o Git. Personalizable en plataformas como GitHub.
- **Reglas típicas:** Exige **firmas criptográficas** en commits y, si aplica, en tags para asegurar autoría e integridad. Requiere **checks en verde** antes de fusionar, incluyendo pruebas, cobertura mínima y escaneos SAST, SCA e IaC como estados obligatorios. **Bloquea el force-push** para preservar un historial auditable y evitar pérdida de referencias. Puedes **forzar historial lineal** para mantener una línea de tiempo clara y facilitar bisect y auditorías. Completa con **aprobaciones mínimas** y **CODEOWNERS** para rutas sensibles, rechazo de aprobaciones obsoletas cuando cambie la base, verificación de que la rama esté **actualizada con `main`**, límites de tamaño de PR, políticas de nombres y relación con tickets. Restringe quién puede fusionar o etiquetar, activa **merge queue** para revalidar en la punta de `main` y registra todo en la plataforma para trazabilidad y cumplimiento.

#### 9. Solicitud de extracción (Pull request)

Las solicitudes de extracción (o Merge Requests en GitLab) facilitan la colaboración al permitir revisiones antes de integrar cambios al proyecto oficial.

```
(feature branch) ---> [Pull Request] ---> (main branch)
```

- **Plantillas:** Incluir checklists para pruebas, riesgos de seguridad, rollback plan y [SBOM/attestations](https://edu.chainguard.dev/open-source/sbom/sboms-and-attestations/).
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

- **Monorepo vs polyrepo:** Monorepos simplifican dependencias pero complican permisos. Los polyrepos dividen lógica pero requieren sincronización. Usar [git sparse-checkout](https://git-scm.com/docs/git-sparse-checkout) para CI eficiente.
- **Retención:** Políticas de archivado, replicación y recuperación ante desastres ([RPO/RTO](https://blog.purestorage.com/es/purely-technical/rto-vs-rpo-whats-the-difference/)).

#### 11. Etiqueta (Tag)

Una etiqueta marca un punto específico en el historial, comúnmente para releases, sin actualizarse con nuevos commits.

```
commit ---[Tag v1.0]
```

- **Anotadas vs ligeras:** Preferir **etiquetas anotadas y firmadas** para auditar las **versiones publicadas** (**releases**): marcan de forma verificable puntos de lanzamiento (p. ej., `v1.2.3`) con metadatos de autor, fecha y mensaje, más **firma criptográfica (GPG)**. Esto permite trazar el **commit exacto** que generó los artefactos (imágenes, paquetes, binarios), producir **changelogs confiables** y cumplir requisitos de **compliance**.
- **SemVer:**  Usar **SemVer** para nombrar versiones y distingue los **canales de liberación** con sufijos de *pre-release* cuando aplique.
  - **Estable:** `v1.0.0` (versión publicada para producción).
  - **Release candidate (RC):** `v1.0.0-rc.1`, `v1.0.0-rc.2` (candidatas a estable).
  - **Beta/alpha (opcional):** `v1.1.0-beta.1`, `v1.1.0-alpha.1` (pruebas tempranas).
  - **Hotfix:** **incrementa PATCH** y publica estable: `v1.0.1`.
    - Si necesitas marcarlo explícitamente, usa **metadatos de build**: `v1.0.1+hotfix.1`.
    - Evita `-hotfix` como *pre-release*, porque SemVer lo trata como **no estable**.

**Recomendación:** Etiquetar con **tags anotados y firmados** y automatizar la promoción entre canales (alpha -> rc -> estable) en la pipeline.

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
- **CI efímero:** Ejecuta cada job en un entorno desechable e idéntico, sin arrastrar estado. Usa clonaciones superficiales para traer solo el historial necesario y un checkout limpio que garantice que el árbol de trabajo no contiene artefactos previos ni archivos sin seguimiento. Valida el SHA del commit, fija versiones de herramientas y dependencias y restaura únicamente cachés de dependencias verificadas. Con agentes efímeros y entornos declarativos, aceleras la descarga, evitas contaminación entre builds, mejoras seguridad y obtienes resultados reproducibles consistentes.

#### 14. Fusión (Merge)

La fusión integra cambios de una rama en otra, combinando historiales. En DevOps/DevSecOps, asegura estabilidad mediante CI y verificaciones de seguridad.

```
rama fuente
   |
   +--> [Fusión] --> rama destino
```

- **FF vs no-FF**: El fast-forward avanza el puntero y mantiene una historia lineal, ideal para cambios pequeños y frecuentes. El no fast-forward crea un commit de fusión que preserva el contexto de la rama, facilita revertir una funcionalidad completa y deja puntos de anclaje para auditoría.
- **Estrategia por defecto**: El motor moderno es **[ort](https://mattrickard.com/git-merge-strategies-and-algorithms)**, más rápido y preciso que **recursive**, con mejores heurísticas para renombres y resolución de conflictos.
* **Resolución de conflictos**: Define responsables técnicos y de seguridad para rutas sensibles, documenta reglas por directorio y acuerda criterios de aceptación. Con **ort** puedes usar las opciones **-X ours** o **-X theirs** para sesgos puntuales en un merge, por ejemplo preferir cambios de la rama destino en archivos generados. Evitar la **estrategia ours** como práctica general, ya que descarta todo el contenido del lado contrario y puede ocultar cambios, salvo escenarios muy acotados como zonas claramente aisladas en un monorepo.

#### 15. Rebase

El rebase reescribe el historial aplicando commits sobre una nueva base, creando una historia lineal.

```
commit antiguo --> [Rebase] --> commit nuevo (sobre base actualizada)
```

-  **Regla de oro:** El rebase reescribe el historial y cambia los identificadores de los commits. Usar solo en ramas locales que nadie más consuma. Así se evita romper pull requests, revisiones en curso, firmas criptográficas y referencias externas. Antes de publicar una rama, sincroniza mediante una integración limpia y evita reescrituras una vez que otros dependan de ella.
-  **Cumplimiento:** En ramas compartidas como `main` o `release` se debe prohibir. Conservar un historial auditable y predecible con integraciones protegidas y cola de fusión. Si se necesita deshacer un cambio ya integrado, se crea un **revert** que deje evidencia y permita rehacer si es necesario. Para excepciones se define un procedimiento con aprobación explícita, ventanas controladas y verificación de integridad. Documentar quién autoriza, qué se modificó y por qué. Mantén escáneres y pipelines como guardianes para asegurar trazabilidad y reducir riesgo operativo.

#### 16. Cherry-pick

El cherry-pick aplica un commit específico de una rama a otra sin fusionar todo el historial.

```
rama A: commit X
          |
        [Cherry-pick] --> rama B
```

- **Backports de seguridad:** Definir versiones soportadas y ventana de soporte. Ante una vulnerabilidad, se evalúa el impacto, abre un ticket con CVE, ramas afectadas, commit de origen, pruebas y pasos de validación. Aplicar el parche como cherry pick trazable, actualizar notas de versión, SBOM y dependencias, etiquetar la versión y vincular artefactos firmados. Mantener un tablero con estado, responsables, fechas objetivo y métricas de latencia. Verificar en CI con pruebas y SAST para asegurar consistencia y auditoría.
- **Riesgo:** El abuso del cherry pick duplica historial y crea divergencias difíciles de mantener, introduce conflictos, omite dependencias, complica forensics y puede romper parches futuros. Priorizar hotfixes encapsulados desde una rama de corrección que se integra a todas las ramas soportadas y luego vuelve a `main`. Documentar la ruta de promoción, aplica pruebas de regresión, automatiza el [forward port](https://es.wikipedia.org/wiki/Redirecci%C3%B3n_de_puertos), limita excepciones y mide MTTR y cobertura.

#### 17. Stash

El stash guarda temporalmente cambios no confirmados, permitiendo cambiar de contexto sin perder trabajo.

```
[Cambios locales] --> [Stash] --> [Aplicar más tarde]
```

-  **Uso moderado:** Tratar como estacionamiento temporal y no como almacenamiento a largo plazo. Incluir también archivos no rastreados con la opción **-u** cuando se necesite preservar trabajo nuevo. Añadir un mensaje claro a cada entrada, revisa periódicamente la lista y aplica o elimina lo pendiente para evitar **stashes huérfanos**, entradas olvidadas que ya no están vinculadas a un trabajo activo y que pueden perderse con tareas de limpieza. No usar para traspasos entre personas ni para cambios críticos, porque no deja un rastro auditable.
-  **Alternativa:** Crear una **rama temporal** desde tu estado actual y registra uno o más commits pequeños. Esa rama puede compartirse en remoto, pasar por CI y recibir revisión, lo que mejora la **trazabilidad** y reduce el riesgo de pérdida. Más adelante se puede integrar de forma controlada o eliminarla sin afectar el historial principal.

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
- **Desafíos:** Sincronización, submodules anidados y permisos. Considerar git subtree o artefactos versionados como alternativas.

#### 20. GitOps

GitOps usa Git como fuente de verdad para configuraciones e infraestructura, aplicando cambios declarativamente.

```
[Repositorio Git] --> [Operador GitOps] --> [Infraestructura declarada]
```
- **Policy-as-Code:** Define reglas declarativas y verificables con **OPA/Conftest** y se debe mantener versionadas en Git. Se usa para **denegar imágenes con etiqueta `latest`**, exigir **cobertura mínima**, imponer **owners y revisiones por ruta**, limitar **tamaños de PR**, validar **nombres**, evitar **secretos** en manifiestos y controlar **recursos**. Ejecutar en **CI** como *gates* de PR y en **runtime** con **admission controllers** compatibles con OPA Gatekeeper o Kyverno. Añade **tests de políticas**, reportes de cumplimiento, **excepciones con caducidad y justificación** y trazabilidad completa.
- **Provenance y atestaciones:** Genera metadatos **firmados criptográficamente** que describan cómo, dónde y con qué insumos se construyó cada artefacto. Hay que apoyarse en **SLSA** para niveles de garantía y en **in-toto** para modelar la cadena de pasos. Firma **artefacto y atestación** y hay que enlazar al **commit o tag** correspondiente. Publica **SBOMs**, hashes, identidad del *builder* y parámetros de build. Verifica en despliegue que **firma y commit aprobado** coincidan y registra evidencias para auditoría y respuesta a incidentes.

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

-  **Gestión de claves:** Establecer propietarios, almacén seguro (KMS/HSM), rotación y expiración programadas, y revocación inmediata ante offboarding o incidentes. Exige commits y tags firmados y, si aplica, DCO/CLA. Audita registros, comprueba huellas y caducidad en CI, y documenta políticas de recuperación, respaldo y cadencia de rotación.
-  **Firmas de artefactos:** Firma imágenes y paquetes con metadatos de procedencia que enlacen el artefacto al SHA del commit o tag aprobado. Publica SBOM y evidencias de compilación. Verifica firmas y procedencia en la admisión de despliegues y bloquea si no coinciden políticas, identidades y huellas registradas.

#### 23. Estrategias de fusión
Las **estrategias de fusión** definen cómo Git integra historiales al unir ramas.

- **fast-forward:** Mueve el puntero sin crear commit de merge cuando la historia es lineal, útil para mantener historial limpio.
- **ort (predeterminada):** Resuelve la mayoría de conflictos con buen rendimiento y manejo de renombres, crea un commit de merge cuando es necesario.
- **recursive (legado):** Estrategia anterior aún disponible por compatibilidad.
- **ours / theirs (estrategias):** Fuerzan que el resultado final provenga solo de un lado, apropiado en casos muy controlados como subárboles o áreas aisladas.

```
estrategia: fast-forward
rama A --> [Fusión sin commit extra] --> rama B
```

- No confundir estas estrategias con las **opciones** `-X ours` y `-X theirs`, que solo **sesgan la resolución** dentro de **ort** o **recursive** pero mantienen el merge. Elige **fast-forward** para linearidad y **no fast-forward** cuando quieras **preservar el contexto** de la rama integrada.
  
#### 24. Shift Left Security

[Shift Left Security](https://orca.security/resources/blog/what-is-shift-left-security/) integra prácticas de seguridad desde las primeras etapas del SDLC, como en commits o PRs.

```
[Desarrollo temprano] --> [Seguridad integrada] --> [Ciclo SDLC]
```

- **Orden recomendado:** Pre-commit (secrets/lint ligero), PR (SAST/SCA/IaC), post-merge (DAST en staging).
- **Trazabilidad:** Adjuntar reportes de seguridad como artefactos versionados.

#### 25. SAST (Static Application Security Testing)

[SAST](https://www.checkpoint.com/es/cyber-hub/cloud-security/what-is-static-application-security-testing-sast/) analiza el código fuente estáticamente para detectar vulnerabilidades, como inyecciones SQL.

```
[Código fuente] --> [Análisis SAST] --> [Reporte de vulnerabilidades]
```

- **Integración:** Ejecutar comprobaciones ligeras en pre-commit para dar feedback inmediato sin bloquear al equipo: reglas rápidas, patrones inseguros frecuentes, validación de convenciones y detección básica de secretos. Reservar el análisis profundo para la CI de los PR, con escaneo diferencial (solo cambios), límites de tiempo, reglas por severidad y cachés para acortar ejecución. Publicar reportes (por ejemplo [SARIF](https://sarifweb.azurewebsites.net/)) como artefactos, marca el pipeline como fallido ante hallazgos críticos y exige correcciones o excepciones justificadas con caducidad. Alinear las políticas con CODEOWNERS y aplica *gates* por riesgo, manteniendo bajo el tiempo de ciclo y alta la calidad de seguridad.

#### 26. DAST (Dynamic Application Security Testing)

[DAST](https://www.fortinet.com/lat/resources/cyberglossary/dynamic-application-security-testing) evalúa aplicaciones en ejecución para detectar vulnerabilidades runtime, como XSS.

```
[Aplicación en ejecución] --> [Pruebas DAST] --> [Detección de exploits]
```
- **Uso:** Ejecutar en CI/CD post-merge sobre un entorno de **staging** muy parecido a producción. Definir **gates claros** para la promoción: pruebas autenticadas, alcance controlado, lista de URLs permitidas, datos de prueba y límite de tiempo. Establecer **criterios objetivos** basados en métricas observables como **tasa de error**, **latencia p95**, **códigos 5xx** y **ausencia de vulnerabilidades críticas**. Integrar **triage** con severidad y **SLA de corrección**, aplica mitigaciones temporales como **reglas de WAF** cuando proceda y **reescanea** antes de promover. Usa **despliegues graduales o canary** con observabilidad activa y **hooks de rollback automáticos** si las métricas o hallazgos superan umbrales definidos.

#### 27. SCA (Software Composition Analysis)

[SCA](https://www.checkpoint.com/es/cyber-hub/cloud-security/what-is-software-composition-analysis-sca/) identifica vulnerabilidades en dependencias de terceros, como librerías externas.

```
[Dependencias] --> [Análisis SCA] --> [Reporte de riesgos]
```

- **Integración:** Ejecutar en los **PR** que toquen **submódulos** o **archivos de dependencias** para detectar vulnerabilidades conocidas (**CVEs**) y problemas de licencia. Anotar el PR con **paquete afectado**, **versión**, **severidad**, **ruta de dependencia** y **enlace a la asesoría**, y ofrece **remediaciones sugeridas**. Bloquear la fusión cuando haya hallazgos **críticos o altos** y exige **actualización**, **parche** o **excepción temporal** con caducidad y justificación. Vigilar dependencias **transitivas**, verifica **integridad** y **fijación de versiones**, genera **SBOM** y registra artefactos. Complementar con bots de actualización automática como **Dependabot** o **Renovate** y métricas de **tiempo de remediación**.

#### 28. Gestión de secretos (Secrets management)

Secrets Management maneja credenciales sensibles de forma segura, evitando su exposición en Git.

```
[Secrets sensibles] --> [Gestión segura] --> [Inyección en runtime]
```
- **Respuesta a incidentes:** Ante exposición de secretos, contiene y corrige de inmediato. **Revocar y rotar** claves, tokens de API, llaves SSH y credenciales de CI. **Invalidar** sesiones y firmas de webhooks. **Escanear** el repositorio completo, issues y artefactos para hallar otras filtraciones. **Limpiar el historial** con BFG o filter-repo, crea una referencia limpia y coordina con mirrors y forks para evitar reintroducciones. **Registrar el incidente** con severidad, línea de tiempo, responsables y acciones correctivas. **Notificar** a equipos afectados y a terceros cuando aplique. **Reforzar controles** preventivos y añade reglas de detección en CI y pre-commit.
- **Inyección segura:** No guardar secretos en Git ni en imágenes. **Gestionar** credenciales en un vault confiable y **emitir** credenciales de vida corta con identidades de workload basadas en OIDC. **Inyectar** secretos en runtime mediante variables, volúmenes o sidecars con **rotación automática**. **Restringir** acceso con RBAC mínimo necesario, **auditar** uso, **cifrar** en tránsito y en reposo, y referencia solo **nombres** de secretos en IaC y pipelines.

#### 29. Scripts de Bash en Git

Un script de Bash automatiza tareas en Git mediante scripts, comunes en hooks y CI/CD, ejecutando validaciones o integraciones.

```
[Evento Git] --> [Script Bash ejecutado] --> [Validación o acción]
```

- **Calidad:** Usar opciones seguras como set -euo pipefail, validar con herramientas como ShellCheck, generar salidas claras.
- **Portabilidad:** Preferir orquestación en CI (YAML) para políticas independientes del entorno.

#### 30. Pre-commit hook

El pre-commit hook valida cambios antes de un commit, ideal para linters, detección de secretos y SAST ligero.

```
[git commit] --> [Pre-commit Hook] --> [Validar y proceder/abortar]
```

- **Ejemplo:** Escanear secretos con herramientas como git-secrets o validar formato con [Prettier](https://prettier.io/).

#### 31. Post-merge hook

El post-merge hook se ejecuta tras una fusión, útil para builds, notificaciones o escaneos DAST.

```
[Fusión completada] --> [Post-merge Hook] --> [Acciones posteriores]
```

- **Uso:** Integrar con CI para validar integridad post-fusión.

#### 32. Pre-push hook

El pre-push hook valida cambios antes de un push al repositorio remoto.

```
[git push] --> [Pre-push Hook] --> [Verificar antes de remoto]
```

- **Aplicación:** Pruebas unitarias, chequeos de firmas o cumplimiento (compliance) en DevSecOps.

#### 33. Algoritmo de hashing en Git (SHA)

Git usa SHA-1 (migrando a SHA-256) para generar IDs únicos de objetos, asegurando integridad.

```
[Objeto Git] --> [Hash SHA] --> [ID único: 40 (SHA-1) o 64 (SHA-256) dígitos hex]
```

* **Seguridad:** Preferir **SHA-256** por su mayor resistencia a colisiones y planifica la migración sin romper integraciones que aún esperan **SHA-1**. Git puede operar en modo SHA-1 o SHA-256 y muchos ecosistemas siguen usando SHA-1 por compatibilidad. Para garantizar integridad, utilizar **firmas verificables** en **commits** y **tags** y acompáñarlas con **atestaciones de procedencia** de los artefactos. Vincular cada build al **SHA del commit** o al **tag firmado**, publica **SBOM** y **hashes** y verificar firmas tanto en **CI** como en la **admisión a producción**. Hay que establecer políticas que bloqueen cambios con identidades no verificadas o con discrepancias entre el artefacto liberado y el commit declarado.

#### 34. Algoritmo de Diff en Git

Git compara versiones con distintos algoritmos de *diff* para apoyar revisiones y auditorías.

- **Myers (predeterminado):** eficiente y tiende a producir parches pequeños al buscar la secuencia común más larga. Es ideal para cambios típicos y ofrece buen rendimiento.
-  **Patience:** prioriza líneas únicas para reducir ruido y mejorar la legibilidad en refactors, reordenamientos y archivos con muchos movimientos.

Complementar con ajustes de comparación a **nivel de palabras**, opciones para **ignorar espacios**, y detección de **renombres** y **copias** para mantener el contexto histórico. Estos diffs alimentan procesos de **código seguro**, análisis diferencial en **SAST**, generación de **changelogs**, trazabilidad para **auditoría** y soporte a investigaciones **forenses** cuando necesitas identificar con precisión qué cambió y por qué.

```
[Versión A] --> [Diff Algorithm] --> [Cambios vs. Versión B]
```

- **Opciones:** --patience/--word-diff mejoran legibilidad en refactors; -M detecta renombres y -C ayuda a detectar copias para revisiones de seguridad en refactors grandes.

#### 35. Compresión delta en Git

Git almacena blobs, árboles y commits en **packfiles** y, para ahorrar espacio, representa muchos objetos como **deltas** respecto a un **objeto base**. Al reconstruir un archivo o una versión, aplica esa cadena de diferencias hasta obtener el contenido completo. Durante tareas de mantenimiento como **repack** o **gc**, reordena y recalcula deltas para maximizar la compresión y la localidad, lo que reduce el tamaño del repositorio y el ancho de banda en fetch y push, especialmente cuando hay historiales largos o archivos que cambian parcialmente en cada versión.

```
[Objeto base] --> [Delta] --> [Objeto comprimido]
```

**Balance:** La alta compresión disminuye almacenamiento y transferencia, pero incrementa uso de CPU al crear y aplicar deltas, algo sensible en CI efímero. Mitigar con **cachés de packfiles y dependencias**, **fetch superficial** con profundidad adecuada, reutilización de artefactos, y programando **repack** fuera del camino crítico. Preferir almacenamiento rápido (NVMe/SSD) para acelerar lectura y escritura de packfiles. Activar compresión paralela cuando la herramienta lo permita para reducir tiempos de repack sin saturar el job. **Observa métricas:** duración de checkout/fetch, tiempo de descompresión y tasa de acierto de caché. Con esos datos, ajusta profundidad de clone, tamaño de cachés y ventanas de mantenimiento según carga y costos.

#### 36. Integración continua (CI)

CI integra cambios frecuentemente al repositorio principal, ejecutando builds y pruebas automáticas.

```
[Commit/Pull Request] --> [Pipeline CI] --> [Build & Test]
```

- **Seguridad:** Incluir SAST/SCA como checks obligatorios.

#### 37. Entrega continua (CD)

CD automatiza o permite despliegues a producción tras validaciones exitosas.

```
[CI exitosa] --> [Pipeline CD] --> [Despliegue a producción]
```

- **Gates:** Definir aprobaciones mínimas con CODEOWNERS y segregación de funciones, valida CI en verde, cobertura y escaneos SAST, SCA e IaC, y revisa riesgos y tamaño del cambio. Exigir ticket, plan de despliegue, plan de reversión y checklist de readiness. Desplegar de forma gradual con canary o porcentajes y habilita observabilidad en tiempo real. Monitorear errores, latencia, códigos 5xx y métricas de negocio. Activar rollback automático si se superan umbrales o si cae el SLO. Registrar evidencia y comunica el estado a las partes interesadas para trazabilidad y auditoría.
- **Estrategia de releases:** Definir una **cadencia fija** o **calendario**. Establece **cut-off**, abre **rama de release** y da una **ventana de estabilización**. Promover solo si se cumplen criterios: **pruebas en verde**, **riesgos aceptados**, **sin vulnerabilidades críticas**, **rendimiento dentro de lo esperado** y **artefactos firmados con procedencia**. Mantener políticas claras de **rollback** y **roll forward**, vincula decisiones a **SLO/SLA** y **documenta** todo. Usar **feature flags** para separar **despliegue** de **activación** y reducir riesgo.

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

* **DevSecOps:** Generar y publicar **SBOM**, **provenance** y **reportes de seguridad** por cada build. Prohibir imágenes o paquetes con etiqueta **`latest`** para mantener **inmutabilidad** y usa **versiones fijas** y **digests por SHA**. **Firma** artefactos y **atestaciones** y enlázalos al **SHA del commit** o al **tag firmado**. Guardar todo en el **registry** con retención y control de acceso. En el pipeline y en la **admisión a producción** verifica firmas, digests, políticas y ausencia de vulnerabilidades críticas y **bloquea** si no cumplen. Registrar evidencias y vincular al **PR** y a la **release** para auditoría.

#### 41. Commit convencionales (Conventional commits)

**Conventional Commits** es un estándar para redactar mensajes de commit que facilita la generación automática de *changelogs* y el versionado semántico (SemVer).

```
fix: corregir error en autenticación
feat: añadir soporte para OAuth2
```

* **Uso:** Automatizar las notas de versión y el versionado y mejorar la trazabilidad en auditorías.


#### 42. Respuesta a incidentes

La respuesta a incidentes en Git implica mitigar errores o vulnerabilidades con trazabilidad.

```
[Incidente detectado] --> [Revert/Parche] --> [PR documentado]
```

- **Práctica:** Preferir revert (auditable) sobre reset en ramas compartidas; enlazar incidentes a PRs/commits para forensics.
