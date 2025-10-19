### Actividad: Patrones de dependencias y módulos en IaC con Terraform y Python

La actividad busca de forma integrada, el desarrollo de  los patrones de dependencia más usados en ingeniería de software e IaC, desde flujos unidireccionales hasta inyección de dependencias, así como los patrones facade, adapter y mediator y que sepas cuándo aplicar cada uno para desacoplar, orquestar y evolucionar sistemas.

#### Pre-requisitos

* Utiliza el siguiente [Laboratorio 7](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio7) dado y las lecturas 15->17 del curso.
* Tener instalados:

  * Terraform (>= 1.0)
  * Python 3.8+
  * `make`


#### Fase 1: Relaciones unidireccionales

1. **Inspección**

   * Explora `network/network.tf.json` y `main.tf.json`.
   * Identifica recursos y sus dependencias implícitas (`depends_on`).

2. **Ejercicio práctico**

   * Ejecuta:

     ```bash
     cd network
     terraform init
     terraform apply -auto-approve
     cd ..
     make all
     ```
   * Observa el orden de creación y elimina (`terraform destroy`) para ver el orden de destrucción.


#### Fase 2: Inyección de dependencias

1. **Inversión de Control y inversión de dependencias**

   * Estudia `main.py`: allí se genera dinámicamente `main.tf.json` inyectando valores de `network`.
2. **Ejercicio práctico**

   * Modifica `main.py` para inyectar además parámetros de configuración del servidor (por ejemplo, nombre, etiquetas).
   * Vuelve a ejecutar `make all` y verifica que los nuevos parámetros aparecen en `main.tf.json`.

#### Fase 3: Patrón Facade

1. **Teoría**

   * ¿Cómo agruparías varios módulos (red + servidor + firewall) tras un únic "facade"?
2. **Ejercicio práctico**

   * Crea en `facade/` un `facade.tf.json` que exponga outputs simplificados (p.por ejemplo, `endpoint`, `network_id`).
   * Refactoriza `main.py` para usar este módulo de facade en lugar de llamadas directas.


#### Fase 4: Patrón Adapter

1. **Teoría**

   * El adaptador "envuelve" una interfaz incompatible para satisfacer otra.
2. **Ejercicio práctico**

   * Simula un módulo de "identidad" que en local usa `null_resource`, y crea un adaptador (`adapter.tf.json`) que convierta su output en formato Terraform estándar (por ejemplo, lista de usuarios -> JSON).


#### Fase 5: Patrón Mediator

1. **Teoría**

   * Centraliza la coordinación entre módulos complejos.
2. **Ejercicio práctico**

   * Implementa en Python un "mediador" (`mediator.py`) que, antes de generar `main.tf.json`, consulte el estado de `network`, `server` y `firewall` y establezca triggers/dependencias.

#### Fase 6: Elección de patrón

* **Actividad de discusión** (en pares o tríos):

  * Para un escenario complejo (p.por ejemplo, multi-cloud), justifica qué patrón(s) usarías y por qué.
  * Prepara una presentación de 5 min con ejemplos de código.


#### Fase 7: Estructura y compartición de módulos

1. **Monorepositorio vs multirepositorio**

   * Debate ventajas/desventajas.
2. **Ejercicio práctico**

   * Refactoriza el proyecto a multi-repositorio: extrae `network/`, `server/`, `facade/`, `adapter/`, `mediator/` a repositorios distintos.
   * Configura en cada uno un `README.md` y un pipeline de CI (GitHub Actions o similar).


#### Fase 8: Versionado y liberación

1. **Versionado semántico**

   * Asigna versiones (`v1.0.0`, `v1.1.0`, etc.) a cada módulo.
2. **Ejercicio práctico**

   * Crea tags de Git y un script en `Makefile` que haga:

     ```makefile
     release:
         git tag -a v$(VERSION) -m "Release $(VERSION)"
         git push --tags
     ```

#### Fase 9: Publicación y compartición

