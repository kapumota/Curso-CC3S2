### Introducción a Git para devops

#### 1) Arquitectura distribuida y modelo operativo

Git es un sistema distribuido en el que cada clon es un repositorio completo con historial íntegro y metadatos, lo que permite ejecutar la mayoría de las operaciones de forma local y sin latencia de red. 
Ese diseño reduce puntos únicos de falla, da autonomía a cada nodo y facilita flujos de trabajo asíncronos en los que la sincronización se  realiza cuando conviene a cada equipo. 

La colaboración se sostiene con intercambio de objetos entre repositorios mediante `fetch`, `pull` y `push`, que transfieren commits, árboles y blobs. 
Esta naturaleza descentralizada habilita a los equipos a trabajar en modo desconectado y a definir estrategias de ramas adecuadas a su cadencia de integración, manteniendo la velocidad de las operaciones diarias que interrogan el historial como `log`, `diff` o `blame`.

#### 2) DAG del historial y árboles de Merkle

El historial en Git se modela como un grafo acíclico dirigido donde cada commit referencia a sus padres y a un árbol que captura la instantánea del proyecto. 
La ausencia de ciclos y la direccionalidad permiten reconstruir estados exactos, localizar el ancestro común en fusiones y razonar sobre  la procedencia de los cambios. 

