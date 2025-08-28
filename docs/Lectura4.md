## Fundamentos operativos de DevOps y DevSecOps

Esta lectura explora cómo DevOps y DevSecOps integran desarrollo, operaciones y seguridad para entregar servicios fiables, seguros y escalables. 
Bajo el marco [CALMS](https://www.atlassian.com/devops/frameworks/calms-framework) (Culture, Automation, Lean, Measurement, Sharing), la cultura fomenta la corresponsabilidad entre equipos, la automatización sistematiza pipelines, el enfoque **Lean** minimiza fallos, la medición guía con métricas como SLO (Service Level Objectives), y el compartir difunde aprendizajes mediante runbooks y postmortems. 

El principio ["you build it, you run it"](https://www.thoughtworks.com/insights/decoder/y/you-build-it-you-run-it) asigna al equipo que desarrolla la responsabilidad de operar el servicio, asegurando decisiones de diseño (idempotencia, caché, TLS) informadas por la operación. 
Los bucles de feedback-métricas, logs y trazas cierran el ciclo, retroalimentando mejoras en diseño y despliegues. 

En CI/CD (Continuous Integration/Continuous Deployment), verificaciones de HTTP, DNS, TLS y puertos actúan como puertas de calidad, integrando pruebas y escaneos de seguridad para garantizar servicios sanos y auditables.

#### HTTP: El contrato operativo del servicio

**Transición**: En el marco de CALMS y CI/CD, HTTP define el contrato entre el servicio y sus clientes, integrando observabilidad y seguridad desde el diseño.  

HTTP estructura la comunicación cliente-servidor, determinando semánticas de reintentos y observabilidad de fallos. 
La **idempotencia** (propiedad de una operación que produce el mismo resultado si se repite) es clave: GET, PUT y DELETE son idempotentes, permitiendo reintentos seguros tras timeouts, POST no lo es, y PATCH depende del diseño. 
Por ejemplo, un endpoint `/orders` con POST para crear pedidos debe evitar reintentos automáticos que dupliquen pedidos. Los códigos de estado guían decisiones: 2xx indica éxito (201 para creado, 202 para aceptado), 3xx gestiona redirecciones, 4xx responsabiliza al cliente (429 Too Many Requests para control de tasa), y 5xx señala fallos del servicio que activan alarmas.  

Las cabeceras refuerzan el contrato:  
- **Cache-Control**: Define políticas de caché (frescura, validación).  
- **ETag** y **If-Match**: Habilitan peticiones condicionales para evitar transferencias innecesarias.  
- **Strict-Transport-Security (HSTS)**: Cabecera HTTP (no parte de TLS) que fuerza HTTPS en futuras visitas.  
- **X-Request-ID** o **traceparent**: Identificadores para correlacionar métricas, logs y trazas.  

En DevSecOps, la observabilidad mide latencias (p50/p95/p99), códigos de estado y tamaños de respuesta. Los endpoints de salud distinguen **liveness** (el proceso está activo) de **readiness** (listo para tráfico), evitando que balanceadores enruten a instancias no preparadas. 

**Ejemplo:** Un endpoint `/health` que retorna 200 para liveness y 503 durante inicialización.  

#### Comandos útiles

#### Inspección rápida del contrato (cabeceras y códigos)

```bash
# Ver cabeceras clave (Cache-Control, ETag, HSTS, etc.)
curl -I https://HOST:PORT/ | sed -n '1,20p'

# Validación condicional con ETag (304 Not Modified si coincide)
ETAG=$(curl -sI https://HOST:PORT/recurso | awk -F': ' 'tolower($1)=="etag"{print $2}' | tr -d '\r')
curl -i -H "If-None-Match: $ETAG" https://HOST:PORT/recurso

# Forzar validación de caché en cliente (evitar reuso de caché intermedia)
curl -I -H "Cache-Control: no-cache" https://HOST:PORT/recurso

# Comprobar HSTS (recuerda: es cabecera HTTP, no parte de TLS)
curl -I https://HOST:PORT/ | grep -i strict-transport-security

# Trazabilidad: X-Request-ID y traceparent (W3C)
RID=$(uuidgen | tr '[:upper:]' '[:lower:]'); TR=$(openssl rand -hex 16); SP=$(openssl rand -hex 8)
curl -i -H "X-Request-ID: $RID" -H "traceparent: 00-$TR-$SP-01" https://HOST:PORT/api/ping
```

#### Idempotencia y reintentos

```bash
# Reintentos seguros (GET/PUT/DELETE son idempotentes): 3 intentos ante timeouts/errores transitorios
curl --retry 3 --retry-all-errors --fail https://HOST:PORT/items/123

# POST NO es idempotente; si necesitas reintentos, usa Idempotency-Key en el backend y cliente
IK=$(uuidgen)
curl -X POST https://HOST:PORT/orders \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $IK" \
  -d '{"sku":"ABC","qty":1}'
```

#### Observabilidad desde el cliente (latencias y tamaños)

```bash
# Métricas de tiempo: DNS, TCP, TLS, TTFB, total, código y tamaños
curl -s -o /dev/null -w \
'tcp_connect=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s total=%{time_total}s code=%{http_code} size=%{size_download}B\n' \
https://HOST:PORT/api/ping
```

#### Liveness vs Readiness (sin Kubernetes)

**Patrón recomendado**:

* **/healthz** -> *liveness*: 200 si el proceso está vivo (no chequea dependencias).
* **/readyz** -> *readiness*: 200 sólo cuando dependencias estén OK (DB, cola, migraciones); **503** mientras inicializa.

```bash
# Liveness: falla el comando si no es 2xx (útil en systemd/CI)
curl -fsS http://HOST:PORT/healthz >/dev/null && echo "LIVE" || echo "NOT LIVE"

# Readiness: espera hasta que esté listo (útil antes de enrutar tráfico)
until curl -fsS http://HOST:PORT/readyz >/dev/null; do
  echo "No ready aún..."; sleep 1
done
echo "READY"

# Visualizar código en tiempo real (200 = listo, 503 = no listo)
watch -n1 'curl -s -o /dev/null -w "%{http_code}\n" http://HOST:PORT/readyz'

# Comprobar puerto/proceso expuesto (corrobora liveness de red)
ss -ltnp | grep ":PORT"
```

> Si tu app sólo expone `/health`, úsalo como *readiness* devolviendo **503** durante la inicialización y **200** cuando esté lista; para *liveness* agrega un chequeo mínimo (p. ej., endpoint que no toca dependencias).

#### Liveness/Readiness en CI/CD y systemd

```bash
# Gate en pipeline: falla el job si /readyz no está 200 en ≤30s
timeout 30 bash -c 'until curl -fsS http://HOST:PORT/readyz >/dev/null; do sleep 1; done'

# Ver correlación de solicitudes por X-Request-ID en logs (ej. systemd)
RID=test-123
curl -H "X-Request-ID: $RID" http://HOST:PORT/api/ping >/dev/null
journalctl -u miapp.service --since "5 min ago" | grep "$RID"
```

#### Control de tasa (429) y comportamiento bajo carga

```bash
# Dispara N solicitudes concurrentes y cuenta códigos (mira 429)
URL=http://HOST:PORT/api/limit
seq 1 200 | xargs -I{} -P 20 sh -c "curl -s -o /dev/null -w '%{http_code}\n' $URL" | sort | uniq -c
```

#### Ejemplos de actualización condicional (ETag / If-Match)

```bash
# Lee ETag actual y sólo actualiza si nadie lo cambió (evita sobrescritura perdida)
ETAG=$(curl -sI http://HOST:PORT/items/123 | awk -F': ' 'tolower($1)=="etag"{print $2}' | tr -d '\r')
curl -i -X PUT http://HOST:PORT/items/123 \
  -H "Content-Type: application/json" \
  -H "If-Match: $ETAG" \
  -d '{"name":"nuevo"}'
```


#### DNS: Identidad y disponibilidad en la red

**Transición**: DNS, pilar de la identidad del servicio, se alinea con la automatización y medición de CALMS para garantizar disponibilidad y consistencia.  

DNS resuelve nombres a direcciones, condicionando la disponibilidad percibida. Los registros principales son:  
- **A/AAAA**: Direcciones IPv4/IPv6.  
- **CNAME**: Alias (evitar cadenas largas).  
- **TXT**: Verificaciones o políticas (ej., SPF para correo).  
- **SRV**: Anuncia servicios y puertos.  

El **TTL (Time to Live)** controla la caché: un TTL de 300s permite cambios rápidos en canarios, mientras que 86400s reduce consultas en servicios estables. 
Una consulta DNS pasa del stub resolver (en el cliente) al resolver recursivo (ISP o interno), que cachea respuestas y sigue la cadena raíz -> TLD -> autoritativos. 
La **caché negativa** (para NXDOMAIN) amortigua consultas a nombres inexistentes.  

En entornos corporativos, **split-horizon DNS** (respuestas distintas según origen) entrega IPs privadas a clientes internos y públicas a externos. 
Por ejemplo, `internal.example.com` resuelve a 10.0.0.1 internamente y a una IP pública vía CDN externamente. En DevSecOps, **DNSSEC** (DNS Security Extensions) valida integridad con firmas criptográficas, y **CAA** (Certificate Authority Authorization) restringe emisores de certificados. 
Verificaciones rigurosas evitan discrepancias, revisando delegaciones, nameservers y archivos como `/etc/hosts`.  

#### Comandos útiles

#### Espacio de nombres y TLDs (raíz -> TLD -> dominio)

```bash
# Ver servidores raíz (.) y TLDs
dig . NS +nocomments +noquestion +answer
dig com. NS +nocomments +noquestion +answer
dig pe.  NS +nocomments +noquestion +answer

# Delegación de un dominio (nameservers autoritativos)
dig example.com NS +nocomments +noquestion +answer
dig +nssearch example.com        # prueba autoritativa de los NS
```

#### Flujo de resolución DNS (trazado paso a paso)

```bash
# Camino completo: raíz -> TLD -> autoritativos (sin caché del recursor)
dig +trace www.example.com

# Simular preguntar a cada capa manualmente
dig @a.root-servers.net com. NS +norecurse
dig @a.gtld-servers.net example.com NS +norecurse
dig @<ns_autoritativo_de_example> www.example.com A +norecurse
```

#### Resolver local y orden de resolución (libc / NSS)

```bash
# ¿Qué IP resuelve *tu sistema* (respeta /etc/hosts, nsswitch, search domains)?
getent hosts www.example.com
getent ahosts www.example.com    # muestra IPv4/IPv6

# Ver cómo está enlazado /etc/resolv.conf (systemd-resolved suele usar 127.0.0.53)
ls -l /etc/resolv.conf
cat /etc/resolv.conf

# Estado del resolver en systemd
resolvectl status
resolvectl dns
resolvectl domain
resolvectl query www.example.com

# Ver el orden de resolución (archivos, dns, etc.)
grep '^hosts:' /etc/nsswitch.conf
```

#### Registros A/AAAA/CNAME/TXT/MX/ SRV (+ CAA/DNSSEC)

```bash
# A y AAAA
dig +short A   www.example.com
dig +short AAAA www.example.com

# CNAME (evita cadenas largas)
dig +noall +answer CNAME api.example.com

# TXT (p.ej., SPF/DMARC/verificaciones)
dig +short TXT example.com

# MX (correo)
dig +noall +answer MX example.com | sort -k1,1n

# SRV (servicio/puerto)
dig +noall +answer SRV _sip._tcp.example.com

# CAA (emisores de certificados permitidos)
dig +noall +answer CAA example.com

# DNSSEC (bandera AD del recursor y RRSIG)
dig +dnssec A www.cloudflare.com       # mira "ad" en HEADER si el recursor valida
dig +noall +answer RRSIG www.cloudflare.com
```

#### TTL y caché (positiva y negativa)

```bash
# Observar el TTL decreciendo (respuesta en caché del recursor)
watch -n1 'dig +noall +answer www.example.com'

# Ver TTL desde autoritativo (sin caché intermedia)
dig @<ns_autoritativo_de_example> www.example.com A +noall +answer +norecurse

# Caché negativa (NXDOMAIN): observa el SOA/TTL de negativa
dig noexiste-123.example.com A +noall +answer +authority

# Forzar revalidación al recursor (menos reuso de caché del cliente)
dig www.example.com +nocache +noall +answer

# Vaciar caché (según componente)
resolvectl flush-caches                  # cache de systemd-resolved
sudo rndc flush                          # BIND
sudo unbound-control flush_zone example.com  # Unbound
```

#### DNS interno y Split-Horizon (vistas)

```bash
# Comparar respuesta interna vs pública (IPs distintas: privadas vs CDN)
dig @10.0.0.53 internal.example.com A +noall +answer        # recursor interno
dig @1.1.1.1   internal.example.com A +noall +answer        # recursor público

# Verificación de split-horizon por FQDNs distintos
dig @10.0.0.53 www.example.com A +noall +answer
dig @1.1.1.1   www.example.com A +noall +answer

# (Opcional) simular dos "vistas" con contenedores/redes o netns apuntando a resolvers distintos
# ip netns add int ; ip netns add ext ; (configura resolv.conf distintos en cada ns y usa `ip netns exec`)
```

#### Comprobaciones de delegaciones, NS y SOA

```bash
# ¿Qué NS responden realmente? ¿coincide con el registro en el TLD?
dig +short NS example.com | sort
dig @a.gtld-servers.net example.com NS +norecurse +noall +answer

# SOA (útil para serial, refresco y TTL mínimo de negativa)
dig +noall +answer SOA example.com
```

#### Verificación rápida desde herramientas alternativas

```bash
host -t A    www.example.com
host -t MX   example.com
nslookup -type=SRV _sip._tcp.example.com
drill -S www.example.com          # muestra cadena DNSSEC (si disponible)
```

#### Interacción con `/etc/hosts` (overrides locales)

```bash
# ¿Hay override local?
grep -E '\bmiapp\.local\b' /etc/hosts || true

# Comprobar que getent usa primero /etc/hosts (según nsswitch)
getent hosts miapp.local
```

#### Tiempo de vida del registro (canarios vs estable)

```bash
# Inspeccionar TTL exacto desde el autoritativo (útil para canary short TTL)
dig @<ns_autoritativo> canary.example.com A +noall +answer +norecurse

# Para un servicio estable (TTL largo reduce consultas)
dig @<ns_autoritativo> stable.example.com A +noall +answer +norecurse
```

#### Flujo "stub -> recursor (ISP/interno) -> autoritativos"

```bash
# Pregunta primero al *recursor configurado* (stub resolver del sistema)
dig www.example.com +noall +answer

# Preguntar *directo* a un recursor público (salta el interno)
dig @9.9.9.9 www.example.com +noall +answer

# Preguntar al autoritativo final (verifica lo que *debería* responder la zona)
dig @<ns_autoritativo> www.example.com A +noall +answer +norecurse
```

> Consejos operativos:
>
> * Para **canarios** usa TTL bajos (p.ej. 300s) y supervisa **propagación** con `dig` a múltiples recursors (`@1.1.1.1`, `@8.8.8.8`, `@9.9.9.9`, internos).
> * Revisa **coherencia**: `NS` en el TLD = `NS` que realmente responden; `SOA.serial` debe avanzar tras cambios.
> * Documenta vistas **split-horizon** (qué subred recibe qué respuesta) y valida con `dig` desde redes distintas o especificando `@resolver`.


#### TLS: Seguridad en el transporte

**Transición**: TLS, esencial para confidencialidad e integridad, refuerza la seguridad de DevSecOps con configuraciones que balancean protección y rendimiento.  

**TLS (Transport Layer Security)** asegura confidencialidad, integridad y autenticación. TLS 1.3 es preferido; 1.2 es aceptable; 1.0/1.1 están obsoletos. 
**SNI (Server Name Indication)** selecciona certificados según el dominio solicitado, y **ALPN (Application-Layer Protocol Negotiation)** negocia protocolos como HTTP/2. 
La identidad se ancla en el **SAN (Subject Alternative Name)**; por ejemplo, un certificado con `api.example.com` y `*.example.com` cubre API y subdominios.  

La cadena de confianza debe incluir certificados intermedios, estar vigente y sin revocación. **OCSP stapling** (validación incluida en el handshake) reduce latencia. 
**HSTS**, declarado vía HTTP, fuerza HTTPS en visitas futuras.  En DevSecOps, **mTLS (mutual TLS)** autentica clientes con certificados, ideal para backoffices. 
La observabilidad registra versión negociada, SAN, emisor y huella del certificado. 

**Ejemplo:** Un servicio con mTLS para `/admin` asegura que solo clientes autorizados accedan.  

#### Comandos útiles

#### Versiones TLS y ALPN (HTTP/2)

```bash
# Ver versión TLS negociada y ALPN (h2 vs http/1.1)
curl -vI --http2 https://DOMAIN 2>&1 | egrep 'SSL connection|ALPN|^< HTTP'
curl -vI --http1.1 https://DOMAIN 2>&1 | egrep 'SSL connection|ALPN|^< HTTP'

# Forzar/validar políticas de versión (debería fallar si 1.0/1.1 están deshabilitados)
curl -I --tls-max 1.0 https://DOMAIN     # esperado: falla
curl -I --tlsv1.3   https://DOMAIN       # fuerza 1.3
```

#### SNI (certificado correcto por nombre)

```bash
# Con SNI (correcto)
openssl s_client -connect DOMAIN:443 -servername DOMAIN </dev/null 2>/dev/null \
| openssl x509 -noout -subject -issuer

# Sin SNI (por IP; suele mostrar el cert "default" del servidor)
openssl s_client -connect IP:443 </dev/null 2>/dev/null \
| openssl x509 -noout -subject -issuer

# Probar mapeo de vhost/SNI explícito contra una IP
curl -I --resolve wrong.example:443:IP https://wrong.example
```

#### SAN (Subject Alternative Name) e identidad

```bash
# Listar SAN (los DNS que cubre el certificado)
openssl s_client -connect DOMAIN:443 -servername DOMAIN </dev/null 2>/dev/null \
| openssl x509 -noout -ext subjectAltName

# Huella y sujeto/emisor para auditoría
openssl s_client -connect DOMAIN:443 -servername DOMAIN </dev/null 2>/dev/null \
| openssl x509 -noout -fingerprint -sha256 -serial -subject -issuer
```

#### Vigencia, cadena e intermedios

```bash
# Fechas de validez
openssl s_client -connect DOMAIN:443 -servername DOMAIN </dev/null 2>/dev/null \
| openssl x509 -noout -dates

# Alertar si expira en < 30 días (2592000 s)
openssl s_client -connect DOMAIN:443 -servername DOMAIN </dev/null 2>/dev/null \
| openssl x509 -checkend 2592000 -noout || echo "Cert expira en <30 días"

# Mostrar cadena enviada y resultado de verificación con almacén del sistema
openssl s_client -connect DOMAIN:443 -servername DOMAIN -showcerts -verify_return_error </dev/null
# (Busca "Verify return code: 0 (ok)"; si faltan intermedios, aquí se verá)
```

#### OCSP stapling (revocación sin latencia extra)

```bash
# Inspeccionar OCSP stapling durante el handshake
openssl s_client -connect DOMAIN:443 -servername DOMAIN -status </dev/null \
| sed -n '/OCSP response:/,/---/p'

# Requerir OCSP stapling desde el cliente (si libcurl lo soporta)
curl --cert-status -I https://DOMAIN
```

#### HSTS (Strict-Transport-Security via HTTP)

```bash
curl -I https://DOMAIN | grep -i strict-transport-security
```

#### mTLS (mutual TLS) para backoffice /admin

```bash
# Sin certificado de cliente: debería rechazar (403/401 o 400)
curl -i https://DOMAIN/admin

# Con certificado de cliente (PEM separados)
curl -i --cert client.crt --key client.key --cacert ca.crt https://DOMAIN/admin

# Con bundle (cert+key en un solo PEM)
curl -i --cert client_bundle.pem --cacert ca.crt https://DOMAIN/admin

# Comprobar desde OpenSSL el handshake presentando cliente
openssl s_client -connect DOMAIN:443 -servername DOMAIN \
  -cert client.crt -key client.key -CAfile ca.crt </dev/null
```

#### Cifras y endurecimiento (vista de servidor)

```bash
# Enumerar suites soportadas por el servidor (útil para verificar que 1.0/1.1 estén fuera)
nmap --script ssl-enum-ciphers -p 443 DOMAIN

# Ver qué ALPN eligió el servidor (h2/http/1.1)
openssl s_client -connect DOMAIN:443 -servername DOMAIN -alpn 'h2,http/1.1' </dev/null 2>&1 \
| grep -i 'ALPN protocol'
```

#### Observabilidad operativa desde el cliente

```bash
# Latencias y código (útil para dashboards rápidos)
curl -s -o /dev/null -w 'code=%{http_code} ttfb=%{time_starttransfer}s total=%{time_total}s\n' https://DOMAIN/ping

# Ver en claro la versión TLS y protocolo de aplicación negociados (para logs)
curl -vI --http2 https://DOMAIN 2>&1 | egrep 'SSL connection|ALPN'
```

> Notas rápidas:
>
> * **TLS 1.3 preferido**; 1.2 aceptable; 1.0/1.1 obsoletos -> valida con `curl --tls-max`.
> * **SNI/SAN**: asegúrate de que todos los FQDN de producción aparecen en el SAN del cert (comodín `*.example.com` no cubre el nivel raíz `example.com`).
> * **Cadena/OCSP**: el servidor debe **enviar intermedios** y, si es posible, **stapling OCSP** "GOOD".
> * **mTLS**: protege rutas sensibles (`/admin`) y rota certificados cliente con expiraciones cortas.


#### Puertos y procesos

**Transición**: Los puertos y procesos definen la superficie de exposición del servicio, integrando seguridad y observabilidad en el núcleo de DevSecOps.  

La exposición se mide por sockets en **LISTEN** (puertos abiertos) y conexiones establecidas. Un servicio puede escuchar en loopback (127.0.0.1) para tráfico interno o en interfaces públicas. 
Los **puertos efímeros** (usados para conexiones salientes, configurables en Linux vía `ip_local_port_range`) afectan reglas NAT. 
**Systemd** controla procesos con reinicios automáticos y variables de entorno para secretos, evitando configuraciones embebidas.  

Un **reverse proxy** (como Nginx) termina TLS, propaga cabeceras (**X-Forwarded-For**), y limita conexiones para estabilidad. El firewall (nftables/UFW) deniega por defecto, abriendo solo puertos necesarios. 
En DevSecOps, la gestión de secretos (en gestores como Vault) y reglas estrictas de firewall minimizan la superficie de ataque.

**Ejemplo:** Un servicio en el puerto 8080 solo accesible desde un proxy interno en 10.0.0.2. La observabilidad combina métricas de sockets, rutas de red y resolución DNS para diagnosticar discrepancias.  


#### Comandos útiles

#### 1) Visibilidad de puertos y procesos

```bash
# Puertos en LISTEN y su proceso (TCP/UDP)
ss -ltnp            # TCP
ss -lunp            # UDP
# Alternativas
sudo lsof -i -P -n | grep LISTEN
sudo netstat -plnt  # si está disponible

# Diferenciar loopback vs público
ss -ltn | grep ':8080'   # ¿127.0.0.1:8080 (sólo local) o 0.0.0.0:8080 (todas)?
ip addr show              # interfaces e IPs locales
```

#### 2) Conexiones establecidas y "top talkers"

```bash
# Conexiones activas hacia/desde un puerto
ss -Htan state established '( sport = :8080 or dport = :8080 )' | head

# Resumen rápido de sockets
ss -s
```

#### 3) Puertos efímeros (rango y uso)

```bash
# Rango efímero actual (IPv4/IPv6)
cat /proc/sys/net/ipv4/ip_local_port_range
cat /proc/sys/net/ipv6/ip_local_port_range 2>/dev/null || echo "sin IPv6"

# Ver conexiones salientes usando puertos efímeros (aprox.)
ss -Htan state established | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq -c | tail
```

#### 4) NAT/conntrack 

```bash
# Tablas de seguimiento de conexiones (requiere paquete conntrack-tools)
sudo conntrack -L | head

# NAT en nftables/iptables
sudo nft list tables
sudo nft list table nat 2>/dev/null || echo "sin tabla nat"
sudo iptables -t nat -S 2>/dev/null | head
```

#### 5) systemd: arranque, reinicios, variables/secretos

```bash
# Estado, logs, reinicios automáticos
systemctl status miapp.service
journalctl -u miapp.service -n 100 --no-pager

# Ver overrides (Restart, Environment, EnvironmentFile)
systemctl cat miapp.service

# Cargar/recargar tras cambios
sudo systemctl daemon-reload
sudo systemctl restart miapp.service

# Inspeccionar variables de entorno expuestas al servicio (ojo con secretos)
systemctl show miapp.service -p Environment
# Mejor: usar archivo .env con permisos 600 y referenciarlo con EnvironmentFile=
```

> Tip DevSecOps: exporta secretos como **EnvironmentFile=/etc/miapp.env** (600, root\:root) y **no** los coloques en archivos unitarios ni binarios.

#### 6) Reverse proxy (Nginx) y terminación TLS

```bash
# Probar front (TLS en 443) vs backend (HTTP local 127.0.0.1:8080)
curl -I https://miapp.ejemplo.com
curl -I http://127.0.0.1:8080   # backend sólo local si está bien aislado

# Ver configuración efectiva y validar sintaxis
sudo nginx -T | sed -n '1,120p'
sudo nginx -t && sudo nginx -s reload
```

#### 7) Encabezados de proxy: X-Forwarded-For / X-Forwarded-Proto

```bash
# Simular cliente detrás de proxy y verificar que la app lo registra/respeta
curl -i -H "X-Forwarded-For: 203.0.113.10" -H "X-Forwarded-Proto: https" http://127.0.0.1:8080/whoami

# Comprobar que Nginx reenvía encabezados al backend
# (Busca proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;)
sudo nginx -T | grep -n 'proxy_set_header'
```

#### 8) Límite de conexiones en Nginx (estabilidad)

```bash
# Ver si hay zonas/limites activos (limit_conn/limit_req)
sudo nginx -T | egrep 'limit_(conn|req)'
# Pequeña prueba de carga y códigos devueltos
seq 1 100 | xargs -I{} -P 20 curl -s -o /dev/null -w '%{http_code}\n' https://miapp.ejemplo.com | sort | uniq -c
```

#### 9) Firewall (política por defecto deny, abrir sólo lo necesario)

**Con UFW:**

```bash
sudo ufw default deny incoming
sudo ufw allow 443/tcp              # sólo front TLS
sudo ufw allow from 10.0.0.2 to any port 8080 proto tcp   # backend sólo desde proxy
sudo ufw enable
sudo ufw status verbose
```

**Con nftables:**

```bash
# Políticas por defecto y reglas mínimas
sudo nft add table inet filter
sudo nft 'add chain inet filter input { type filter hook input priority 0; policy drop; }'
sudo nft add rule inet filter input ct state established,related accept
sudo nft add rule inet filter input iif lo accept
sudo nft add rule inet filter input tcp dport 443 accept
sudo nft add rule inet filter input ip saddr 10.0.0.2 tcp dport 8080 accept
sudo nft add rule inet filter input icmp type echo-request limit rate 5/second accept
sudo nft add rule inet filter input log prefix "DROP " counter drop

sudo nft list ruleset
```

#### 10) "Sólo el proxy 10.0.0.2 puede llegar al 8080"

```bash
# Verificar desde el proxy (debería conectar)
nc -zv 10.0.0.1 8080          # ejecutado desde 10.0.0.2 contra backend 10.0.0.1

# Verificar desde otra IP (debería fallar)
nc -zv 10.0.0.1 8080          # ejecutado desde cualquier otra máquina -> rechazado/bloqueado

# En el host backend, confirmar que sólo hay conexiones desde 10.0.0.2
ss -Htan '( dport = :8080 )' | awk '{print $5}' | awk -F: '{print $1}' | sort -u
```

#### 11) Diagnóstico "end-to-end": sockets, rutas y DNS

```bash
# Rutas y gateways
ip route show
ip -br addr show

# Resolución DNS efectiva del front
getent hosts miapp.ejemplo.com
dig +short miapp.ejemplo.com

# Trazado hasta el front (latencias intermedias)
mtr -rwzc 10 miapp.ejemplo.com 2>/dev/null || traceroute miapp.ejemplo.com

# Métrica de tiempo de respuesta y tamaño (para cuadros de mando)
curl -s -o /dev/null -w 'code=%{http_code} ttfb=%{time_starttransfer}s total=%{time_total}s size=%{size_download}B\n' https://miapp.ejemplo.com/ping
```

#### 12) Escaneo puntual de exposición (auditoría)

```bash
# Qué puertos están realmente expuestos externamente (banner y servicio)
nmap -sS -sV -p 1-1024,8080,8443 miapp.ejemplo.com
```

#### 12-Factor App: Diseño para operabilidad

**Transición**: La metodología 12-Factor alinea el diseño con la automatización y los bucles de feedback de CI/CD, asegurando servicios reproducibles y auditables.  

La metodología **12-Factor App** hace la operabilidad una propiedad del diseño:  
- **Port binding**: Servicios se publican en puertos, independientes de servidores externos.  
- **Configuración**: Variables de entorno separan parámetros por entorno.  
- **Backing services**: Estado en bases de datos o colas, tratados como recursos intercambiables.  
- **Logs**: Flujo continuo a stdout/stderr para recolección centralizada.  
- **Build/Release/Run**: Artefactos inmutables y versionados, con trazabilidad (hashes, SBOM).  

La **disposability** (arranques/paradas rápidos) facilita escalado y canarios. La paridad dev-prod reduce sorpresas. En CI/CD, estos principios habilitan pruebas automatizadas (HTTP, DNS, TLS) en cada etapa, generando evidencia para bucles de feedback. Ejemplo: Un release versionado con hash SHA256 asegura que el mismo artefacto pasa de staging a producción. En DevSecOps, escaneos de seguridad en el pipeline refuerzan la confianza en el despliegue.  

#### Ejemplos

#### 1) Port binding (el servicio publica su propio puerto)

```bash
# Arranca tu servicio como systemd (ej.: Laboratorio1/miapp.service)
sudo systemctl start miapp && systemctl status miapp
# Ver qué interfaz/puerto escucha (loopback vs público)
ss -ltnp | grep ':8080'
# Probar contrato HTTP básico
curl -i http://127.0.0.1:8080/ping
```

#### 2) Configuración por variables de entorno (no embebidas)

```bash
# Archivo seguro de entorno para producción
sudo sh -c 'printf "APP_ENV=prod\nDB_URL=postgres://user:pw@db:5432/app\nPORT=8080\n" > /etc/myapp.env'
sudo chmod 600 /etc/myapp.env
# La unit debe tener: EnvironmentFile=/etc/myapp.env
sudo systemctl daemon-reload && sudo systemctl restart miapp
# Ver variables cargadas por systemd (ojo: puede ocultar secretos)
systemctl show miapp -p Environment
```

#### 3) Backing services (recursos intercambiables por config)

```bash
# Comprobar resolución y reachability de la base de datos declarada en DB_URL
getent hosts db
nc -zv db 5432
# Cambiar de DB = editar /etc/myapp.env (DB_URL=...) y reiniciar
sudoedit /etc/myapp.env && sudo systemctl restart miapp
```

#### 4) Logs a stdout/stderr (recolección centralizada)

```bash
# Ver logs en tiempo real (journald)
journalctl -u miapp -f --output=short-iso
# Forzar formato "una línea" para parseo
journalctl -u miapp --since "10 min ago" -o cat
```

#### 5) Build /Release/Run (artefactos inmutables + trazabilidad)

```bash
# Identidad de la release
GIT_SHA=$(git rev-parse --short=12 HEAD)
# Empaqueta artefacto (ej.: binarios/scripts/config) de forma inmutable
git archive --format=tar --prefix=myapp-$GIT_SHA/ $GIT_SHA | gzip > myapp-$GIT_SHA.tar.gz
sha256sum myapp-$GIT_SHA.tar.gz > SHA256SUMS

# SBOM (si tienes syft/cyclonedx; opcional)
syft dir:. -o cyclonedx-json > sbom-$GIT_SHA.json 2>/dev/null || echo "syft no instalado"

# Metadatos de release (auditables)
cat > release-$GIT_SHA.json <<EOF
{"app":"myapp","git_sha":"$GIT_SHA","tar":"myapp-$GIT_SHA.tar.gz","sha256":"$(sha256sum myapp-$GIT_SHA.tar.gz | awk '{print $1}')","built_at":"$(date -Iseconds)"}
EOF
sha256sum release-$GIT_SHA.json
```

#### 6) Disposability (arranque/parada rápidos, señales limpias)

```bash
# Gate de readiness (espera hasta 200 en /readyz)
timeout 30 bash -c 'until curl -fsS http://127.0.0.1:8080/readyz >/dev/null; do sleep 0.2; done; echo READY'
# Parada limpia y tiempo de stop (SIGTERM -> shutdown ordenado)
sudo systemctl stop miapp
systemctl show -p TimeoutStopUSec miapp
```

#### 7) Paridad dev-prod (mismo artefacto, cambia solo config)

```bash
# Mismo código/commit, distinto env: ajusta /etc/myapp.env y recarga
sudoedit /etc/myapp.env
sudo systemctl restart miapp
# Verifica versión/commit expuesto por el servicio (endpoint /version o banner)
curl -s http://127.0.0.1:8080/version
```

#### 8) Gates en CI/CD (HTTP/DNS/TLS + seguridad)

```bash
# HTTP: código y latencias aceptables
curl -s -o /dev/null -w 'code=%{http_code} total=%{time_total}\n' http://app.internal/ping | tee http_check.txt
awk '/code=200/ && $2 ~ /total=0\.[0-9]{1,3}/ {ok=1} END{exit ok?0:1}' FS='[= ]' http_check.txt

# DNS: delegación mínima correcta
dig +trace app.example.com | tee dns_trace.txt
grep -q 'app.example.com.*A' dns_trace.txt

# TLS: versión y HSTS
curl -I --tlsv1.3 https://app.example.com | tee tls_hsts.txt
grep -iq '^strict-transport-security:' tls_hsts.txt

# Seguridad estática (ejemplos no acoplados a contenedores)
semgrep --error --config p/ci            # reglas base
bandit -r . -q                            # Python (si aplica)
pip-audit                                 # dependencias Python (si aplica)
shellcheck scripts/*.sh                   # scripts bash
```

#### 9) Blue/Green/Canary sin contenedores (dos instancias + Nginx)

```bash
# (opcional) Ejecuta segunda instancia en otro puerto (si la app respeta PORT)
PORT=8082 APP_ENV=prod ./app.py &   # o un segundo unit file miapp2.service con PORT=8082
# Nginx: upstream con pesos; luego valida y recarga
sudo nginx -t && sudo nginx -s reload
# Observa distribución de respuestas
seq 1 100 | xargs -I{} -P 10 curl -s http://localhost/track | sort | uniq -c
```

#### 10) "Statelessness" y archivos efímeros

```bash
# Ver que la app no persiste estado local inesperado (inspección ligera)
sudo lsof -p $(pidof miapp) | grep -E '(/var|/home|/tmp)'
```

En estos ejemplos **se auto-expone por puerto**, la **config** vive en entorno, los **backing services** se cambian por URL, los **logs** fluyen a journald, 
las **releases** son **inmutables y trazables** (hash/SBOM), la **disposability** permite escalar/canarios, mantienes **paridad dev-prod** y aplicas **gates** de  HTTP/DNS/TLS/seguridad en CI/CD.


### Notas sobre conceptos en inglés:

- **CALMS**: Framework que define cinco pilares de DevOps: Culture (colaboración), Automation (pipelines), Lean (eficiencia), Measurement (métricas), Sharing (aprendizaje compartido).  
- **You build it, you run it**: Principio donde el equipo que desarrolla un servicio lo opera, alineando diseño y responsabilidad operativa.  
- **CI/CD (Continuous Integration/Continuous Deployment)**: Automatización de integración, pruebas y despliegues para entregar cambios rápidos y seguros.  
- **SLO (Service Level Objectives)**: Metas medibles de disponibilidad y rendimiento.  
- **Runbooks**: Guías documentadas para operar y resolver incidentes.  
- **Postmortems**: Análisis post-incidente para aprender y mejorar.  
- **HSTS (HTTP Strict Transport Security)**: Política HTTP que fuerza conexiones seguras.  
- **ETag**: Identificador para validar caché en HTTP.  
- **DNSSEC (DNS Security Extensions)**: Valida la integridad de respuestas DNS.  
- **CAA (Certificate Authority Authorization)**: Restringe emisores de certificados.  
- **SNI (Server Name Indication)**: Selecciona certificados TLS según el dominio.  
- **ALPN (Application-Layer Protocol Negotiation)**: Negocia protocolos como HTTP/2.  
- **mTLS (mutual TLS)**: Autenticación bidireccional con certificados de cliente y servidor.  
- **OCSP stapling**: Validación de certificados incluida en el handshake TLS.  
- **12-Factor App**: Metodología para diseñar aplicaciones escalables y operables.  
- **SBOM (Software Bill of Materials)**: Lista de componentes de un artefacto de software.  
