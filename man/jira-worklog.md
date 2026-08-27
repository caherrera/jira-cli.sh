# jira-worklog(1) -- Registro e imputación de tiempo en Jira

## SINTAXIS
`jira worklog add` <ISSUE_KEY> <tiempo> [opciones]  
`jira worklog list` <ISSUE_KEY> [opciones]  
`jira worklog delete` <ISSUE_KEY> <WORKLOG_ID>  
`jira worklog` <ISSUE_KEY> <tiempo> [opciones]  
`jira issue worklog` ...  
`jira issue` <ISSUE_KEY> `--worklog` <tiempo>  

## DESCRIPCIÓN
Registra tiempo trabajado e inspecciona el historial de imputaciones de un ticket.

Soporta formatos de tiempo naturales: `2h`, `30m`, `1d 4h`, `1h 15m`, `90m`.

## OPCIONES
* `-m`, `--message` <texto>:
  Descripción o comentario de la actividad realizada.
* `--started` <fecha_hora>:
  Fecha y hora de inicio de la actividad (ISO 8601, ej: `2026-08-26T10:00:00.000+0000`).
* `--output` <formato>:
  Formato de salida para listado: `json`, `table`, `md`.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Imputar 2 horas y media de trabajo
jira worklog add PROJ-123 2h30m -m "Implementación de tests unitarios"
jira worklog PROJ-123 1h -m "Code review y validación"
jira issue PROJ-123 --worklog 45m -m "Reunión de refinamiento"

# Listar horas registradas en el ticket
jira worklog list PROJ-123
jira worklog list PROJ-123 --output table

# Eliminar una imputación de tiempo
jira worklog delete PROJ-123 10550
```
