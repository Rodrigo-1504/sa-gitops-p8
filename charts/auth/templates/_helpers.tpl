{{/*
  _helpers.tpl — Funciones reutilizables del chart sa-platform
  Todos los templates definidos aquí pueden llamarse desde cualquier
  subchart o template del chart padre con: {{ include "sa-platform.xxx" . }}
*/}}


{{/* ═══════════════════════════════════════════════════════════════
     1. NOMBRE COMPLETO DEL RELEASE
     Uso de: default, trunc, trimSuffix
     Genera: "<release-name>-<chart-name>" (máx. 63 chars, límite de DNS)
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
  {{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     2. NOMBRE BASE DEL CHART
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     3. LABELS COMUNES (se pegan en metadata.labels de todos los recursos)
     Uso de: if, quote
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     4. SELECTOR LABELS (usados en spec.selector y spec.template.metadata.labels)
     Recibe un dict con "service" (nombre del microservicio) y "root" (contexto raíz)
     Ejemplo de llamada:
       {{ include "sa-platform.selectorLabels" (dict "service" "auth" "root" .) }}
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ .service | quote }}
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
app: {{ .service | quote }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     5. IMAGEN COMPLETA DE UN MICROSERVICIO
     Uso de: required, default, if/else
     - required: falla con mensaje claro si el valor es obligatorio y está vacío
     - default: pone un tag por defecto si no se especifica
     Recibe un dict con "image" (bloque .Values.image del subchart) y "root"
     Ejemplo:
       image: {{ include "sa-platform.image" (dict "image" .Values.image "root" .) }}
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.image" -}}
{{- $repo := required "image.repository es requerido para cada microservicio" .image.repository -}}
{{- $tag  := default "latest" .image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     6. NOMBRE DEL SERVICE ACCOUNT DE UN MICROSERVICIO
     Retorna el nombre del SA dedicado (nunca usa "default")
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.serviceAccountName" -}}
{{- printf "sa-%s" .service -}}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     7. VARIABLES DE ENTORNO DESDE CONFIGMAP (range)
     Itera sobre el mapa .Values.extraEnv de un subchart y genera
     entradas env: para el container. Uso de: range, if/else
     Ejemplo en values.yaml del subchart:
       extraEnv:
         LOG_LEVEL: "info"
         NODE_ENV: "production"
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.extraEnvVars" -}}
{{- if .extraEnv }}
{{- range $key, $value := .extraEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     8. ANOTACIÓN CHECKSUM PARA REINICIO AUTOMÁTICO AL CAMBIAR CONFIGMAP
     Agrega un hash del ConfigMap como anotación al pod.
     Cuando el ConfigMap cambia, el hash cambia → Kubernetes recrea el pod.
     Uso: en spec.template.metadata.annotations de cada Deployment
       annotations:
         {{- include "sa-platform.configmapChecksum" (dict "configmapName" "auth-config" "root" .) | nindent 8 }}
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.configmapChecksum" -}}
checksum/config: {{ include (print .root.Template.BasePath "/" .configmapName ".yaml") .root | sha256sum }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     9. RECURSOS DE CPU/MEMORIA (default + if/else para límites opcionales)
     Genera el bloque resources: de un container.
     Si el usuario no pone limits en values, solo pone requests.
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.resources" -}}
{{- $res := . -}}
requests:
  cpu: {{ default "100m" $res.requests.cpu | quote }}
  memory: {{ default "128Mi" $res.requests.memory | quote }}
{{- if $res.limits }}
limits:
  cpu: {{ $res.limits.cpu | quote }}
  memory: {{ $res.limits.memory | quote }}
{{- end }}
{{- end }}


{{/* ═══════════════════════════════════════════════════════════════
     10. SECURITY CONTEXT ESTÁNDAR (igual para todos los containers)
     runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation: false
     — requisito G de la práctica
     ═══════════════════════════════════════════════════════════════ */}}
{{- define "sa-platform.securityContext" -}}
runAsNonRoot: true
runAsUser: 1001
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}