1. **Registro local vs Terraform registry**

   * Configura `providers.tf` para usar un `registry.local` (p.por ejemplo, con `terraform local publish` o repositorio Artifactory).
2. **Ejercicio práctico**

   * Publica uno de tus módulos en un registro local y úsalo desde otro proyecto clonándolo mediante `terraform init`.

#### Ejercicios adicionales

1. Explica las diferencias clave entre los patrones Facade, Adapter y Mediator en términos de acoplamiento y reutilización.
2. Describe un escenario real (por ejemplo, despliegue multi-cloud) y justifica qué patrón usarías para gestionar dependencias complejas, señalando ventajas e inconvenientes de cada opción.
3. Argumenta cómo la inversión de control y la inversión de dependencias mejoran la mantenibilidad de un proyecto IaC frente a relaciones unidireccionales.
4. Analiza posibles riesgos o anti-patrones al abusar de la inyección de dependencias en módulos Terraform.
5.  Compara monorepositorio vs. multirepositorio para un conjunto de módulos IaC usados por diferentes equipos. Incluye criterios de escalabilidad, gobernanza y velocidad de despliegue.
6. Diseña un flujo de trabajo de Git (ramas, tags, pull requests) adecuado para ambos modelos, destacando diferencias en la gestión de versiones compartidas.
7. Justifica el uso de versionado semántico en módulos Terraform. ¿Qué consecuencias podría tener omitirlo?
8. Propón una política de gestión de releases para un registro privado de módulos, incluyendo cadencias y criterios de bump de versión (mayor, menor, parche).
9. Evalúa ventajas y desventajas de publicar módulos en Terraform Cloud Registry frente a un repositorio Git interno.
10. Describe cómo implementarías un mecanismo de autenticación y control de acceso para tu registro de módulos en un entorno corporativo.
11. Toma el módulo de red y rediseña su interfaz para que admita un nuevo recurso (por ejemplo, balanceador de carga) inyectado por un patrón Mediator. Indica qué cambios harías en la generación de la configuración y en la orquestación Python.
12. Crea un módulo "unificado" que agrupe red, servidor y monitorización bajo un único facade. Describe detalladamente las entradas y salidas de ese módulo y cómo garantizarías que las dependencias internas no se expongan al consumidor.
13. (Opcional) Diseña un adaptador que permita usar, de forma transparente, recursos de un proveedor ficticio (p. por ejemplo, "localmock") con la misma interfaz que tus módulos actuales de GCP. Explica cómo transformarías los outputs para encajar en los consumidores existentes.
14. Refactoriza el proyecto original a un esquema multi-repositorio. Detalla en un documento los pasos de migración de cada módulo, la configuración de los pipelines CI/CD y los cambios en los pipelines de integración.
15. Implementa en tu Makefile o en tu sistema de CI un proceso automatizado que, tras cada merge a la rama principal, actualice la versión semántica de uno de los módulos, genere un tag Git y publique el módulo en un registro local.
16. Monta un registro privado (puede ser un simple servidor HTTP o un artefacto de Git) y publica al menos dos versiones de un módulo. Luego, desde otro proyecto, configura el `source` para consumirlo por versión fija y por rango de versiones, y demuestra la actualización controlada.


### Entrega

Para completar la actividad se debe crear una carpeta principal llamada `Actividad15-CC3S2`. Esta carpeta contendrá todos los entregables organizados de manera clara y estructurada, incluyendo código, documentación, diagramas, informes y evidencias de ejecución. 

#### Ejemplo de estructura general de la carpeta 

