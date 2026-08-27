# jira-attach(1) -- Gestión de archivos adjuntos y evidencias

## SINTAXIS
`jira attach` <ISSUE_KEY> <archivo1> [archivo2...]  
`jira attach list` <ISSUE_KEY> [opciones]  
`jira attach download` <ATTACHMENT_ID> [-o <destino>]  
`jira issue attach` ...  
`jira issue attachments` <ISSUE_KEY>  
`jira issue` <ISSUE_KEY> `--attach` <archivo>  

## DESCRIPCIÓN
Sube, lista y descarga archivos adjuntos en tickets de Jira.

Maneja automáticamente las cabeceras de seguridad requeridas por Jira Cloud (`X-Atlassian-Token: no-check`) y la codificación multipart.

## OPCIONES
* `-o`, `--output-file` <ruta>:
  Ruta de destino para guardar el archivo descargado.
* `--output` <formato>:
  Formato de salida para listado: `json`, `table`, `md`.
* `--dry-run`:
  Simula la subida sin transferir datos.
* `-h`, `--help`:
  Muestra esta ayuda.

## EJEMPLOS
```bash
# Subir uno o varios archivos como evidencias
jira attach PROJ-123 evidencia.png logs.txt
jira issue PROJ-123 --attach plan.pdf

# Listar adjuntos del issue
jira attach list PROJ-123
jira issue attachments PROJ-123 --output table

# Descargar un archivo adjunto por su ID
jira attach download 10450 -o ./descargas/evidencia.png
```
