{{/*
ServiceAccount name helper
*/}}
{{- define "customer-management-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default "aws-secrets-sa" .Values.serviceAccount.name -}}
{{- else -}}
    {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
