# jira-branch(1) -- Gestor de ramas Git vinculadas a Jira

## SINTAXIS
`jira branch` [create] <ISSUE_KEY> [opciones]  
`jira branch rename` <ISSUE_KEY> [opciones]  
`jira issue branch` [create] <ISSUE_KEY> [opciones]  
`jira issue` <ISSUE_KEY> `--branch` [opciones]  

## DESCRIPCIÓN
Crea o renombra una rama Git local/remota normalizada a partir de los datos de un ticket de Jira (resumen, tipo y prioridad).

Calcula automáticamente el prefijo de la rama según la convención del equipo:
- `feature/` para Story, Feature, Improvement
- `bugfix/` para Bug, Defect con prioridad normal
- `hotfix/` para Incidentes, Bugs críticos o bloqueantes (P0/P1)
- `task/` para Task, Tarea, Sub-task
- `chore/` para Mantenimiento, Deuda técnica
- `spike/` para Spikes, Discovery

## OPCIONES
* `-N`, `--dry-run`:
  Solo imprime el nombre calculado de la rama sin crearla ni modificar el repositorio.
* `-Q`, `--quick`:
  Crea la rama inmediatamente sin ejecutar `git fetch` previo ni comprobaciones de árbol limpio.
* `-m`, `--rename`:
  Renombra la rama Git actual en lugar de crear una nueva rama.
* `-t`, `--summary` <texto>:
  Sobrescribe el título/resumen usado para generar el nombre de la rama.
* `--prefix` <prefijo>:
  Fuerza un prefijo específico (feature, bugfix, hotfix, chore, task, spike).
* `-F`, `--fresh`:
  Crea la rama a partir del HEAD remoto actualizado de la rama por defecto (`origin/main` u `origin/master`).
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Crear rama automática a partir del ticket
jira branch PROJ-123

# Crear rama explícita con prefijo forzado
jira issue branch create PROJ-123 --prefix hotfix

# Ver solo el nombre generado sin crear
jira branch PROJ-123 -N

# Renombrar rama actual
jira branch rename PROJ-123
```
