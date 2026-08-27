# jira-transition(1) -- Gestión de transiciones y flujos de estado

## SINTAXIS
`jira transition` [list] <ISSUE_KEY> [opciones]  
`jira transition to` <ISSUE_KEY> <ID|NAME>  
`jira transition done` <ISSUE_KEY> [opciones]  
`jira transition redo` <ISSUE_KEY> [opciones]  
`jira done` <ISSUE_KEY> [-m "mensaje"]  
`jira redo` <ISSUE_KEY>  
`jira issue transition` ...  
`jira issue` <ISSUE_KEY> `--transition` <SPEC>  
`jira issue` <ISSUE_KEY> `--to-done`  

## DESCRIPCIÓN
Muestra y ejecuta transiciones de estado en tickets de Jira.

El subcomando `done` resuelve automáticamente el camino de transiciones necesarias para llevar el ticket desde su estado actual hasta la categoría "Done" del workflow del proyecto sin necesidad de especificar IDs fijos.

## OPCIONES
* `--to` <ID>:
  ID de transición directa a ejecutar.
* `--transition` <SPEC>:
  Aplica transición por ID, nombre exacto de transición o nombre del estado destino.
* `-m`, `--message` <texto>:
  Agrega un comentario de cierre al completar la transición a Done.
* `--discard`:
  Descarta/cancela el ticket en lugar de completarlo normalmente.
* `--output` <formato>:
  Formato de salida para la lista de transiciones: `json`, `table`, `md`.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Ver transiciones disponibles para un issue
jira transition list PROJ-123
jira transition PROJ-123

# Transicionar automáticamente hasta Done
jira done PROJ-123
jira done PROJ-123 -m "Cerrado tras merge en dev"

# Reabrir ticket (Redo)
jira redo PROJ-123

# Aplicar transición específica por nombre de estado
jira transition to PROJ-123 "In Progress"
jira issue PROJ-123 --transition "Code Review"
```
