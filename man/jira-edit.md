# jira-edit(1) -- Edición granular de campos en issues

## SINTAXIS
`jira edit` <ISSUE_KEY> [opciones]  
`jira issue edit` <ISSUE_KEY> [opciones]  

## DESCRIPCIÓN
Modifica campos específicos de un ticket existente (resumen, descripción, prioridad, asignación, etiquetas y componentes) de forma atómica y sin tener que construir JSON a mano.

En Jira Cloud (v3), la descripción se convierte automáticamente de Markdown a ADF.

## OPCIONES
* `-s`, `--summary` <texto>:
  Nuevo título/resumen del ticket.
* `-d`, `--description` <texto>:
  Nueva descripción (soporta Markdown). Usa `-` para leer desde stdin.
* `--description-file` <ruta>:
  Lee la descripción desde un archivo Markdown/texto.
* `-P`, `--priority` <nombre>:
  Nueva prioridad (High, Medium, Low, etc.).
* `-a`, `--assignee` <usuario|email|me|none>:
  Asignar ticket a un usuario o desasignar (`none`).
* `--add-label` <etiquetas>:
  Agrega etiquetas separadas por comas (`--add-label backend,v2`).
* `--remove-label` <etiquetas>:
  Elimina etiquetas separadas por comas.
* `--add-component` <componentes>:
  Agrega componentes al ticket.
* `--remove-component` <componentes>:
  Elimina componentes del ticket.
* `-f`, `--field` key=value:
  Modifica un campo personalizado directo.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Cambiar título y prioridad
jira edit PROJ-123 --summary "Nuevo título refinado" --priority High

# Actualizar descripción desde archivo Markdown
jira issue edit PROJ-123 --description-file ./docs/spec.md

# Agregar y remover etiquetas de forma atómica
jira edit PROJ-123 --add-label "backend,api" --remove-label "legacy"

# Asignar a uno mismo
jira edit PROJ-123 --assignee me
```