Para asegurar integridad, Git emplea estructuras tipo **[Merkle](https://medium.com/geekculture/understanding-merkle-trees-f48732772199)** dondecada objeto se identifica por un hash del contenido y los enlaces entre objetos propagan cualquier modificación hacia arriba. 
Un cambio en un archivo altera su blob y el árbol que lo contiene, y termina alterando el hash del commit que lo referencia, de modo que las alteraciones quedan expuestas. 
Históricamente Git ha usado SHA-1 y hoy convive con SHA-256 para reforzar resistencia a colisiones, con mecanismos de transición que protegen compatibilidad y herramientas auxiliares. 

En términos de almacenamiento y transferencia, la combinación de hashing fuerte y referencias estructuradas habilita compresión y delta encoding efectivos que reducen espacio y aceleran clonaciones y actualizaciones.

#### 3) Anatomía interna del repositorio

El directorio `.git` es el corazón de un repo. Allí residen la base de datos de objetos, referencias, índices y configuración. La carpeta `objects` almacena blobs, árboles y commits indexados por su hash. 
Con `git cat-file -p <hash>` es posible inspeccionar cualquier objeto para ver, por ejemplo, el árbol asociado a un commit o el contenido de un blob que representa un archivo en una revisión específica. 
Esta inspección permite entender que Git es esencialmente un almacén clave valor y que el grafo del historial se materializa con punteros hash entre objetos. 
La indexación por los dos primeros bytes del hash en subdirectorios agiliza accesos y mantiene el repositorio organizado. 

Además, `git show` ofrece una vista legible de un commit con su mensaje y el diff asociado, mientras que `git cat-file` brinda una perspectiva de bajo nivel útil para aprendizaje y auditoría.

**Ejemplo**

```bash
# Inspeccionar la estructura interna de un commit
git show HEAD~1

# Ver vínculos del commit con su árbol y padre
git cat-file -p HEAD

# Navegar un árbol específico y descubrir blobs
git cat-file -p <hash_de_tree>
```

#### 4) Ciclo de vida de archivos y flujo cotidiano

Cada archivo puede estar no rastreado, sin modificar, modificado o preparado para commit. El flujo cotidiano de trabajo transita por `status` para visualizar el estado, `add` para mover cambios al área de preparación y `commit` para confirmarlos de forma atómica. 
El staging permite agrupar cambios coherentes que fortalecen la trazabilidad y facilitan auditorías. 

Herramientas de inspección como `log` con variantes `--graph` y `--oneline` ayudan a entender el historial y a preparar notas de versión. En escenarios de colaboración, `blame` ofrece contexto de última edición por línea y `show` explora objetos puntuales.

**Ejemplo**

```bash
# Vista del estado y diferencias
git status
git diff         # cambios en el directorio de trabajo
git diff --staged  # cambios ya preparados

# Confirmación atómica con firma GPG si corresponde
git commit -m "agregar API de pagos"

# Auditoría del historial para preparar release notes
git log --date=iso --graph --decorate --oneline
```

#### 5) Packfiles, delta encoding y paralelización

Para economizar espacio y acelerar intercambios, Git empaqueta objetos en packfiles que combinan compresión y delta encoding. En lugar de duplicar versiones completas, almacena diferencias entre revisiones y aplica compresión para reducir el tamaño final. 
La creación de packs se beneficia de paralelización interna que distribuye cálculo de deltas y compresión en varios hilos, algo clave en repositorios grandes. 
Esto acelera operaciones de red como `fetch` y reduce el tiempo de reconstrucción local. 

En pipelines de CI y en espejos internos, mantener repos con GC programada y packs optimizados acorta tiempos de checkout y mejora el throughput de agentes que construyen y prueban en paralelo.

**Ejemplo**

```bash
# Mantenimiento de salud del repo
git gc
git maintenance start
git maintenance run --task=commit-graph
```

#### 6) Algoritmos de diferencias y reconciliación de historia

El cálculo de diferencias entre versiones de archivos se basa en algoritmos de comparación de secuencias como **[Myers](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/)**, que produce diffs mínimos a nivel de líneas con buen equilibrio entre precisión y rendimiento.
Sobre ese sustrato de comparaciones se apoyan los algoritmos de fusión y rebase.

El **merge de tres vías** identifica primero el ancestro común más cercano entre las ramas a integrar y compara cada punta con esa base. Los cambios que no se solapan se integran automáticamente. 
Cuando hay ediciones en regiones coincidentes, Git marca conflictos y deja al usuario la combinación. 
La estrategia recursiva lida con situaciones de múltiples bases y despliega detección de renombres basada en similitud de contenido para  evitar conflictos falsos cuando archivos se movieron o renombraron sin cambios sustanciales. 
Para integrar varias ramas sin conflictos en un solo paso existe la estrategia **octopus**, típicamente usada para agrupar trabajos independientes.

En los últimos años Git incorporó el backend de fusión **[ORT](https://behindmethods.com/blog/merge-made-by-the-ort-strategy/)** como reemplazo moderno al algoritmo recursivo tradicional en muchos escenarios. 
ORT optimiza la detección de conflictos, mejora el rendimiento en repositorios grandes y reduce casos límite donde antes aparecían conflictos difíciles de interpretar. En la práctica, ORT y la heurística de renombres trabajan sobre los diffs que aporta Myers u otras variantes, y su objetivo es minimizar intervención humana preservando la intención de cada cambio.

**Ejemplo**

```bash
# Ensayar una fusión de tres vías y visualizar conflictos
git switch main
git merge feature-x

# Habilitar una política conservadora en pulls
git pull --ff-only
```

#### 7) Rebase, cherry-pick y estrategias de historia

**Rebase** toma una secuencia de commits y los reaplica sobre otra base, creando nuevos hashes. Esto permite mantener historias lineales que simplifican auditorías y bisect. 
En ramas de vida corta es habitual rebasar contra la rama principal antes de integrar.  La modalidad interactiva facilita reordenar, combinar con squash o fixup, reescribir mensajes y editar commits. 
Como regla de oro en colaboración, evitar reescribir historia ya publicada.

```bash
# Mantener una rama al día con la rama principal sin mezclar commits de fusión
git fetch origin
git rebase origin/main

# Limpieza interactiva antes de proponer una integración
git rebase -i origin/main
```

**Cherry-pick** aplica un commit específico sobre otra rama. Es esencial para hotfix que deben propagarse a ramas de mantenimiento sin llevar otros cambios adyacentes.

```bash
# Tomar un fix puntual y aplicarlo a la rama de release
git switch release/1.2
git cherry-pick <hash_del_fix>
```

#### 8) Reset, restore y revert

`reset` mueve referencias y opcionalmente ajusta index y árbol de trabajo. Es poderoso y debe usarse con cuidado en ramas compartidas. `restore` modifica index o árbol de trabajo sin tocar referencias, útil para descartar cambios locales sin riesgo para el historial. 
`revert` crea un commit que invierte un cambio previo sin reescritura, ideal en repos colaborativos donde la historia publicada se considera inmutable.

```bash
# Descartar cambios en el árbol de trabajo de un archivo
git restore --worktree path/al/archivo

# Volver el index a HEAD para un conjunto de archivos
git restore --staged path/al/archivo

# Crear un commit inverso de uno anterior
git revert <hash>
```

#### 9) Colaboración, sincronización y políticas sanas

`remote` administra orígenes y espejos. `fetch` trae referencias sin mezclar. `pull` combina `fetch` más integración en la rama actual. 
Para equipos con políticas estrictas de historia lineal, `pull --ff-only` previene commits de merge accidentales. 

Cuando una rama local fue rebasada y aún no se movió en el remoto, `push --force-with-lease` es preferible ya que verifica que nadie haya avanzado la referencia remota en paralelo, lo que reduce riesgo de pisar trabajo ajeno.

```bash
git remote -v
git fetch --all --tags
git pull --ff-only
git push --force-with-lease
```

#### 10) Diagnóstico y salud del repositorio

`bisect` ejecuta una búsqueda binaria sobre el DAG para ubicar el commit que introdujo una regresión. `fsck` valida conectividad e integridad de objetos. `gc` compacta y elimina basura. 
El comando `maintenance` programa tareas como generación del commit-graph o prefetch que mantienen repositorios ágiles. 

Para auditoría de packs, `verify-pack` e `index-pack` permiten inspeccionar contenidos y verificar consistencia, lo que resulta útil en entornos donde se sospecha corrupción o anomalías de transferencia.

```bash
# Búsqueda binaria del commit defectuoso
git bisect start
git bisect bad           # marcar versión con fallo
git bisect good v1.4.2   # marcar versión conocida como buena
# tras identificar el commit culpable
git bisect reset

# Verificación de integridad
git fsck
```

#### 11) Estrategias de fusión en DevOps y detección de renombres

Desde la perspectiva de entrega continua, la fusión debe equilibrar velocidad y previsibilidad. En ramas de **feature** conviene rebasar para evitar divergencias largas. 
En integraciones de largo aliento con varios equipos, un merge explícito documenta convergencias complejas. La heurística de renombres basada en similitud de contenido reduce conflictos artificiales cuando archivos cambiaron de nombre. 
En fusiones con múltiples bases, aplicar la estrategia recursiva garantiza que el algoritmo compare correctamente las diferencias contra una base común y no mezcle cambios incompatibles. 

Para agrupar mejoras independientes como dependencia actualizada, limpieza de linter y documentación, un **octopus merge** permite consolidar sin ruido, siempre que no existan conflictos.

#### 12) Comandos esenciales orientados a DevOps

Esta selección prioriza reproducibilidad, trazabilidad y diagnósticos rápidos en pipelines y operaciones del día a día.

**Identidad, políticas y repos iniciales**

```bash
# Identidad y políticas locales
git config --global user.name "Tu Nombre"
git config --global user.email "tu@correo"
git config --global core.autocrlf input
git config --global commit.gpgsign true

# Inicialización de repos
git init
git init --bare
```

**Ciclo cotidiano con trazabilidad**

```bash
# Preparar cambios por partes con intención clara
git add -p

# Confirmaciones pequeñas y atómicas
git commit -m "corregir cálculo de impuestos"

# Auditoría de historia para generar notas de versión
git log --no-merges --pretty=format:"%h %ad %an %s" --date=short
```

**Revisión y calidad antes de integrar**

```bash
# Comparación de ramas para PRs largos
git range-diff origin/main...feature/nueva-api

# Ver archivos que introdujo un commit y su contexto
git show --stat <hash>
```

**Políticas de sincronización seguras**

```bash
# Traer cambios sin integrar automáticamente
git fetch origin

# Integrar solo con fast forward
git pull --ff-only
```

**Mantenimiento y packs**

```bash
# Programar mantenimiento de repos con actividades periódicas
git maintenance start
git maintenance run --task=gc
git maintenance run --task=commit-graph
```

**Diagnóstico y rollback seguro**

```bash
# Aislar la regresión con bisect y un script de prueba
git bisect start
git bisect bad
git bisect good <tag_estable>

# Revertir sin reescribir historia publicada
git revert <hash>
```

**Hotfix dirigido y promoción controlada**

```bash
# Propagar un fix crítico a una rama de release
git cherry-pick <hash_del_fix>
git tag -a v1.2.3 -m "release 1.2.3"
git push origin v1.2.3
```

**Inspección interna para auditoría**

```bash
# Validar conectividad e integridad
git fsck

# Ver objetos empaquetados y tamaños
git verify-pack -v .git/objects/pack/pack-*.idx
```

#### 13) Conexión con los fundamentos internos

Entender el almacén clave valor y la organización del `.git` permite razonar con mayor criterio ante incidencias de infraestructura como repositorios corruptos, fallos de red o agentes de CI con caches inconsistentes. 
Inspeccionar objetos con `cat-file` y navegar árboles para verificar qué hash referencia un commit ayuda a establecer causas raíz sin depender de capas superiores. 

Al mismo tiempo, comprender el DAG y los árboles de Merkle refuerza la confianza en la inmutabilidad del historial y en la posibilidad de detectar alteraciones. 

Estas competencias internas se traducen en prácticas más sólidas en DevOps, donde reproducibilidad, verificación y trazabilidad son pilares diarios.
