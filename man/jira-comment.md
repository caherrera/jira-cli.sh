# jira-comment(1) -- Gestión integral de comentarios en Jira

## SINTAXIS
`jira comment` [list] <ISSUE_KEY> [opciones]  
`jira comment` <ISSUE_KEY> ["mensaje"] [opciones]  
`jira comment add` <ISSUE_KEY> ["mensaje"] [opciones]  
`jira comment edit` <ISSUE_KEY> <COMMENT_ID> ["mensaje"] [opciones]  
`jira comment delete` <ISSUE_KEY> <COMMENT_ID>  
`jira issue comment` ...  
`jira issue` <ISSUE_KEY> `-m` "mensaje"  

## DESCRIPCIÓN
Permite listar, publicar, editar y eliminar comentarios en issues de Jira.

En Jira Cloud (API v3), convierte automáticamente el texto en formato Markdown (bloques de código, listas, negritas, enlaces) a formato Atlassian Document Format (ADF) para una visualización enriquecida en la interfaz web de Jira.

## OPCIONES
* `-m`, `--message` <texto>:
  Texto del comentario. Soporta `@archivo.md` para leer desde archivo o `-` para leer desde stdin / pipes.
* `--output` <formato>:
  Formato de salida para listado: `json`, `table`, `md`.
* `--dry-run`:
  Imprime el payload generado sin enviar la petición a la API.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Listar comentarios de un issue
jira comment list PROJ-123
jira issue comments PROJ-123 --output md

# Agregar un comentario directo
jira comment PROJ-123 "Implementación completada con éxito."
jira issue PROJ-123 -m "Revisión lista para QA."

# Agregar comentario con Markdown desde archivo
jira comment PROJ-123 -m @evidencias.md

# Agregar comentario desde un pipe
cat logs.txt | jira comment PROJ-123 -m -

# Editar un comentario existente
jira comment edit PROJ-123 10052 -m "Comentario actualizado."

# Eliminar un comentario
jira comment delete PROJ-123 10052
```