```
Actividad15-CC3S2/
├── README.md                  # Resumen general de la actividad, instrucciones de ejecución y enlaces a repositorios (si aplica).
├── codigo/                    # Carpeta con todo el código fuente y modificaciones.
│   ├── network/               # Módulo original de red (de Laboratorio 7), con modificaciones si aplica.
│   │   ├── network.tf.json
│   │   └── ... (otros archivos del lab)
│   ├── main.py                # Versión modificada con inyección de dependencias (Fase 2).
│   ├── facade/                # Módulo facade (Fase 3).
│   │   └── facade.tf.json
│   ├── adapter/               # Módulo adapter (Fase 4).
│   │   └── adapter.tf.json
│   ├── mediator.py            # Script mediador en Python (Fase 5).
│   ├── server/                # Módulo de servidor (extraído o referenciado, si aplica en refactor).
│   ├── firewall/              # Módulo de firewall (extraído o referenciado).
│   ├── Makefile               # Actualizado con comandos como 'release' (Fase 8).
│   └── otros_modulos/         # Si se crean módulos adicionales (por ejemplo unificado de Fase 12 o adaptador ficticio de Fase 13).
├── documentacion/             # Carpeta con informes, explicaciones y diagramas.
│   ├── informe_fase1.pdf      # Breve informe (1 página) sobre separación unidireccional (Fase 1).
│   ├── explicacion_ioc.txt    # Explicación corta (máx. 300 palabras) de inversión de control (Fase 2).
│   ├── diagrama_facade.png    # Diagrama de alto nivel del facade (Fase 3).
│   ├── explicacion_adapter.txt# Explicación de uso del patrón adapter en producción (Fase 4).
│   ├── comparacion_mediator_facade.txt # Breve comparación entre mediator y facade (Fase 5).
│   ├── presentacion_discusion.pptx # Presentación de 5 min sobre elección de patrones en escenario complejo (Fase 6).
│   ├── tabla_mono_vs_multi.md # Tabla comparativa de monorepositorio vs multirepositorio (Fase 7).
│   ├── informe_final.pdf      # Informe final (3-4 páginas) cubriendo análisis de patrones, elecciones de diseño, comparativa mono/multi, versionado/publicación y ejercicios resueltos.
│   └── ejercicios_adicionales/ # Subcarpeta con respuestas a los 16 ejercicios adicionales.
│       ├── ejercicio1.txt     # Diferencias entre Facade, Adapter y Mediator.
│       ├── ejercicio2.txt     # Escenario real (multi-cloud) y justificación de patrones.
│       ├── ... (hasta ejercicio16.txt)
├── evidencias/                # Carpeta con capturas de pantalla, grafos y logs.
│   ├── graph.png              # Grafo de dependencias (Fase 1).
│   ├── logs_apply_destroy.txt # Logs de ejecución de terraform apply/destroy (Fase 1 y 2).
│   ├── ejemplo_release.txt    # Ejemplo de releases con al menos dos versiones (Fase 8).
│   ├── captura_registro.png   # Captura de módulo instalado desde registro local (Fase 9).
│   └── pipelines/             # Configuraciones de CI/CD (por ejemplo .github/workflows/ para cada repositorio en multi-repositorio).
├── repositorios/              # Si se usa multi-repositorio (Fase 7), incluye clones locales o enlaces.
│   ├── network_repo/          # Clone o enlace a repositorio de network.
│   ├── server_repo/           # Clone o enlace a repositorio de server.
│   ├── facade_repo/           # Etc.
│   └── README_repos.md        # Enlaces a repositorios GitHub creados y tabla comparativa de tiempo/desarrollo.
└── registry/                  # Configuración de registro local (Fase 9).
    ├── providers.tf           # Configuración para registry local.
    └── ejemplo_publicacion/   # Scripts o logs de publicación y consumo de módulos.
```

#### Detalles de los entregables por fase y sección

1. **Fase 1: Relaciones unidireccionales**
   - `evidencias/graph.png`: Captura del grafo de dependencias.
   - `documentacion/informe_fase1.pdf`: Informe de 1 página sobre separación unidireccional.
   - `evidencias/logs_apply_destroy.txt`: Logs de ejecución.

2. **Fase 2: Inyección de dependencias**
   - `codigo/main.py`: Código modificado con inyección de parámetros adicionales (por ejemplo nombre, etiquetas).
   - `documentacion/explicacion_ioc.txt`: Explicación corta del principio de inversión de control.

