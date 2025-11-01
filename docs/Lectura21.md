### **¿Qué es la virtualización?**

La virtualización es una técnica que permite **crear y ejecutar entornos lógicos** (instancias virtuales) sobre uno o varios servidores físicos para **aprovechar mejor los recursos**, **aislar cargas de trabajo** y **simplificar la operación**. En la práctica, se implementa con **máquinas virtuales (VM)** o con **contenedores**, que persiguen objetivos similares mediante **mecanismos distintos**.

Si recién comienzas con la virtualización, esto es lo esencial:

1. **Eficiencia y gestión de recursos.** Ejecuta múltiples cargas de trabajo en el mismo servidor sin interferencias, delimitando CPU, memoria y almacenamiento por instancia.
2. **Escalabilidad.** Crea nuevas instancias bajo demanda para pruebas, picos de cómputo o separación de entornos.
3. **Aislamiento y seguridad.** El aislamiento reduce el "daño colateral", la seguridad final depende de **configuración, permisos y parches**.
4. **Portabilidad.** Plantillas e imágenes permiten **replicar entornos** en otros hosts o nubes.
5. **Contenerización.** Además de las VM, los **contenedores** ofrecen empaquetados ligeros para apps y dependencias, con **arranque rápido** y **alta densidad**.

Para más información: [What is virtualization? (IBM)](https://www.ibm.com/think/topics/virtualization) y [Virtualization 101 (VMware)](https://www.vmware.com/solutions/cloud-infrastructure/virtualization)

### **¿Qué es una máquina virtual?**

Una **máquina virtual (VM)** es un entorno aislado que **ejecuta un sistema operativo invitado completo** sobre un **hipervisor** (software que reparte el hardware físico entre varias VMs). Cada VM tiene su **kernel propio**, drivers y espacio de usuario.

1. **Entornos aislados.** Cada VM se comporta como un equipo independiente (SO, procesos, paquetes).
2. **Gestión de recursos.** CPU, RAM y disco se asignan por VM, puedes ajustarlos con políticas de cuota/prioridad.
3. **Escalabilidad.** Aprovisiona nuevas VMs para separar desarrollo, prueba y producción o para escalar pipelines.
4. **Instantáneas y copias de seguridad.** Las **instantáneas** sirven para **rollback rápido**, **no sustituyen** respaldos externos.
5. **Versatilidad.** Ejecuta distintos sistemas operativos (Linux, Windows) según la necesidad.
6. **Seguridad.** Buen aislamiento entre VMs, requiere parches, endurecimiento y control de acceso.
7. **Compatibilidad con la nube.** Servicios tipo IaaS facilitan el ciclo de vida de VMs administradas.

**Puente hacia contenedores.** Mientras la VM aísla con **hipervisor + SO invitado**, los **contenedores** ejecutan procesos **que comparten el kernel del host**, con aislamiento de **namespaces** y control de recursos mediante **cgroups** (ver siguiente sección).

Para más información: [What is a Virtual Machine (VM)? (VMware)](https://www.vmware.com/topics/virtual-machine)

### **Introducción a los contenedores**

Un **contenedor** empaqueta **aplicación + dependencias + configuración** y se ejecuta como **procesos aislados** que **comparten el kernel** del host. Esto ofrece **arranque rápido**, **alta densidad** y **portabilidad** entre equipos y nubes.

1. **Fundamentos de la contenerización.** Garantiza consistencia ("funciona igual aquí y en producción") y reduce conflictos de librerías.
2. **Portabilidad.** Construyes una imagen una vez y la ejecutas donde haya un runtime compatible.
3. **Eficiencia.** Menor huella que una VM: no hay SO invitado por instancia, el kernel es compartido.
4. **Escalabilidad.** Replicas contenedores para absorber demanda, ideales para microservicios y pipelines de datos.
5. **Consistencia.** El mismo artefacto (imagen) se usa en dev, CI y prod, minimizando sorpresas.
6. **Ciclo de vida ágil.** Builds rápidos, despliegues atómicos y rollbacks simples.

**Diferencia técnica clave.** El aislamiento de contenedores se basa en **namespaces** (por ejemplo, `pid`, `net`, `mnt`, `ipc`, `uts`) y el control de recursos en **cgroups** (CPU, memoria, IO). En VM, el aislamiento proviene del **hipervisor** y cada VM tiene **su propio kernel**. **Un contenedor no es una "VM pequeña".**

**Nota terminológica.** **Docker** es una **plataforma** (daemon/CLI/formato de imagen), el **contenedor** es la **unidad de ejecución**. No son sinónimos.

**Prácticas mínimas de seguridad en contenedores:**

* Ejecuta como **usuario no-root** (`USER` en Dockerfile).
* **Reduce capabilities** y usa `read_only` cuando aplique.
* **Genera SBOM** y **escanea vulnerabilidades** (Syft/Grype/Trivy) en cada build.

> Además de namespaces y cgroups, los contenedores pueden filtrar **syscalls** con **seccomp** y el **host** puede reforzar con AppArmor/SELinux.

Para aprender más: [Containers vs. VMs (Microsoft Learn)](https://learn.microsoft.com/en-us/virtualization/windowscontainers/about/containers-vs-vm)


### **Docker: la plataforma de contenedores**

**Docker** es una **plataforma** de contenerización: provee formato de **imagen**, **runtime**, **daemon** y **CLI** para crear, compartir y ejecutar contenedores de forma consistente entre desarrollo, prueba y producción. Un **contenedor** es la **unidad de ejecución** (app + dependencias + config), mientras que **Docker** es el **conjunto de herramientas** para construir, publicar y operar esas unidades.

**Contenedores vs. Docker (la plataforma)**

* **Contenedores**: unidades ligeras y aisladas que empaquetan aplicación, dependencias y configuración. Se ejecutan como **procesos** que comparten el **kernel** del host con aislamiento de **namespaces** y control de recursos con **cgroups**; aportan portabilidad y arranque rápido.
* **Docker**: plataforma y herramientas (daemon/CLI) para **construir imágenes**, **ejecutar contenedores**, **gestionar redes/volúmenes** y **distribuir artefactos** (registros). Facilita un flujo estandarizado para crear, versionar y desplegar.

**En síntesis**: el contenedor es la tecnología de ejecución; **Docker** es la plataforma que la hace práctica y productiva en el día a día.

> Referencia: [Docker Overview](https://docs.docker.com/get-started/docker-overview/) (Docker Docs)


### **Uso de la línea de comandos de Docker (CLI)**

La **CLI de Docker** permite construir imágenes, ejecutar/inspeccionar contenedores y administrar recursos (redes, volúmenes) desde la terminal. A continuación, lo esencial con la **nomenclatura moderna** (subcomandos agrupados):

#### Comandos básicos (día a día)

* **Ejecutar contenedores**

  * `docker run IMAGE ...`: crea e inicia un contenedor (puertos, volúmenes, envs).
  * `docker ps` / `docker ps -a`: lista contenedores (en ejecución / todos).
  * `docker stop/ start/ restart NAME|ID`: controla ciclo de vida.
* **Imágenes**

  * `docker build -t NAME:TAG .`: construye una imagen desde un `Dockerfile`.
  * `docker image ls` *(=`docker images`)*: lista imágenes locales.
  * `docker pull/push NAME:TAG`: descarga/publica desde/hacia un registro.
  * `docker rmi IMAGE`: elimina imágenes no usadas.
* **Contenedores**

  * `docker container ls` *(=`docker ps`)*, `docker container rm NAME|ID`: gestiona instancias.
* **Diagnóstico rápido**

  * `docker logs -f NAME|ID`: sigue logs.
  * `docker exec -it NAME|ID sh|bash`: entra al contenedor para depurar.

#### Redes, volúmenes y recursos

* **Redes**: `docker network ls`, `docker network create`, `docker network inspect`
* **Volúmenes**: `docker volume ls`, `docker volume create`, `docker volume inspect`
* **Inspección detallada**: `docker inspect NAME|ID`

#### Multi-contenedor con Compose (V2)

Usa **`docker compose`** (no `docker-compose`):

* `docker compose up -d`: inicia la app definida en `docker-compose.yml`.
* `docker compose ps`: estado de los servicios.
* `docker compose logs -f [SERVICE]`: sigue logs.
* `docker compose down`: detiene y limpia recursos (opcional `--volumes`).

#### Buenas prácticas mínimas (seguridad y entrega)

* **Imágenes**: evita `latest`; usa **tags inmutables** o digests; preferir **multi-stage builds**; base mínima (por ejemplo, `-slim`).
* **Usuario no-root**: en `Dockerfile`, define `USER app` y permisos adecuados.
* **Superficie de ataque**: `read_only: true`, **capabilities mínimas** (`--cap-drop ALL` y añadir solo las necesarias).
* **SBOM y escaneo**: genera **SBOM** (Syft) y escanea (Trivy/Grype) en cada build.
* **Variables y secretos**: usa **env vars** (sin commitear `.env`) y mecanismos de secretos del orquestador/host.

> Referencias:
>
> * [Use the Docker Command Line](https://docs.docker.com/reference/cli/docker/) (Docker Docs)
> * [Compose V2](https://docs.docker.com/compose/) (Docker Docs)



### **Creación de una imagen de Docker (paso a paso)**

Las **imágenes** son los artefactos que empaquetan tu aplicación con sus dependencias y configuración. Se definen con un **Dockerfile** y se construyen con `docker build`.

1. **Crear el Dockerfile**

   * Crea un archivo llamado **`Dockerfile`** en la raíz de tu proyecto. Este archivo contiene las **instrucciones de construcción** de tu imagen.
   * Elige una **imagen base** adecuada (idealmente mínima y con versión fija), por ejemplo `python:3.12-slim` o `node:22-alpine`.

2. **Definir dependencias**

   * Instala dependencias del sistema y del lenguaje (librerías, paquetes).
   * Añade un **`.dockerignore`** para evitar copiar archivos innecesarios (por ejemplo, `.git/`, `__pycache__/`, `node_modules/`).

3. **Copiar el código de la aplicación**

   * Usa **`COPY`** (preferir sobre `ADD` salvo tar/URL) indicando **rutas precisas** de origen y destino.

4. **Configurar ajustes**

   * Define variables con **`ENV`** (solo valores no sensibles). Los **secretos** deben venir por entorno/gestor de secretos externo.
   * Fija **zona de trabajo** con `WORKDIR /app`.

5. **Exponer puertos (si aplica)**

   * Declara **`EXPOSE 8080`** (documenta puerto de escucha). Recuerda que la **exposición real** la decides con `-p` o en Compose.

6. **Definir el comando de inicio**

   * Usa **`CMD`** para el comando por defecto y **`ENTRYPOINT`** cuando quieras forzar un binario principal. Mantén **forma JSON** (sin shell) salvo que necesites expansión de variables.

7. **Construir la imagen**

   * En la carpeta del Dockerfile:

     ```bash
     docker build -t mi-app:1.0 .
     ```

     Recomendado: usa **tags inmutables** (versión o digest) y evita `latest`.

8. **Probar la imagen**

   * Ejecuta un contenedor para validar:

     ```bash
     docker run --rm -p 8080:8080 mi-app:1.0
     ```

9. **Publicar la imagen (opcional)**

   * Etiqueta y empuja a un registro (Docker Hub u otro):

     ```bash
     docker tag mi-app:1.0 usuario/mi-app:1.0
     docker push usuario/mi-app:1.0
     ```

**Buenas prácticas mínimas (muy recomendadas)**

* **Multi-stage build** para reducir tamaño y superficie de ataque.
* Ejecutar como **usuario no-root** (`USER app`).
* Mantener **base mínima** (`-slim`, `-alpine` cuando sea viable).
* Generar **SBOM** y escanear vulnerabilidades (Syft/Trivy/Grype) en cada build.

**Ejemplo (Python, multi-stage y no-root)**

```dockerfile
# Etapa de build
FROM python:3.12-slim AS build
WORKDIR /app
COPY pyproject.toml poetry.lock* ./
RUN pip install --no-cache-dir --upgrade pip poetry \
 && poetry export -f requirements.txt -o requirements.txt
COPY . .

# Etapa final
FROM python:3.12-slim
RUN useradd -m app
WORKDIR /app
COPY --from=build /app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=build /app ./
USER app
EXPOSE 8080
CMD ["python", "main.py"]
```

Para más información: [Packaging your Software](https://docs.docker.com/build/concepts/dockerfile/) y [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/).


### Redes y aislamiento con Docker

La red define **quién puede hablar con quién** y bajo **qué condiciones**. En Docker, casi todo ocurre sobre redes **bridge** (NAT), con DNS interno y reglas de `iptables` administradas por el Engine. Un diseño prudente evita publicar puertos "por costumbre", minimiza privilegios y documenta las dependencias explícitas.

#### Redes *bridge* y puertos

**Concepto clave:** dentro de una **red bridge definida por el usuario**, los contenedores se descubren por **nombre de servicio** y pueden comunicarse **sin publicar puertos al host**. Publicar (`-p`) es exponer un borde de confianza hacia fuera.

**Tipos habituales**

* `bridge` *por defecto*: tráfico entre contenedores que se unan a esa red; NAT hacia el host.
* `host`: el contenedor comparte la pila de red del host (**no aísla puertos**).
* `none`: sin red (sandbox útil para *jobs* offline).
* **User-defined bridge** (recomendado): DNS integrado, *isolation* por nombre de red y control explícito.

**Publicar vs. no publicar**

* **Sin publicar** (preferido): `web -> db:5432` dentro de la misma red. Ningún puerto de `db` es accesible desde el host.
* **Publicar**: `-p 8080:80` crea una regla DNAT (`iptables`) para que el host (y posiblemente su red) acceda al contenedor.

**Por qué publicar es una decisión de seguridad**

* Abre una **frontera** (host->contenedor). Requiere **razón documentada**, verificación de **TLS**, **auth** y **rate limiting** (si aplica).
* Reduce la ambigüedad operativa: si no está publicado, **no es accesible** desde fuera (menos superficie).

**Compose: dos redes, un único servicio publicado**

```yaml
services:
  web:
    build: .
    ports: ["8080:8080"]         # único borde expuesto
    networks: ["frontend", "backend"]
    depends_on:
      db: { condition: service_healthy }

  db:
    image: postgres:16
    networks: ["backend"]         # NO accesible desde el host
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 10s; timeout: 3s; retries: 10

networks:
  frontend: { driver: bridge }
  backend:  { driver: bridge }
```

**Verificaciones rápidas (host)**

```bash
docker network ls
docker network inspect <red>
docker ps --format 'table {{.Names}}\t{{.Ports}}'
# NAT creado por publish
sudo iptables -t nat -S | grep DOCKER
# Comprobar que DB no está expuesta
ss -tulpen | grep -E ':5432|:8080'
```

**Notas finas**

* `EXPOSE` en Dockerfile **no** abre puertos; solo documenta.
* Testea endpoints **desde la misma red** sin exponer:

  ```bash
  docker run --rm --network <red> curlimages/curl \
    curl -fsS http://web:8080/health
  ```
* Activa **IPv6** solo si sabes cómo filtrar/monitorear ese plano (reglas separadas).

#### Namespaces y cgroups (alto nivel)

Docker aísla por **namespaces** y **limita** por **cgroups**, compartiendo **el mismo kernel** del host. Es un **aislamiento de procesos**, no una VM.

**Namespaces principales**

* `pid`: procesos aislados (no ves PIDs del host).
* `net`: interfaces/puertos virtuales por contenedor/red.
* `mnt`: *mounts* (sistema de archivos y *bind mounts*).
* `ipc`: colas y memoria compartida.
* `uts`: `hostname` y `domainname`.
* `user`: mapeo de UIDs/GIDs (con **rootless**: `root` del contenedor ≠ `root` del host).

**cgroups (v1/v2)**

* Límite/cuota de **CPU** (`--cpus`), **memoria** (`--memory`), **blkio** (I/O), **pids** (número de procesos).
* Reducen *blast radius*: un *leak* o bucle infinito no tumba el host.

**No es una sandbox "dura"**

* Con privilegios excesivos (por ejemplo, `--privileged`, `SYS_ADMIN`, montajes peligrosos) puedes **interferir** con el host.
* Vulnerabilidades del **kernel** afectan a todos: contenedor y host comparten kernel.
* **Docker rootless** + **user namespace** mejoran la defensa (UID del contenedor mapeado a un UID sin privilegios en el host).

**Endurecimiento recomendado**

* Ejecutar como **usuario no-root** (`USER app`) y considerar **rootless Docker**.
* Mantener **perfil seccomp** por defecto (bloquea syscalls peligrosas).
* **AppArmor/SELinux** activos (con políticas al menos por defecto).
* Montajes seguros: `:ro`, `noexec`, `nodev`, `nosuid` cuando aplique.
* Evitar montar el **socket Docker** (`/var/run/docker.sock`) dentro de contenedores (equivale a root en el host).

**Verifica el aislamiento dentro del contenedor**

```bash
# PID namespace aislado
cat /proc/self/status | grep -E 'CapEff|CapBnd'
# Límites efectivos
cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes
# Perfil seccomp activo (indicio)
grep Seccomp /proc/self/status
```

#### Capacidades Linux

Linux fragmenta privilegios de `root` en **capabilities**. Docker comienza con un conjunto por defecto y permite **quitar** (`--cap-drop`) o **añadir** (`--cap-add`) capacidades. En auditoría, **añadir** capacidades es *bandera roja*; `--privileged` es *alarma*.

**Patrón: mínimo privilegio**

* **Quita todo** (`cap_drop: ["ALL"]`).
* **Añade solo** lo imprescindible, con justificación y evidencia (por ejemplo, un puerto <1024 requiere `NET_BIND_SERVICE`).

**Riesgos comunes**

* `SYS_ADMIN`: poder "demi-Dios" (montajes, namespaces…); evita salvo *appliance* dedicado.
* `NET_ADMIN`: cambiar rutas/iptables; solo para *network utilities* muy controladas.
* `SYS_PTRACE`: depuración avanzada; evita en producción.
* `DAC_OVERRIDE`/`DAC_READ_SEARCH`: saltarse permisos DAC; peligrosas si se combinan con montajes amplios.

**Ejemplos**

*Docker CLI: puerto 80 sin elevar privilegios innecesarios*

```bash
docker run --rm \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --read-only \
  -p 80:80 mi-web:1.0
```

*Compose: endurecimiento base*

```yaml
services:
  web:
    image: mi-web:1.0
    ports: ["8080:8080"]
    user: "1000:1000"      # no-root
    read_only: true
    cap_drop: ["ALL"]
    # cap_add: ["NET_BIND_SERVICE"]  # solo si hace falta
    security_opt:
      - no-new-privileges:true
      # - apparmor:docker-default   # (Docker Desktop/Linux)
      # - label:type:container_t    # (SELinux, si aplica)
    tmpfs: ["/tmp:rw,noexec,nosuid,nodev"]
```

**Cómo auditar capacidades rápidamente**

```bash
# Capabilidades efectivas del proceso PID 1 en el contenedor
docker exec -it web sh -lc 'grep Cap /proc/1/status'
# Ver si alguien coló 'privileged'
docker inspect web --format '{{.HostConfig.Privileged}}'
# Revisar añadidos puntuales
docker inspect web --format '{{json .HostConfig.CapAdd}}'
```

**Guardrails de política (opcional, OPA/conftest)**

* Bloquear `privileged: true`.
* Requerir `cap_drop: ["ALL"]`.
* Permitir solo `NET_BIND_SERVICE` bajo etiqueta `needs-low-port: "true"`.
* Denegar `devices:` y `extra_hosts` salvo lista de confianza.
* Rechazar `ports:` fuera de un **allowlist** (por ejemplo, 80/443 en *frontend*).

**Ejemplo de regla (pseudoregla Rego)**

```rego
deny[msg] {
  input.services[_].hostConfig.Privileged == true
  msg := "privileged=true prohibido"
}

deny[msg] {
  some svc
  svc := input.services[_]
  not svc.hostConfig.CapDrop
  msg := "cap_drop requerido (ALL)"
}
```


### Seguridad en la imagen

#### Minimizar superficie de ataque

La imagen final debe contener solo lo que la app necesita para correr en producción. Nada de **toolchains**, **depuradores** o **caches** de build. La mejor forma es usar **multi stage builds**.

> **"toolchains"** significa **las herramientas de *compilación y construcción*** que solo se necesitan para **construir** el binario/paquete, **no** para **ejecutarlo** en producción.



**Ejemplo práctico con Python**

```dockerfile
# Etapa de build
FROM python:3.12-slim AS builder
WORKDIR /app
COPY pyproject.toml poetry.lock* ./
RUN pip install --no-cache-dir --upgrade pip poetry \
 && poetry export -f requirements.txt -o requirements.txt
COPY . .
RUN python -m compileall .

# Etapa de runtime
FROM python:3.12-slim
RUN useradd -m app
WORKDIR /app
# Solo copio lo necesario
COPY --from=builder /app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=builder /app /app
USER app
EXPOSE 8080
CMD ["python", "main.py"]
```

**Qué logramos**

* Toolchains y caches se quedan en la etapa builder
* La imagen final es más pequeña y con menor superficie de ataque
* `USER app` evita ejecutar como root

**Expón solo lo necesario**

* Si la app escucha en 8080 usa `EXPOSE 8080`
* No abras puertos por si acaso
* Justifica cada puerto en la documentación del servicio y en el PR de seguridad

**Smells comunes y cómo evitarlos**

* Imagen base enorme con utilitarios que no usas. Cambia a `-slim` o a una base mínima
* Instalar compilers en la imagen final. Muévelos a la etapa builder
* Shell interactiva en producción. Si no aporta valor al runtime no la incluyas

**Prueba rápida**

* `docker scout quickview` o `trivy image` para ver tamaño y CVE
* `docker history --no-trunc mi-app:1.0` para inspeccionar capas grandes inesperadas

#### Gestión de secretos

Un secreto en el Dockerfile o en la imagen es un secreto perdido. La imagen viaja por registros y cachés y deja huellas. Los secretos deben **inyectarse en tiempo de ejecución** y preferir **montajes** o **mecanismos de secretos** del orquestador.

**Nunca en el Dockerfile**

```dockerfile
# Mal
ENV DB_PASSWORD=mipass
```

**Inyección local controlada**

```bash
# Bien en local para desarrollo
echo "DB_PASSWORD=solo_para_local" > .env.runtime
docker run --rm --env-file .env.runtime mi-app:1.0
```

**Montaje como archivo con permisos**

* Evita que quede visible como variable de entorno
* El proceso lee desde un archivo temporal con dueño y permisos estrictos

```bash
# Archivo de secreto con permisos 600
echo -n "solo_para_local" > db_password.txt
chmod 600 db_password.txt

# Montaje en solo lectura
docker run --rm \
  -v $PWD/db_password.txt:/run/secret/db_password:ro \
  -e DB_PASSWORD_FILE=/run/secret/db_password \
  mi-app:1.0
```

**Patrón en código**

```python
import os
from pathlib import Path

def read_secret():
    file = os.getenv("DB_PASSWORD_FILE")
    if file and Path(file).exists():
        return Path(file).read_text().strip()
    return os.getenv("DB_PASSWORD", "")  # solo como fallback local
```

**Por qué evitar variables con secretos**

* `docker inspect` muestra las variables
* Cualquier operador con acceso al host puede leerlas
* Montajes y gestores de secretos reducen ese riesgo y facilitan rotación

**En orquestadores**

* Swarm y Kubernetes tienen objetos de tipo secret
* Asignan el secreto como archivo en memoria o tmpfs
* Controlan quién puede leerlo y lo rotan sin reconstruir la imagen

#### Escaneo y SBOM

Cada imagen debe venir con su diagnóstico de vulnerabilidades y su lista de materiales. Sin eso estás volando a ciegas. Además los CVE aparecen después del build. Por eso el escaneo debe repetirse de forma programada y no solo en el pipeline.

**Escaneo mínimo con Trivy o Grype**

```bash
# Falla si encuentra HIGH o CRITICAL
trivy image --exit-code 1 --ignore-unfixed --severity HIGH,CRITICAL mi-app:1.0

# Alternativa
grype mi-app:1.0 --fail-on High
```

**Generar SBOM en el build**

* Formatos comunes

  * CycloneDX
  * SPDX

```bash
# Con Syft
syft packages docker:mi-app:1.0 -o cyclonedx-json > .evidence/sbom.json
```

**Usa versionado inmutable y despliega por digest**

* Tag fijo legible para humanos
* Digest sha para la verdad operativa
* Evita `latest` en producción

```bash
# Etiquetar y obtener digest
docker tag mi-app:1.0 registry.example.com/mi-app:1.0
docker push registry.example.com/mi-app:1.0
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' registry.example.com/mi-app:1.0)

# Desplegar por digest
docker run --rm $DIGEST
```

**Firma y verificación de imagen**

* Asegura que el artefacto no fue alterado
* Útil para políticas de admisión que solo permitan imágenes firmadas

```bash
cosign sign --yes registry.example.com/mi-app:1.0
cosign verify registry.example.com/mi-app:1.0
```

**Flujo recomendado en el pipeline**

1. Construye con multi stage y `USER` no root
2. Escanea la imagen y falla ante HIGH o CRITICAL
3. Genera SBOM y publícalo en la carpeta de evidencia
4. Firma la imagen y publica tag y digest
5. Despliega por digest
6. Programa reescaneo del repositorio de imágenes de forma periódica


### **Empezando con Docker Compose**

**Docker Compose** (V2) te permite definir aplicaciones **multi-contenedor** en un único archivo (`compose.yaml` o `docker-compose.yml`) y levantarlas con un solo comando.

1. **Archivo de Compose**

   * Define **servicios**, **redes** y **volúmenes** en `compose.yaml`. Es el **plano declarativo** de tu app.

2. **Definición de servicios**

   * Cada servicio es un contenedor (web, db, api…). Especifica **imagen** o **build**, **env vars**, **puertos**, **volúmenes** y **comandos**.

3. **Redes y volúmenes**

   * Crea **redes** para la comunicación interna por **nombre de servicio** (DNS integrado) y **volúmenes** para persistencia.

4. **Dependencias y orquestación local**

   * Usa `depends_on` para el **orden de arranque**. Si necesitas esperar a que un servicio esté **realmente listo**, configura **`healthcheck`** y condiciones (`service_healthy`).

5. **Lanzar la aplicación**

   * Con **Compose V2** utiliza `docker compose` (no `docker-compose`):

     ```bash
     docker compose up -d
     docker compose ps
     docker compose logs -f
     docker compose down   # añade --volumes si quieres borrar datos
     ```
   * Escalar:

     ```bash
     docker compose up -d --scale web=3
     ```

6. **Configuración de entornos**

   * Usa **`.env`** (no commitear secretos) y **sustitución `${VAR}`** en el YAML. Gestiona **secretos** con el orquestador/host.

**Ejemplo mínimo seguro (`compose.yaml`)**

```yaml
services:
  web:
    build: .
    ports:
      - "8080:8080"
    environment:
      APP_ENV: "prod"
    read_only: true
    cap_drop: ["ALL"]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
      interval: 10s
      timeout: 2s
      retries: 5

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: changeme
      POSTGRES_DB: appdb
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 10s
      timeout: 3s
      retries: 10

volumes:
  dbdata:
```

**Notas rápidas**

* Por defecto, Compose crea una **red** para que `web` pueda conectarse a `db` usando el **nombre del servicio** (`db:5432`).
* `read_only` y `cap_drop` endurecen el contenedor; añade solo lo imprescindible si algo falla.
* Para builds reproducibles: `docker compose build --pull` y evita `latest`.
* Las credenciales del ejemplo son solo para entorno local. En producción usa secrets (Compose/K8s) o archivos montados (`*_FILE`).

Para más información: [Compose Overview](https://docs.docker.com/compose/).


### Contexto DevSecOps y por qué Docker importa

Cuando un equipo adopta Docker, decide **empaquetar la app con todo lo que necesita**. Así, lo que corre en tu laptop **es el mismo artefacto** que llega a producción. Menos sorpresas. Menos "en mi máquina funciona".

En DevSecOps eso encaja perfecto con **CALMS**: 

* **Cultura**. El mismo equipo cuida calidad y seguridad desde el inicio
* **Automatización**. Cada cambio dispara build, pruebas y escaneo
* **Lean**. Versiones pequeñas y reversibles
* **Medición**. Evidencias por imagen y por versión
* **Compartir**. Plantillas y reglas que todos entienden

Con **You Build It, You Run It**, el equipo que construye también opera. Docker ayuda porque la imagen es **predecible** y **auditada**. Sabes qué contiene y puedes demostrar cómo se construyó.

¿Dónde entra cada cosa?

* **VM** para aislar sistemas completos. Llevan su kernel invitado y son pesadas
* **Docker** para aislar procesos. Es rápido y denso. Ideal para desplegar y escalar apps
* **Kubernetes** para orquestar contenedores a gran escala. Programa, vigila y aplica políticas. Consume imágenes que tú ya construiste

La **imagen** es el corazón de la entrega. La versionas, la firmas, la escaneas y le generas un **SBOM**. Con eso puedes **rastrear** qué está corriendo y **defender** tus decisiones ante auditoría o revisión de seguridad.


### **DevSecOps aplicado con Docker Compose**

La adopción de **Docker Compose** permite trasladar prácticas DevSecOps al entorno local y de integración continua: **salud verificable**, **datos correctamente gestionados**, **dependencias explícitas** y **límites de recursos** que reducen el "blast radius". Estos controles, aunque parezcan "pequeños", mejoran la reproducibilidad de incidentes y la higiene operativa del equipo.

#### Healthchecks y observabilidad temprana

Un contenedor **vivo** no significa **sano**. El *healthcheck* debe validar la **capacidad real de atender** (por ejemplo, un endpoint `/health` que compruebe DB/colas). Es el primer paso hacia **métricas, alertas** y *SLOs*.

* **HTTP (recomendado si hay endpoint de salud):**

  ```yaml
  services:
    web:
      # ...
      healthcheck:
        test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
        interval: 10s
        timeout: 2s
        retries: 5
        start_period: 15s
  ```

* **TCP (cuando no hay HTTP):**

  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "nc -z localhost 5432 || exit 1"]
  ```

* **Script (verificaciones compuestas):**

  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "/app/healthcheck.sh"]
  ```

**Beneficios DevSecOps:** detectar *regresiones* antes del despliegue, reducir *MTTR* al reproducir fallas localmente, y alimentar paneles/alertas con un concepto claro de **salud** (no solo "el proceso sigue vivo").

#### Volúmenes y datos

Distingue **volúmenes nombrados** (gestionados por Docker) de **bind mounts** (carpetas del host). Usa **volúmenes nombrados** para **estado persistente** (DB) y *bind mounts* sólo en desarrollo para editar código.

* **Named volume (persistencia "controlada"):**

  ```yaml
  services:
    db:
      image: postgres:16
      volumes:
        - dbdata:/var/lib/postgresql/data
  volumes:
    dbdata:
  ```

* **Bind mount (dev-only, ojo con filtrado y permisos):**

  ```yaml
  services:
    web:
      volumes:
        - ./:/app:ro
  ```

**Qué persiste y qué NO:**

* **Sí**: datos de bases de datos, colas, almacenamiento de blobs local de desarrollo.
* **No**: **secretos**, **claves privadas**, **tokens** y **dumps con PII**.
  Riesgo común: estudiantes dejando **backups/dumps** con **PII** sin cifrar en volúmenes o carpetas del host. Define reglas:

  * Prohibir dumps sin **cifrado** (por ejemplo, `age`, `gpg`, `openssl enc`).
  * **.gitignore** para evidencias/dumps.
  * Montajes **de solo lectura** para el contenedor que no deba escribir.
  * Rotación y eliminación segura de archivos temporales.

#### Dependencias explícitas

`depends_on` define **orden de arranque**, pero **no** garantiza que el servicio dependido esté **listo**. Combínalo con **healthchecks** y condiciones para un **mini-orquestador local** reproducible.

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 10s
      timeout: 3s
      retries: 10

  web:
    build: .
    depends_on:
      db:
        condition: service_healthy
```

**Ventaja operativa (YBIYRI):** puedes **recrear el incidente** en local con el **mismo plano declarativo** que en el pipeline. Esto reduce "no reproducible" y acelera *post-mortems*.

#### Limitaciones de recursos

Limitar CPU/memoria **reduce el daño** de bucles infinitos, fugas o picos inesperados (**blast radius**) y aporta trazabilidad ante **seguridad/finops**.

* **Local (Compose clásico):** usa `cpus` y `mem_limit` (equivalentes a `--cpus` y `--memory`).

  ```yaml
  services:
    web:
      build: .
      cpus: "1.0"           # máx 1 CPU lógico
      mem_limit: "512m"     # límite duro de memoria
  ```

* **Swarm/Kubernetes (planeación "de verdad"):** usa `deploy.resources` (Swarm) o `requests/limits` (K8s).

  ```yaml
  services:
    api:
      image: registry.example.com/api:1.2.3
      deploy:
        resources:
          limits:
            cpus: "1.0"
            memory: 512M
          reservations:
            cpus: "0.25"
            memory: 256M
  ```

**Racional de seguridad/finops:** un contenedor sin límites puede **agotar el host** (DoS interno), afectar observabilidad (agentes caen) y degradar servicios vecinos. Los límites te dan una **línea de defensa** y evidencias para justificar capacidad y costos.

