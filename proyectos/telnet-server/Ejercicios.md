### Lista de ejercicios

#### 1. Aplicación de ejemplo (servidor Telnet en Go)

**Idea:** evitar `switch` gigante y facilitar tests separando los comandos en un mapa de handlers.

```go
// Nuevo tipo para manejar comandos
type CommandHandler func(conn net.Conn, srcIP, args string)

// En tu TCPServer
type TCPServer struct {
    // ...
    handlers map[string]CommandHandler
}

func NewTCPServer(/* ... */) *TCPServer {
    s := &TCPServer{/*...*/}
    s.handlers = map[string]CommandHandler{
        "q":     s.handleQuit,
        "quit":  s.handleQuit,
        "date":  s.handleDate,
        "?":     s.handleHelp,
        "help":  s.handleHelp,
    }
    return s
}

func (t *TCPServer) handleConnection(conn net.Conn) {
    defer conn.Close()
    srcIP := conn.RemoteAddr().String()
    scanner := bufio.NewScanner(conn)

    for scanner.Scan() {
        line := strings.TrimSpace(scanner.Text())
        parts := strings.SplitN(line, " ", 2)
        cmd := strings.ToLower(parts[0])
        args := ""
        if len(parts) == 2 {
            args = parts[1]
        }

        if handler, ok := t.handlers[cmd]; ok {
            handler(conn, srcIP, args)
        } else {
            // Métrica y eco de comando desconocido
            t.metrics.IncrementUnknownCommands(cmd)
            fmt.Fprintf(conn, "comando desconocido: %s\n", cmd)
        }

        t.logger.Printf("[IP=%s] Comando solicitado: %s", srcIP, line)
    }
}
```

**Mejora:**

* El código queda más limpio y extensible: añadir un nuevo comando es solo agregar una entrada al mapa.
* Es más fácil de testear cada handler por separado.

#### 2. Docker y pruebas de contenedor

**Idea:** endurecer el Dockerfile (no-root + versión fija de Go + healthcheck).

```dockerfile
# Etapa de compilación(build)
FROM golang:1.23-alpine AS build-env
WORKDIR /src
COPY . .
RUN go build -o telnet-server ./cmd/telnet-server

# Etapa final
FROM alpine:3.20

# Crear usuario no-root
RUN adduser -D -u 10001 appuser
USER appuser

WORKDIR /app

ENV TELNET_PORT=2323 \
    METRIC_PORT=9000

COPY --from=build-env /src/telnet-server /app/telnet-server

# Healthcheck simple contra el puerto de métricas
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD nc -z localhost "${METRIC_PORT}" || exit 1

ENTRYPOINT ["./telnet-server"]
```

Y en `container-tests/command-and-metadata-test.yaml` puedes añadir:

```yaml
metadataTest:
  user: "appuser"
```

**Mejora:**

* Imagen más segura (no-root, versiones fijas).
* Healthcheck ya incluido a nivel de contenedor; encaja luego con Kubernetes.

#### 3. Minikube y diferencia Docker host vs Docker interno

**Idea:** hacer `deploy.sh` más reutilizable parametrizando la imagen y haciendo función para cambiar contexto.

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-dftd/telnet-server:v1}"

use_minikube_docker() {
  # Solo cambiamos al daemon de Minikube si no lo estamos usando ya
  if ! docker info 2>/dev/null | grep -q "Minikube"; then
    echo "[*] Cambiando a daemon Docker de Minikube..."
    eval "$(minikube docker-env)"
  fi
}

echo "[1] Iniciando Minikube con driver Docker (idempotente)..."
minikube start --driver=docker

echo "[2] Probando imagen en Docker del host..."
docker rm -f telnet-server 2>/dev/null || true
docker run --name telnet-server -d -p 2323:2323 -p 9000:9000 "$IMAGE"
sleep 3
docker logs telnet-server | head -n 5
docker rm -f telnet-server || true

echo "[3] Construyendo imagen dentro de Minikube..."
use_minikube_docker
docker build -t "$IMAGE" .

docker image ls "$IMAGE"
```

**Mejora:**

* Puedes cambiar la imagen solo exportando `IMAGE=...`.
* Menos código duplicado y más claro dónde se cambia el contexto Docker.

#### 4. Kubernetes: Deployment clásico, servicios y exploración

**Idea:** mejorar seguridad del `Deployment` añadiendo `securityContext` y `podAntiAffinity`.

En `kubernetes/deployment.yaml`, dentro de `spec.template`:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 10001
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - telnet-server
            topologyKey: "kubernetes.io/hostname"
  containers:
    - name: telnet-server
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsUser: 10001
      # resto igual...
```

