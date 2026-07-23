# =============================================================================
# Splunk OTel Collector — base Helm values (platform, gateway, agent core)
# =============================================================================
# Deploy with Astronomy Shop overlay (second file wins on duplicate keys):
#   helm install|upgrade ... \
#     -f splunk-otel-collector-values.yaml \
#     -f splunk-astronomy-shop-collector-values.yaml
#
# Additional settings via vm_eks_admin_server.tf --set:
#   splunkPlatform.endpoint (HTTPS HEC), token, index, insecureSkipVerify
#   splunkObservability.*, gateway.enabled, clusterName, environment
#
# Terraform vars (modules/eks + root):
#   eks_otel_gateway_enabled, eks_otel_gateway_replica_count,
#   eks_otel_gateway_*_request/limit (gateway pod resources),
#   eks_node_group_desired_size, eks_node_group_min_size, eks_node_group_max_size
#
# Gateway sizing: chart defaults (8Gi/4 CPU) need large nodes.
# Demo t3.large/t3.xlarge: use 2Gi–4Gi limits via eks_otel_gateway_memory_limit.
# =============================================================================
# Telemetry resilience (production-style when gateway_enabled = true)
# =============================================================================
# Agent (DaemonSet):
#   - Disk-backed queue on each node (persistentQueue) buffers agent -> gateway
#     or agent -> backend when gateway is disabled.
#   - Container logs, node metrics, app OTLP: collected on every node.
#   - Astronomy Shop adds receiver_creator + flagd filters (see shop values file).
#
# Gateway (Deployment, replica_count from Terraform):
#   - Multi-replica HA pool; agents forward via otlp_grpc when gateway enabled.
#   - Export queues are in-memory; rolling restart drains one pod at a time.
#   - If all gateways are down, agent disk queues hold data on every node.
#   - Graceful restart: kubectl rollout restart deployment/splunk-otel-collector
#   - Force kill: kubectl delete pod ... --force --grace-period=0
#
# Cluster receiver (in astronomy-shop values file):
#   - NOT disk-backed; forwards via otlp_grpc when gateway enabled.
#   - K8s events/object watches and SQL DBMON may gap on restart.
#
# PROTECTED on agent restart (splunk-otel-collector-agent) when persistentQueue on:
#   - Container/pod logs        -> Splunk Platform (HEC)     [via gateway or direct]
#   - Host/node metrics         -> Splunk Observability      [signalfx / otlp_grpc]
#   - App OTLP metrics          -> Splunk Observability
#   - App traces                -> Splunk Observability      [otlp_http, signalfx]
#   - Secure app logs           -> Splunk Observability      [when gateway disabled]
#
# NOT protected on cluster receiver restart (in-memory queues only):
#   - K8s cluster metrics, events, object watches, SQL Server DBMON pipelines
# =============================================================================

# Persistent export queues (agent DaemonSet). Chart enables file_storage when
# splunkPlatform.sendingQueue.persistentQueue.enabled is true.
splunkPlatform:
  sendingQueue:
    queueSize: 10000
    numConsumers: 10
    persistentQueue:
      enabled: true
      storagePath: "/var/addon/splunk/exporter_queue"

%{ if gateway_enabled ~}
# Gateway enabled — agents/cluster receiver use otlp_grpc; gateway exports to HEC/O11y.
# Gateway export queues below are in-memory (not disk-backed per replica).
gateway:
  enabled: true
  replicaCount: ${gateway_replica_count}
  terminationGracePeriodSeconds: 600
  resources:
    requests:
      cpu: ${gateway_cpu_request}
      memory: ${gateway_memory_request}
    limits:
      cpu: ${gateway_cpu_limit}
      memory: ${gateway_memory_limit}
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: splunk-otel-collector
                component: otel-collector
            topologyKey: kubernetes.io/hostname
  config:
    exporters:
%{ if splunk_platform_enabled ~}
      # Requires splunkPlatform.endpoint from helm --set (enterprise deploy only).
      splunk_hec/platform_logs:
        sending_queue:
          enabled: true
          queue_size: 10000
          num_consumers: 10
        retry_on_failure:
          enabled: true
          max_elapsed_time: 0
%{ endif ~}
      signalfx:
        sending_queue:
          enabled: true
          queue_size: 10000
        retry_on_failure:
          enabled: true
          max_elapsed_time: 0
      otlp_http:
        sending_queue:
          enabled: true
          queue_size: 10000
        retry_on_failure:
          enabled: true
          max_elapsed_time: 0
%{ endif ~}

agent:
  # 1Gi minimum with persistentQueue; 2Gi when gateway enabled (high trace volume from astro shop).
  resources:
    limits:
%{ if gateway_enabled ~}
      memory: 2Gi
%{ else ~}
      memory: 1Gi
%{ endif ~}
%{ if !splunk_platform_enabled ~}
  # Chart only mounts the persistent-queue hostPath when Splunk Platform logs are enabled
  # (splunkPlatform.endpoint set). Without this, file_storage/persistent_queue has no backing path.
  # hostPath dirs are root-owned; the chart chown initContainer runs only when logs are enabled.
  securityContext:
    runAsUser: 0
  extraVolumes:
    - name: persistent-queue
      hostPath:
        path: "/var/addon/splunk/exporter_queue/agent"
        type: DirectoryOrCreate
  extraVolumeMounts:
    - name: persistent-queue
      mountPath: "/var/addon/splunk/exporter_queue/agent"
%{ endif ~}
  config:
    extensions:
      file_storage/persistent_queue:
        create_directory: true
    exporters:
%{ if gateway_enabled ~}
      # Disk-backed queue for agent -> gateway hop (production resilience).
      otlp_grpc:
        sending_queue:
          enabled: true
          storage: file_storage/persistent_queue
          queue_size: 50000
          num_consumers: 10
        retry_on_failure:
          enabled: true
          max_elapsed_time: 0
        timeout: 30s
%{ else ~}
      # Direct export with disk-backed queues when gateway is disabled.
      signalfx:
        sending_queue:
          storage: file_storage/persistent_queue
      otlp_http:
        sending_queue:
          storage: file_storage/persistent_queue
      otlp_http/secureapp:
        sending_queue:
          storage: file_storage/persistent_queue
%{ endif ~}
    # Agent metrics/traces pipelines: defined in splunk-astronomy-shop-collector-values.yaml
    # (Helm fully replaces service.pipelines lists; shop overlay adds receiver_creator + flagd filter).

# Optional host log collection (uncomment to enable on all agents).
# logsCollection:
#   extraFileLogs:
#     filelog/syslog:
#       include: [/var/log/syslog]
#       include_file_path: true
#       include_file_name: false
#       resource:
#         com.splunk.source: /var/log/syslog
#         host.name: 'EXPR(env("K8S_NODE_NAME"))'
#         com.splunk.sourcetype: syslog
#     filelog/auth_log:
#       include: [/var/log/auth.log]
#       include_file_path: true
#       include_file_name: false
#       resource:
#         com.splunk.source: /var/log/auth.log
#         host.name: 'EXPR(env("K8S_NODE_NAME"))'
#         com.splunk.sourcetype: auth_log


