# jira-link(1) -- Enlaces entre issues y URLs externas

## SINTAXIS
`jira link` <INWARD_KEY> <OUTWARD_KEY> [opciones]  
`jira link-url` <ISSUE_KEY> <URL> [opciones]  
`jira link-url delete` <ISSUE_KEY> <REMOTE_LINK_ID>  
`jira issue link` <INWARD_KEY> <OUTWARD_KEY>  
`jira issue link-url` <ISSUE_KEY> <URL>  

## DESCRIPCIÓN
Permite vincular tickets de Jira entre sí (Relates, Blocks, Clones, etc.) y enlazar URLs externas (GitLab Merge Requests, GitHub Pull Requests, Confluence, Figma, Docs).

## OPCIONES
* `--type` <nombre>:
  Tipo de enlace entre issues (por defecto: `Relates`). Ej: `Blocks`, `Cloners`, `Duplicate`.
* `--title` <texto>:
  Título descriptivo para el enlace web externo (ej: "GitLab MR !145").
* `--summary` <texto>:
  Descripción o resumen adicional para el enlace web.
* `--relationship` <relación>:
  Tipo de relación externa (por defecto: `relates to`).
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Enlazar dos tickets de Jira
jira link PROJ-123 PROJ-456
jira link PROJ-123 PROJ-789 --type Blocks

# Enlazar un Merge Request de GitLab al ticket
jira link-url PROJ-123 https://gitlab.com/org/repo/-/merge_requests/45 --title "GitLab MR !45"
jira issue PROJ-123 --link-url https://gitlab.com/org/repo/-/merge_requests/45 --title "GitLab MR !45"

# Listar enlaces remotos del ticket
jira issue remote-links PROJ-123

# Eliminar un enlace web
jira link-url delete PROJ-123 10023
```
