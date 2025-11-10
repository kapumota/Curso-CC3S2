### Actividad: Gobernanza y Seguridad Operacional en Infraestructura como Código

Esta actividad ayuda a entender que IaC no es solo "Terraform apply", sino una práctica completa que incluye gobernanza, seguridad y evidencia. 
Gobernanza significa definir con claridad quién puede modificar cada módulo de infraestructura, cómo se comparte ese módulo entre equipos y cómo se controla su evolución mediante versionado formal. 
Seguridad implica tener controles automáticos (gates) que bloquean configuraciones inseguras por ejemplo, exponer recursos públicos sin justificación o filtrar secretos antes de que algo llegue a producción. 

Finalmente, evidencia significa poder demostrar que se cumplieron los controles: guardar planes firmados, reportes de cumplimiento de políticas, rotación de credenciales y trazas de auditoría que permitan mostrar, en cualquier momento, qué se cambió, quién lo cambió y bajo qué condiciones de seguridad.
  
> Utiliza las lecturas [Lectura 18](https://github.com/kapumota/Curso-CC3S2/blob/main/docs/Lectura18.md), [Lectura 19](https://github.com/kapumota/Curso-CC3S2/blob/main/docs/Lectura19.md)  y al siguiente [ejemplo](https://github.com/kapumota/Curso-CC3S2/tree/main/ejemplos/IaC-seguridad) dado.

#### Parte A. Preguntas teórico-conceptuales (responder en texto)

**A1. Monorepositorio vs. repositorios múltiples (respuesta ~200 palabras).**
Imagina que hoy todo tu IaC vive en un solo repositorio. Explica:

1. ¿Por qué este enfoque inicialmente acelera el "bootstrap" del equipo?
2. ¿Por qué empieza a romperse cuando hay muchas personas cambiando cosas al mismo tiempo (locks, reviewers agotados, CI lento, permisos demasiado amplios)? 
3. ¿Cuándo tendría sentido "extraer" un módulo (por ejemplo `modules/network/`) a su propio repositorio/versionado independiente? Explica el flujo resumido de migración (aislar directorio -> filtrar historial git -> crear pipeline propio -> publicar `v1.0.0`). 

**A2. Versionado semántico y notas de versión (respuesta ~150 palabras).**
Define con tus palabras qué significa publicar un módulo IaC en `v1.0.0`, `v1.1.0` y `v1.1.1`. 
¿Cuándo sube el número mayor (breaking change), cuándo sube el menor (nueva capacidad compatible) y cuándo sube el patch (bugfix)? 
Explica también por qué **NO** es aceptable que otro equipo "apunte a `main`" sin etiqueta firmada. Incluye qué debe contener una buena nota de versión para que otro equipo sepa migrar sin romper producción 
(impacto operativo, variables nuevas/eliminadas, pasos manuales si los hay). 

**A3. Seguridad en cadena de suministro (respuesta ~200 palabras).**
Resume con tus palabras estas tres ideas y por qué son obligatorias en un pipeline serio de IaC:

* **SBOM + verificación de proveedores** (bloquear binarios o providers manipulados).
* **SLSA / procedencia firmada del artefacto** (saber de qué commit, qué pipeline y quién generó el módulo que estás usando).
* **Política de "solo etiquetas firmadas" para producción** (rechazar módulos sin firma válida). 

**A4. Secretos y privilegio mínimo (respuesta ~200 palabras).**
Describe un error típico de estudiantes o equipos junior respecto a secretos (por ejemplo, dejar un `AWS_ACCESS_KEY` en el repositorio o exponerlo en un `output`). Explica cómo debería ser el flujo correcto usando:

* gestor centralizado de secretos,
* rotación frecuente/TTL corto,
* alcance por entorno (`dev`, `staging`, `prod`),
* y pruebas/políticas que fallen si un output parece contener un secreto.
  Cierra diciendo por qué esto está directamente ligado al principio de **privilegio mínimo** en IAM y por qué es auditable. 

**A5. Evidencia y auditoría (respuesta ~150 palabras).**
¿Por qué en IaC ya no vale "confía en mí, yo lo configuré bien"?
Menciona ejemplos de evidencia que un equipo debe guardar:

* SBOM con hash,
* resultado del escaneo de secretos,
* hash del `tfstate` + traza de `plan/apply`,
* reporte de drift detectado vs. corregido.
  Explica por qué retener esa evidencia con fechas y responsables permite mapear cada control técnico a un control normativo (ISO, NIST, PCI) y pasar auditoría sin teatro. 

#### Parte B. Ejercicio práctico

En esta parte no se despliega a la nube. El objetivo es simular un pipeline DevSecOps de IaC en local.

**Contexto:**
Se asume que les diste un mini-repositorio local de IaC (por ejemplo el que ya preparaste con Makefile y directorio `.evidence/`) con targets tipo:

```bash
make plan        # genera un plan JSON reproducible (por ejemplo, ./.evidence/plan.json)
make policy      # corre validaciones OPA/Conftest sobre el plan
make sbom        # genera un SBOM del módulo y lista proveedores/dependencias
make evidence    # empaqueta artefactos de auditoría listos para archivar
```

> Si los nombres reales de tus targets son distintos, el/la estudiante debe adaptarse, pero la idea es esta misma tubería local: plan -> policy -> sbom -> evidencia.

#### B1. Captura de plan y policy

1. Ejecuta `make plan`.
2. Abre el archivo de plan generado (normalmente algo tipo `plan.json` o `plan.tfplan` convertido a JSON).
3. Ejecuta `make policy`.
4. Describe en un archivo `respuestas/B1.txt`:

   * ¿La política bloquea algo inseguro? Por ejemplo, ¿bloquearía exponer un bucket público o imprimir un secreto en un output? Explica con tus palabras el tipo de chequeo que viste. 
   * ¿Qué pasaría si intentas "forzar" algo inseguro en `main.tf` y vuelves a correr `make policy`?

#### B2. SBOM y cadena de suministro

1. Ejecuta `make sbom`.
2. Abre el SBOM generado (JSON).
3. En `respuestas/B2.txt`, responde:

   * ¿Qué dependencias/proveedores aparecen listadas?
   * ¿Por qué guardar este archivo con hash y firma ayuda a demostrar procedencia y a cumplir con niveles SLSA (integridad del artefacto)? 
   * ¿Cómo usarías esto para decirle a un auditor: "no estamos bajando providers random de internet, todo viene de un mirror interno controlado"? 

#### B3. Evidencia y gobernanza

1. Ejecuta `make evidence` (o el target equivalente que compacte `.evidence/` en algo tipo `evidencia-YYYYMMDD.tar` con hashes).
2. En `respuestas/B3.txt`, redacta:

   * ¿Qué piezas mínimas de evidencia incluirías en un ticket de cambio antes de aplicar en `prod`? Por ejemplo: plan firmado, SBOM con hash, resultado del escaneo de secretos, y mención de qué tag semántico (`v1.2.0`) del módulo se va a usar.  
   * ¿Quién debería ser Responsible y quién Accountable según un esquema RACI cuando vas a aplicar ese cambio en infraestructura real? Explica con tus palabras (usa R/Responsible = quien ejecuta la tarea y A/Accountable = quien responde formalmente por el resultado). 


#### Parte C. Preguntas adicionales

**C1. Gobernanza vs velocidad (~150 palabras).**
Contesta: ¿Cómo puedo permitir que los equipos de producto avancen rápido creando/modificando módulos (autonomía), pero al mismo tiempo imponer políticas duras (encriptado por defecto, IAM mínimo, no secretos en outputs, TLS 1.3+ obligatorio) sin volver el proceso burocrático? Relaciona tu respuesta con:

* separar módulos en repositorios distintos con dueños naturales,
* versionado semántico con notas de versión claras,
* gates automáticos (OPA, escaneo de secretos, SBOM),
* y métricas tipo DORA / KPIs de IaC (tiempo de revisión, locks concurrentes bajos, % de rechazos por política bajo pero distinto de 0).  

### Entregable

Cada estudiante sube una carpeta llamada `Actividad-IaC-Seguridad-Gobernanza/` con:

1. `A1-A5.md`

   * Todas las respuestas de la Parte A (en prosa, no bullets sueltos).
2. `respuestas/`

   * `B1.txt`, `B2.txt`, `B3.txt` con las observaciones prácticas.
3. `evidencia-local/`

   * Copia de los artefactos generados por su ejecución local del mini-repositorio:

     * plan (`plan.json` o equivalente),
     * salida del policy check (puede ser `policy_result.txt` o similar),
     * SBOM (`sbom-*.json`),
     * paquete de evidencia (`.tar`, `.zip` o carpeta `.evidence/` si aplica).
4. `REFLEXION.md`

   * La respuesta de C1.

> Trabajo **individual**. No vale compartir el mismo SBOM o el mismo plan exacto entre dos personas: cada entrega debe venir de la propia ejecución local del repositorio que se ha utilizado.
