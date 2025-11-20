## Curso de desarrollo de software CC3S2
Curso práctico y básico para llevar código a producción, enfocándose en calidad, automatización, seguridad y operabilidad. Cubre  metodologías ágiles, Git, TDD/BDD (pytest/behave), CI/CD (GitHub Actions), Infraestructura como Código (Terraform, OPA/tfsec), contenedores (Docker), orquestación (Kubernetes), observabilidad (OpenTelemetry, Prometheus, Grafana) y DevSecOps (SAST/SCA/DAST, SBOM, SLSA, NIST SSDF) de manera local. Incluye verificación formal (TLA+) y AIOps/LLMs con guardrails para IA segura en DevOps.

Este repositorio contiene lecturas, laboratorios y ejemplos de código.

#### Prerrequisitos

- Python 3 (scripts, pytest).
- Linux/Bash básico (CLI, procesos, permisos, pipes).
- Git básico (ramas, merge, PRs).

### Unidades de aprendizaje

#### Capítulo 1: DevOps y desarrollo moderno
- Introducción a DevOps y DevSecOps.
- Linux/Bash, Make, automatización.
- Redes/Arquitectura: HTTP/DNS/TLS, 12-Factor App.

#### Capítulo 2: Desarrollo ágil y Git
- Git: merge, rebase, cherry-pick, CI/CD.
- BDD (behave), TDD (pytest, AAA, cobertura).
- Gestión ágil: GitHub Projects, sprints.

#### Capítulo 3: Infraestructura como Código
- Terraform: módulos, dependencias.
- Seguridad IaC: OPA/Conftest, tfsec, NIST SSDF.

#### Capítulo 4: Contenedores y Despliegue
- Docker, Docker Compose, buenas prácticas.
- Kubernetes: pods, deployments, servicios.
- Seguridad: SBOM (Syft), firma (cosign), SAST/SCA/DAST, SLSA L2.
- Despliegues: blue-green, canary, feature flags.

#### Capítulo 5: Observabilidad y Resiliencia
- Observabilidad: OpenTelemetry, Prometheus, Grafana.
- SRE: SLO/SLI, on-call, post-mortems.
- Seguridad Kubernetes: RBAC, policies, secretos.
- AIOps/LLMs: detección de anomalías, pruebas/doc con guardrails.

### Cronograma (Semanal)

- **Semana 1 (25-27/08)**: Introducción al curso, Linux/Bash.
- **Semana 2 (01-03/09)**: Git básico, Makefile, linters.
- **Semana 3 (08-10/09)**: Git avanzado (merge, flujos).
- **Semana 4 (15-17/09)**: BDD/TDD, P1 (17/09).
- **Semana 5 (22-24/09)**: pytest, rebase, CI/CD.
- **Semana 6 (29/09-01/10)**: Sprints, P2 (01/10).
- **Semana 7 (06-08/10)**: Terraform, feriado (08/10).
- **Semana 8 (20-22/10)**: IaC módulos, seguridad IaC.
- **Semana 9 (27-29/10)**: Docker/Compose, P3 (29/10).
- **Semana 10 (03-05/11)**: Kubernetes, despliegues.
- **Semana 11 (10-12/11)**: CI/CD, SBOM, SLSA, P4 (12/11).
- **Semana 12 (17-19/11)**: Microservicios, despliegues progresivos.
- **Semana 13 (24-26/11)**: Observabilidad, SRE.
- **Semana 14 (01-03/12)**: Seguridad K8s, P5 (03/12).
- **Semana 15 (08-10/12)**: Feriado (08/12), AIOps/LLMs.

**Exámenes**: Parcial (13/10), Final (15/12), Sustitutorio (22/12).

### Metodología

Semipresencial: 2 horas/semana teoría, 4 horas/semana práctica. Clases combinan bases teóricas con aplicaciones prácticas.

### Evaluación

- **Prácticas (P1-P5)**: 5 prácticas calificadas, elimina la menor nota, promedia las 4 restantes (PP).
- **Exámenes**: Parcial (EP), Final (EF), Sustitutorio opcional (ES).
- **Fórmula**:
  - PC = (PP + EP + EF) / 3 (sin ES).
  - PC = (PP + máx(EP, EF) + ES) / 3 (con ES).

#### Rúbricas de prácticas (sobre 20 puntos)

| Categoría                | Sobresaliente (2-3 pts)                              | Regular (1 pt)                              | Pésimo (0 pts)                              |
|--------------------------|-----------------------------------------------------|---------------------------------------------|---------------------------------------------|
| **Videos de sprints**    | Claros, completos, con explicación técnica.          | Incompletos, poca claridad u organización.  | Ausentes o sin avance real.                 |
| **Código y documentación** | Limpio, modular, bien documentado, buen uso de Git. | Funcional, pero con fallos o poca documentación. | Desordenado, sin documentación, mal uso de Git. |
| **Exposición**           | Clara, estructurada, con dominio técnico.           | Aceptable, pero falta claridad o estructura. | Deficiente, sin dominio ni claridad.        |
| **Preguntas docente**    | Respuestas precisas, técnicas (5-11 pts).           | Respuestas parciales (2-4 pts).             | Sin respuestas o incorrectas (0-1 pt).      |

### Estructura del repositorio

- `/docs/`: Guías y recursos.
- `/labs/`: Laboratorios de clase.
- `/ejemplos/`: Ejemplos de código (Git, Terraform, Docker, etc.).
- `/proyectos/`: Plantillas para proyectos y sprints.
- `/actividades/`: Actividades del curso, evidencia de avance.
