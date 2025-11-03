# SECURITY.md

## Política de imagen
- Prohibido usar `:latest` en producción.
- Cada imagen debe tener tag inmutable (`etl-app:1.0.0`) y digest (`@sha256:...`).
- Se debe generar SBOM (`make sbom`) y pasar escaneo de vulnerabilidades (`make scan`) antes de publicar.

## Usuarios y privilegios
- Ningún contenedor de aplicación puede correr como root.
- Prohibido `--privileged` o `cap-add` sin justificación explícita y revisión.
- Postgres no se expone al host ni a internet: vive en la red interna `backend`.

## Puertos
- Solo se publica `8080:8080` para `airflow-webserver`, porque es la consola que necesitamos ver.
- Publicar un puerto es una decisión de seguridad, no un paso mecánico.

## Secretos
- `.env` NO se commitea. `.env.example` es la única versión que entra al repo.
- Está prohibido hardcodear credenciales en Dockerfile, código Python o docker-compose.yml.
- Recordatorio: `docker inspect` revela variables de entorno. Para entornos serios se migra a secret managers.

## Anti-patrones que RECHAZAMOS en PR
- `FROM ubuntu:latest` + `apt-get install` infinito sin limpiar → superficie enorme.
- Ejecutar como root "porque necesito puerto 80".
- Copiar llaves SSH / tokens / passwords dentro de la imagen.
- Hacer `docker compose up` en una VM pública y llamarla "producción" sin TLS, sin firewall y sin monitoreo.
- Exponer la base de datos (`5432:5432`) hacia internet sólo para probar con un GUI.

Si detectas alguno de esos puntos en un PR, se rechaza.
