{{- define "yas.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "yas.serviceName" -}}
{{- printf "%s-%s" .Release.Name .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

