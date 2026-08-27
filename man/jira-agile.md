# jira-agile(1) -- Tableros y Sprints de Jira Software

## SINTAXIS
`jira board list` [opciones]  
`jira sprint current` [BOARD_ID] [opciones]  
`jira sprint list` [BOARD_ID] [opciones]  
`jira sprint issues` <SPRINT_ID> [opciones]  
`jira sprint add` <SPRINT_ID> <ISSUE_KEY>  

## DESCRIPCIÓN
Interactúa con los endpoints ágiles de Jira Software (`/rest/agile/1.0/`) para consultar tableros Scrum/Kanban, ver sprints activos y gestionar tickets en sprint.

## OPCIONES
* `--state` <active|future|closed>:
  Filtra sprints por estado.
* `--output` <formato>:
  Formato de salida: `json`, `table`, `md`.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Listar todos los tableros ágiles
jira board list
jira board list --output table

# Ver el sprint activo actual del proyecto
jira sprint current

# Ver los tickets dentro del sprint activo
jira sprint issues 450
jira sprint issues 450 --output table

# Agregar un ticket al sprint
jira sprint add 450 PROJ-123
```
