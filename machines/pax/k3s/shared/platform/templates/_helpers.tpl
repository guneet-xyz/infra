{{/*
Platform library chart — shared templates for single-service app deployments.

Dict-arg convention: (dict "app" .Values.apps.<name>)
Additional top-level keys for specific defines are noted below.

=== platform.deployment ===
Required:  app.appName, app.namespace, app.port, app.replicas,
           app.image, app.imageTag, app.resources.{requests.cpu,
           requests.memory, limits.memory}
Optional:  app.strategy ("RollingUpdate" default | "Recreate"),
            app.command (list; emitted as container command),
            app.args (list; emitted as container args),
            app.securityContext.{allowPrivilegeEscalation,readOnlyRootFilesystem,
              runAsNonRoot,runAsUser,runAsGroup,capabilities.drop},
            app.fsGroup, app.env [{name,value|valueFrom}],
            app.volumes [{name,mountPath,type:pvc|configMap|emptyDir,
              claimName?,configMapName?,readOnly?}],
            app.probes.readiness.{path,port,initialDelaySeconds,periodSeconds,
              failureThreshold},
            app.probes.liveness.{same; path falls back to readiness.path},
            app.resources.limits.cpu,
            checksums (top-level) {<suffix>: <pre-computed-sha256>}

Usage example (ntfy-like):
  Caller computes any per-ConfigMap sha256sum in its own template (using
  the standard Helm idiom that includes a sibling template and pipes it to
  sha256sum), then passes the map of "<suffix>: <hash>" pairs as
  "checksums". The library emits each as a checksum/<suffix> pod
  annotation.

    {{ include "platform.deployment" (dict
        "app" .Values.apps.ntfy
        "checksums" (dict "config" $configHash)
    ) }}

=== platform.service ===
Required: app.appName, app.namespace, app.port

=== platform.pvc ===
Required: app.namespace, app.appName, name (top-level), storage (top-level)
Usage: {{ include "platform.pvc" (dict "app" .Values.apps.ntfy "name" .Values.apps.ntfy.claims.cache "storage" .Values.apps.ntfy.storage.cache) }}

=== platform.networkpolicy.defaultDeny ===
Required: app.appName, app.namespace

=== platform.networkpolicy.allowFromCaddy ===
Required: app.appName, app.namespace, app.port, caddy (top-level) = .Values.apps.caddy
Usage: {{ include "platform.networkpolicy.allowFromCaddy" (dict "app" .Values.apps.ntfy "caddy" .Values.apps.caddy) }}

=== platform.networkpolicy.allowFromSameNamespace ===
Required: app.appName, app.namespace, app.port
*/}}

{{/*
=== platform.deployment — NEW optional keys in v0.2.0 ===
  app.serviceAccountName (string; emitted as pod spec serviceAccountName),
  app.initContainers (list; emitted as pod spec initContainers, full container spec),
  app.envFrom (list; [{secretRef: {name: ...}} | {configMapRef: {name: ...}}]),
  app.probes.readiness.type / app.probes.liveness.type ("httpGet" default | "tcpSocket"),
  volumes[*].subPath (string; emitted as volumeMounts subPath),
  volumes[*].type: "secret" → secretName, defaultMode (optional, K8s default 420)

=== platform.serviceaccount ===
Required: app.appName, app.namespace
Optional: app.serviceAccount.secrets (list of secret names to associate)

=== platform.rbac.clusterrole ===
Required: app.appName, rules (top-level list of RBAC rule objects)
Usage: {{ include "platform.rbac.clusterrole" (dict "app" .Values.apps.<name> "rules" .Values.apps.<name>.rbac.rules) }}

=== platform.rbac.clusterrolebinding ===
Required: app.appName, app.namespace
Binds a ClusterRole named app.appName to a ServiceAccount named app.appName in app.namespace

=== platform.cronjob ===
Required: app.appName, app.namespace, name (suffix string), schedule (cron expression),
          container (dict: image, imageTag, command?, args?, volumeMounts?)
Optional: concurrencyPolicy (default "Forbid"), successfulJobsHistoryLimit (default 3),
          failedJobsHistoryLimit (default 3), volumes (list of volume specs)
*/}}

