{{/*
Postgres library chart — shared templates for PostgreSQL sidecar deployments.

All templates accept a dict with:
  - "app"       : the values dict (e.g. .Values.apps.litellm)
  - "Release"   : the Release object

The calling chart is responsible for passing the correct app values.

Usage example (in litellm/templates/postgres-deployment.yaml):
  {{ include "postgres.deployment" (dict "app" .Values.apps.litellm "Release" .Release) }}
*/}}

{{- define "postgres.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .app.postgres.serviceName }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.postgres.serviceName }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .app.postgres.serviceName }}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: {{ .app.postgres.serviceName }}
    spec:
      nodeSelector:
        role: primary
      containers:
        - name: postgres
          image: {{ .app.images.postgres.image }}:{{ .app.images.postgres.imageTag }}
          ports:
            - containerPort: {{ .app.postgres.port }}
              protocol: TCP
          envFrom:
            - secretRef:
                name: postgres-secret
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          securityContext:
            allowPrivilegeEscalation: false
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              memory: 512Mi
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - {{ .app.postgres.dbUser }}
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - {{ .app.postgres.dbUser }}
            initialDelaySeconds: 15
            periodSeconds: 10
          volumeMounts:
            - mountPath: /var/lib/postgresql/data
              name: {{ .app.claims.postgresData }}
      volumes:
        - name: {{ .app.claims.postgresData }}
          persistentVolumeClaim:
            claimName: {{ .app.claims.postgresData }}
{{- end -}}

{{- define "postgres.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .app.postgres.serviceName }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.postgres.serviceName }}
spec:
  ports:
    - name: postgres
      port: {{ .app.postgres.port }}
      targetPort: {{ .app.postgres.port }}
  selector:
    app: {{ .app.postgres.serviceName }}
{{- end -}}

{{- define "postgres.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.postgres.serviceName }}
type: Opaque
stringData:
  POSTGRES_USER: {{ .app.postgres.dbUser }}
  POSTGRES_PASSWORD: {{ .app.postgres.dbPassword }}
  POSTGRES_DB: {{ .app.postgres.dbName }}
{{- end -}}

{{- define "postgres.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .app.claims.postgresData }}
  namespace: {{ .app.namespace }}
  labels:
    app: {{ .app.postgres.serviceName }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .app.postgres.storage }}
{{- end -}}
