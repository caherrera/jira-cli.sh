## Changelog

### [Unreleased]

#### Jira Cloud API v3 (búsqueda y autenticación)

- **Búsqueda JQL**: corrige el reemplazo de URL `/rest/api/3/search?` → `/rest/api/3/search/jql?` en `src/jira.sh` y `lib/jira.search.sh` (endpoint requerido en Cloud v3).
- **Basic Auth / PAT**: si `JIRA_AUTH` es `basic` y `JIRA_EMAIL` + `JIRA_API_TOKEN` están definidos, se ignora `JIRA_TOKEN` cuando contiene un PAT crudo (`ATATT*`), evitando fallos de autenticación por mala configuración.

#### Movimiento de issues entre proyectos

- **Nuevo flujo de `move`**: se agrega el atajo `jira move KEY --to-project PROJ` y la opción `--move PROJ` en `jira issue` para clonar un issue en otro proyecto (útil para mover trabajo entre tableros).
- **Clonado y enlace automático**: el nuevo issue hereda `summary`, `description`, `labels` y componentes del origen (cuando existen en el proyecto destino) y crea un enlace de tipo *Relates* entre el issue original y el nuevo.
- **Gestión de componentes destino**:
  - Si un componente del origen no existe en el proyecto destino, puede crearse interactívamente (o automáticamente con `--yes`).
  - La opción `--components A,B` permite sobrescribir completamente la lista de componentes del issue destino.
- **Modo no interactivo**: `--yes` evita preguntas sobre tipo de issue y creación de componentes, pensado para scripts y automatizaciones.
- **Autocompletado actualizado**: scripts de completion para Bash y Zsh actualizados para sugerir el recurso `move` y las opciones `--move`, `--to-project`, `--components` y `--yes`.

#### Componentes de proyecto (export / import)

- **Exportar componentes**: `jira project components PROJ --export --format json|csv|yaml|tsv` vuelca la lista de componentes de un proyecto a stdout, pensado para backup o migraciones entre instancias/proyectos.
- **Importar componentes**: `jira project components PROJ --import --format ...` lee desde stdin y crea componentes que no existan aún en el proyecto destino.
- **Validaciones de uso**:
  - Se impide combinar `--export` y `--import` en la misma llamada.
  - Se valida el valor de `--format` y se muestran mensajes claros cuando el formato no es soportado.
- **Autocompletado**: los scripts de completion ahora sugieren `components` como subcomando de `project` y completan `--export`, `--import` y `--format` con sus formatos soportados.

#### Ayuda, documentación y tests

- **Ayuda integrada**:
  - `jira --help` muestra ahora el recurso `move` y las nuevas opciones relacionadas con movimiento de issues.
  - `jira issue -h` documenta `--move`, `--components` y `--yes`, junto con ejemplos completos de uso.
  - `jira project -h` documenta `components`, `--export`, `--import` y `--format`, con ejemplos de export e import.
- **README actualizado**:
  - Se añaden ejemplos de `jira issue --move` y `jira move --to-project` en la sección de uso simplificado.
  - Se documenta el flujo de exportación/importación de componentes, incluyendo formatos soportados y limitaciones.
- **Cobertura de tests**:
  - Nuevo `test_issue_move.sh` que valida errores de uso, mensajes de ayuda y comportamiento básico de `jira issue --move` / `jira move`.
  - `test_project_components.sh` ampliado para cubrir `--export`, `--import`, validación de `--format` y mensajes de error cuando se combinan flags incompatibles.