**Mejora:**

* Refuerzas el aislamiento del contenedor (no puede escalar privilegios, FS solo lectura).
* Se distribuyen las réplicas en nodos distintos (anti-affinity), mejorando disponibilidad.

#### 5. Despliegue Azul-Verde

**Idea:** marcar explícitamente qué color está activo usando una anotación en el Service. 
Esa anotación será la referencia única y confiable que indica qué entorno (blue o green) está recibiendo el tráfico, y el `selector` del Service debe mantenerse siempre consistente con ese valor.

En `kubernetes/service.yaml`:

```yaml
metadata:
  name: telnet-server
  labels:
    app: telnet-server
  annotations:
    telnet-server/color-active: "blue"
spec:
  type: LoadBalancer
  selector:
    app: telnet-server
    color: blue
```

Y un pequeño script para sincronizar selector con la anotación:

```bash
#!/usr/bin/env bash
set -euo pipefail

COLOR="${1:-green}"

echo "Cambiando Service a color=${COLOR}..."
minikube kubectl -- patch svc telnet-server -p \
"{
  \"spec\": {
    \"selector\": {
      \"app\": \"telnet-server\",
      \"color\": \"${COLOR}\"
    }
  },
  \"metadata\": {
    \"annotations\": {
      \"telnet-server/color-active\": \"${COLOR}\"
    }
  }
}"
```

**Mejora:**

* Evitas que el selector y el "color activo" se desincronicen.
* Dejas trazabilidad clara de qué entorno (blue/green) está activo en cada momento.

#### 6. Rollback e historial de despliegues

**Idea:** permitir que `check_rollback.sh` reciba la revisión como argumento y falle de forma explícita si no existe.

```bash
#!/usr/bin/env bash
set -euo pipefail

REVISION="${1:-1}"

echo "Services: telnet-server"
minikube kubectl -- get services telnet-server

echo
echo "Historia Rollout: telnet-server"
minikube kubectl -- rollout history deployment telnet-server

echo
echo "Intentando rollback a revision=${REVISION}..."
if ! minikube kubectl -- rollout undo deployment telnet-server --to-revision="${REVISION}"; then
  echo "No se pudo hacer rollback (tal vez no existe esa revisión)." >&2
fi

echo
echo "Estado tras rollback:"
minikube kubectl -- rollout status deployment telnet-server || true
```

**Mejora:**

* Puedes probar distintos escenarios de rollback (`./check_rollback.sh 2`, etc.).
* Mejor feedback en caso de fallo (no se oculta el error).

#### 7. Stack de monitoreo: Prometheus, Grafana y Alertmanager

**Idea:** hacer el Deployment de Prometheus un poco más "realista" configurando retención y recursos.

En `monitoring/prometheus/deployment.yaml`, dentro del contenedor:

```yaml
containers:
  - name: prometheus
    image: prom/prometheus:v2.55.0
    args:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus/"
      - "--storage.tsdb.retention.time=24h"
      - "--web.enable-lifecycle"
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

Y un ejemplo de regra de alerta simple en tu ConfigMap (si no la tienes):

```yaml
groups:
  - name: telnet-server.rules
    rules:
      - alert: TelnetServerDown
        expr: up{job="telnet-server"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          description: "No se detectan instancias de telnet-server en up==1"
```

**Mejora:**

* Controlas cuánto tiempo guardas métricas (24h para laboratorio).
* Evitas que Prometheus se coma toda la memoria.
* Introduces una alerta clara ligada al servicio de ejemplo.

#### 8. Skaffold: build + test + deploy

**Idea:** añadir una prueba extra que verifique el endpoint de métricas del `telnet-server` después del deploy.

En `skaffold.yaml`, dentro de `test:` del perfil simple:

```yaml
test:
  - image: dftd/telnet-server
    custom:
      - command: "kubectl wait deployment/telnet-server --for=condition=available --timeout=2m -n default"
      - command: "kubectl get svc telnet-server -n default"
      - command: "kubectl run curl-metrics --rm -i --image=curlimages/curl:8.11.1 --restart=Never -- \
                  curl -s telnet-server-metrics.default.svc.cluster.local:9000/metrics | head -n 5"
```

*(Asumiendo que el Service de métricas se llame `telnet-server-metrics`; ajusta al nombre real del YAML).*