{{- define "platform.deployment" -}}
{{- $strategy := default "RollingUpdate" .app.strategy -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .app.appName }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  replicas: {{ .app.replicas }}
  selector:
    matchLabels:
      app: {{ .app.appName }}
  strategy:
    type: {{ $strategy }}
    {{- if eq $strategy "RollingUpdate" }}
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
    {{- end }}
  template:
    metadata:
      labels:
        app: {{ .app.appName }}
      {{- if .checksums }}
      annotations:
        {{- range $suffix, $value := .checksums }}
        checksum/{{ $suffix }}: {{ $value }}
        {{- end }}
      {{- end }}
    spec:
      nodeSelector:
        role: primary
      {{- if .app.serviceAccountName }}
      serviceAccountName: {{ .app.serviceAccountName }}
      {{- end }}
      {{- if .app.fsGroup }}
      securityContext:
        fsGroup: {{ .app.fsGroup }}
      {{- end }}
      {{- if .app.initContainers }}
      initContainers:
        {{- toYaml .app.initContainers | nindent 8 }}
      {{- end }}
      containers:
         - name: {{ .app.appName }}
           image: {{ .app.image }}:{{ .app.imageTag }}
           {{- with .app.command }}
           command:
             {{- toYaml . | nindent 12 }}
           {{- end }}
           {{- with .app.args }}
           args:
             {{- toYaml . | nindent 12 }}
           {{- end }}
           securityContext:
            {{- if .app.securityContext }}
            {{- if hasKey .app.securityContext "allowPrivilegeEscalation" }}
            allowPrivilegeEscalation: {{ .app.securityContext.allowPrivilegeEscalation }}
            {{- end }}
            {{- if hasKey .app.securityContext "readOnlyRootFilesystem" }}
            readOnlyRootFilesystem: {{ .app.securityContext.readOnlyRootFilesystem }}
            {{- end }}
            {{- if hasKey .app.securityContext "runAsNonRoot" }}
            runAsNonRoot: {{ .app.securityContext.runAsNonRoot }}
            {{- end }}
            {{- if hasKey .app.securityContext "runAsUser" }}
            runAsUser: {{ .app.securityContext.runAsUser }}
            {{- end }}
            {{- if hasKey .app.securityContext "runAsGroup" }}
            runAsGroup: {{ .app.securityContext.runAsGroup }}
            {{- end }}
            {{- if .app.securityContext.capabilities }}
            capabilities:
              drop:
                {{- range .app.securityContext.capabilities.drop }}
                - {{ . }}
                {{- end }}
            {{- end }}
            {{- else }}
            allowPrivilegeEscalation: false
            {{- end }}
           resources:
             requests:
               cpu: {{ .app.resources.requests.cpu }}
               memory: {{ .app.resources.requests.memory }}
             limits:
               {{- if .app.resources.limits.cpu }}
               cpu: {{ .app.resources.limits.cpu }}
               {{- end }}
               memory: {{ .app.resources.limits.memory }}
           ports:
             - containerPort: {{ .app.port }}
               protocol: TCP
           {{- if .app.env }}
           env:
             {{- toYaml .app.env | nindent 12 }}
           {{- end }}
           {{- if .app.envFrom }}
           envFrom:
             {{- toYaml .app.envFrom | nindent 12 }}
           {{- end }}
           {{- with .app.probes }}
           {{- if .readiness }}
           readinessProbe:
             {{- if eq (default "httpGet" .readiness.type) "tcpSocket" }}
             tcpSocket:
               port: {{ default $.app.port .readiness.port }}
             {{- else }}
             httpGet:
               path: {{ .readiness.path }}
               port: {{ default $.app.port .readiness.port }}
             {{- end }}
             initialDelaySeconds: {{ default 5 .readiness.initialDelaySeconds }}
             periodSeconds: {{ default 5 .readiness.periodSeconds }}
             failureThreshold: {{ default 3 .readiness.failureThreshold }}
           {{- end }}
           {{- if .liveness }}
           livenessProbe:
             {{- if eq (default "httpGet" .liveness.type) "tcpSocket" }}
             tcpSocket:
               port: {{ default $.app.port .liveness.port }}
             {{- else }}
             httpGet:
               path: {{ default .readiness.path .liveness.path }}
               port: {{ default $.app.port .liveness.port }}
             {{- end }}
             initialDelaySeconds: {{ default 15 .liveness.initialDelaySeconds }}
             periodSeconds: {{ default 10 .liveness.periodSeconds }}
             failureThreshold: {{ default 3 .liveness.failureThreshold }}
           {{- end }}
           {{- end }}
           {{- if .app.volumes }}
           volumeMounts:
             {{- range .app.volumes }}
             - name: {{ .name }}
               mountPath: {{ .mountPath }}
               {{- if .subPath }}
               subPath: {{ .subPath }}
               {{- end }}
               {{- if .readOnly }}
               readOnly: true
               {{- end }}
             {{- end }}
           {{- end }}
      {{- if .app.volumes }}
      volumes:
        {{- range .app.volumes }}
        - name: {{ .name }}
          {{- if eq .type "pvc" }}
          persistentVolumeClaim:
            claimName: {{ .claimName }}
          {{- else if eq .type "configMap" }}
          configMap:
            name: {{ .configMapName }}
          {{- else if eq .type "emptyDir" }}
          emptyDir: {}
          {{- else if eq .type "secret" }}
          secret:
            secretName: {{ .secretName }}
            {{- if .defaultMode }}
            defaultMode: {{ .defaultMode }}
            {{- end }}
          {{- end }}
        {{- end }}
      {{- end }}
{{- end -}}

{{- define "platform.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .app.appName }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  type: ClusterIP
  ports:
    - name: http
      port: {{ .app.port }}
      targetPort: {{ .app.port }}
  selector:
    app: {{ .app.appName }}
{{- end -}}

{{- define "platform.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .name }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .storage }}
{{- end -}}

{{- define "platform.networkpolicy.defaultDeny" -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
{{- end -}}

{{- define "platform.networkpolicy.allowFromCaddy" -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-caddy
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  podSelector:
    matchLabels:
      app: {{ .app.appName }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .caddy.namespace }}
      ports:
        - port: {{ .app.port }}
          protocol: TCP
{{- end -}}

{{- define "platform.networkpolicy.allowFromSameNamespace" -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-same-namespace
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  podSelector:
    matchLabels:
      app: {{ .app.appName }}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
      ports:
        - port: {{ .app.port }}
          protocol: TCP
{{- end -}}

{{- define "platform.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .app.appName }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
{{- if .app.serviceAccount }}
{{- if .app.serviceAccount.secrets }}
secrets:
  {{- range .app.serviceAccount.secrets }}
  - name: {{ . }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "platform.rbac.clusterrole" -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ .app.appName }}
  labels:
    app: {{ .app.appName }}
rules:
  {{- toYaml .rules | nindent 2 }}
{{- end -}}

{{- define "platform.rbac.clusterrolebinding" -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .app.appName }}
  labels:
    app: {{ .app.appName }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ .app.appName }}
subjects:
  - kind: ServiceAccount
    name: {{ .app.appName }}
    namespace: {{ .app.namespace }}
{{- end -}}

{{- define "platform.cronjob" -}}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ .app.appName }}-{{ .name }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.appName }}
spec:
  schedule: {{ .schedule | quote }}
  concurrencyPolicy: {{ default "Forbid" .concurrencyPolicy }}
  successfulJobsHistoryLimit: {{ default 3 .successfulJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ default 3 .failedJobsHistoryLimit }}
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            role: primary
          restartPolicy: OnFailure
          containers:
            - name: {{ .name }}
              image: {{ .container.image }}:{{ .container.imageTag }}
              {{- with .container.command }}
              command:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- with .container.args }}
              args:
                {{- toYaml . | nindent 16 }}
              {{- end }}
              {{- with .container.volumeMounts }}
              volumeMounts:
                {{- toYaml . | nindent 16 }}
              {{- end }}
          {{- with .volumes }}
          volumes:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end -}}