3. **Fase 3: Patrón Facade**
   - `codigo/facade/facade.tf.json`: Código del facade con outputs simplificados.
   - `codigo/main.py`: Refactorizado para usar el facade.
   - `documentacion/diagrama_facade.png`: Diagrama de alto nivel.

4. **Fase 4: Patrón Adapter**
   - `codigo/adapter/adapter.tf.json`: Código del adapter con ejemplo de uso.
   - `documentacion/explicacion_adapter.txt`: Explicación de uso en producción.

5. **Fase 5: Patrón Mediator**
   - `codigo/mediator.py`: Script con comentarios.
   - `documentacion/comparacion_mediator_facade.txt`: Comparación breve.

6. **Fase 6: Elección de patrón**
   - `documentacion/presentacion_discusion.pptx`: Presentación de 5 min con ejemplos de código.

7. **Fase 7: Estructura y compartición de módulos**
   - `repositorios/`: Clones o enlaces a repositorios separados, cada uno con `README.md` y pipeline CI (por ejemplo YAML de GitHub Actions).
   - `documentacion/tabla_mono_vs_multi.md`: Tabla comparativa (columnas: Ventajas, Desventajas, Tiempo de desarrollo, Facilidad de uso).

8. **Fase 8: Versionado y liberación**
   - `codigo/Makefile`: Actualizado con target `release`.
   - `evidencias/ejemplo_release.txt`: Logs o evidencias de al menos dos versiones (por ejemplo v1.0.0 y v1.1.0).

9. **Fase 9: Publicación y compartición**
   - `registry/providers.tf`: Configuración para registry local.
   - `evidencias/captura_registro.png`: Captura de instalación del módulo.
   - `registry/ejemplo_publicacion/`: Scripts o logs de publicación.

10. **Ejercicios adicionales**
    - `documentacion/ejercicios_adicionales/`: Un archivo .txt por ejercicio (1 al 16), con respuestas detalladas. Por ejemplo:
      - Ejercicio 1: Diferencias en acoplamiento (Facade reduce complejidad, Adapter convierte interfaces, Mediator coordina interacciones) y reutilización.
      - Ejercicio 11: Rediseño del módulo de red con mediator para inyectar balanceador de carga, modificando mediator.py para triggers.
      - Ejercicio 15: Proceso automatizado en Makefile o CI para versionado y publicación.
      - Ejercicio 16: Configuración de registry privado con ejemplos de consumo por versión fija/rango.

11. **Entregables finales**
    - Toda la carpeta `codigo/` con organización y versiones (usa Git para tags).
    - Carpeta `documentacion/` con README, diagramas y tablas.
    - Scripts en `codigo/Makefile` y evidencias en `evidencias/`.
    - `documentacion/informe_final.pdf`: Informe de 3-4 páginas integrando todo: análisis de patrones (ventajas/inconvenientes), elecciones (por ejemplo mediator para multi-cloud por coordinación central), comparativa mono/multi (escalabilidad vs. gobernanza), prácticas de versionado/publicación, y resolución de ejercicios.

#### Notas adicionales para completar la actividad

- **Ejecución y Pruebas**: Asegúrate de que todo el código sea ejecutable. Por ejemplo, desde la raíz: `make all` debe generar y aplicar configuraciones sin errores.
- **Formato**: Usa Markdown para tablas y texto, PDF para informes formales, PNG para diagramas (puedes usar herramientas como Draw.io).
- **Longitud y Calidad**: Mantén las explicaciones concisas pero completas. Incluye referencias a lecturas 15-17 del curso.
- **Originalidad**: Todo código debe estar comentado, y los informes deben reflejar comprensión propia (no copiar texto genérico).
- **Si usas multi-repositorio**: Proporciona enlaces a GitHub en `repositorios/README_repos.md`. Si es monorepositorio, mantén todo en `codigo/`.

