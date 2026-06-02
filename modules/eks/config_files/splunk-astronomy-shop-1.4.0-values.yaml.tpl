# =============================================================================
# Persistent export queues (agent DaemonSet only)
# =============================================================================
# Queues are written to disk on each node (hostPath) so agent pod restarts on
# the same node do not drop unsent data. Requires splunkPlatform endpoint when
# using HEC; O11y exporters below reuse the same file_storage extension.
#
# PROTECTED on agent restart (splunk-otel-collector-agent):
#   - Container/pod logs        -> Splunk Platform (HEC)     [platform_logs]
#   - Host/node metrics         -> Splunk Observability      [signalfx]
#   - App OTLP metrics          -> Splunk Observability      [signalfx]
#   - App traces                -> Splunk Observability      [otlp_http, signalfx]
#   - Secure app logs           -> Splunk Observability      [otlp_http/secureapp]
#   - Discovery/receiver_creator metrics -> O11y               [signalfx]
#
# NOT protected (cluster receiver Deployment — in-memory queues only):
#   - Kubernetes cluster metrics (k8s_cluster receiver)     -> O11y [signalfx]
#   - Kubernetes events (eventsEnabled)                       -> HEC / O11y
#   - Kubernetes object watch logs (k8sObjects pods/events)   -> HEC / O11y
#   - SQL Server DB metrics (sqlserver/* receivers)           -> O11y [signalfx]
#   - SQL Server DBMON events (logs/dbmon pipeline)         -> O11y [otlp_http/dbmon]
#   On force restart: unsent queue data is lost AND there is a collection gap
#   (missed events/scrapes are not backfilled). Container logs on nodes are
#   unaffected — those are collected by the agent DaemonSet, not here.
#
# Demo tip: log-generator / HEC log tests use agents. Restarting the cluster
# receiver does not simulate container log loss; restarting agents does.
# =============================================================================
splunkPlatform:
  sendingQueue:
    queueSize: 5000
    persistentQueue:
      enabled: true
      storagePath: "/var/addon/splunk/exporter_queue"

# Cluster receiver: single-replica Deployment — persistent queue not supported
# by the chart (pod may reschedule to a different node; hostPath would not follow).
# See header comment for data at risk if this pod is force restarted.
clusterReceiver:
  extraEnvs:
  - name: WORKSHOP_REALM
    valueFrom:
      secretKeyRef:
        name: workshop-secret
        key: realm
  eventsEnabled: true
  k8sObjects:
    - name: events
      mode: watch
      namespaces: [default, splunk]
    - name: pods
      mode: watch
      namespaces: [default, splunk]
  config:
    receivers:
      sqlserver/shopshim:
        collection_interval: 10s
        top_query_collection:
          lookback_time: 300s
        username: sa
        password: ShopPass123!
        server: shop-dc-shim-db
        port: 1433
        resource_attributes:
          sqlserver.instance.name:
            enabled: true
        events:
          db.server.query_sample:
            enabled: true
          db.server.top_query:
            enabled: true
        metrics:
          sqlserver.batch.request.rate:
              enabled: true
          sqlserver.batch.sql_compilation.rate:
              enabled: true
          sqlserver.batch.sql_recompilation.rate:
              enabled: true
          sqlserver.database.count:
              enabled: true
          sqlserver.database.io:
              enabled: true
          sqlserver.database.latency:
              enabled: true
          sqlserver.database.operations:
              enabled: true
          sqlserver.deadlock.rate:
              enabled: true
          sqlserver.lock.wait.count:
              enabled: true
          sqlserver.lock.wait.rate:
              enabled: true
          sqlserver.os.wait.duration:
              enabled: true
          sqlserver.page.buffer_cache.hit_ratio:
              enabled: true
          sqlserver.processes.blocked:
              enabled: true
          sqlserver.resource_pool.disk.operations:
              enabled: true
          sqlserver.resource_pool.disk.throttled.read.rate:
              enabled: true
          sqlserver.resource_pool.disk.throttled.write.rate:
              enabled: true
          sqlserver.user.connection.count:
              enabled: true
      sqlserver/fraud:
        collection_interval: 10s
        top_query_collection:
          lookback_time: 120s
        username: sa
        password: "ChangeMe_SuperStrong123!"
        server: sql-server-fraud.default.svc.cluster.local
        port: 1433
        resource_attributes:
          # sqlserver.computer.name:
          #   enabled: true
          sqlserver.instance.name:
            enabled: true
        # ADD to ENABLE Database Monitoring
        events:
          db.server.query_sample:
            enabled: true
          db.server.top_query:
            enabled: true 
        metrics:
          sqlserver.batch.request.rate:
              enabled: true
          sqlserver.batch.sql_compilation.rate:
              enabled: true
          sqlserver.batch.sql_recompilation.rate:
              enabled: true
          sqlserver.database.count:
              enabled: true
          sqlserver.database.io:
              enabled: true
          sqlserver.database.latency:
              enabled: true
          sqlserver.database.operations:
              enabled: true
          sqlserver.deadlock.rate:
              enabled: true
          sqlserver.lock.wait.count:
              enabled: true
          sqlserver.lock.wait.rate:
              enabled: true
          sqlserver.os.wait.duration:
              enabled: true
          sqlserver.page.buffer_cache.hit_ratio:
              enabled: true
          sqlserver.processes.blocked:
              enabled: true
          sqlserver.resource_pool.disk.operations:
              enabled: true
          sqlserver.resource_pool.disk.throttled.read.rate:
              enabled: true
          sqlserver.resource_pool.disk.throttled.write.rate:
              enabled: true
          sqlserver.user.connection.count:
              enabled: true
          sqlserver.database.latency:
            enabled: true  
    exporters:
      # NOT disk-backed — cluster receiver queues are in-memory only.
      otlp_http/dbmon:
        headers:
          X-SF-Token: ${eks_access_token} # GH Modified
          X-splunk-instrumentation-library: dbmon
        logs_endpoint: https://ingest.${realm}.signalfx.com/v3/event # GH Modified
        sending_queue:
          batch:
            flush_timeout: 15s
            max_size: 10485760 # 10 MiB
            sizer: bytes 
    processors:
      transform/dbmon:
        error_mode: ignore
        metric_statements:
          - conditions:
              - resource.attributes["sqlserver.instance.name"] != nil
              - resource.attributes["k8s.pod.name"] != nil
            statements:
              - set(resource.attributes["service.instance.id"], Concat([resource.attributes["k8s.pod.name"], " - ", resource.attributes["sqlserver.instance.name"]], ""))
        log_statements:
          - conditions:
              - resource.attributes["sqlserver.instance.name"] != nil
              - resource.attributes["k8s.pod.name"] != nil
            statements:
              - set(resource.attributes["service.instance.id"], Concat([resource.attributes["k8s.pod.name"], " - ", resource.attributes["sqlserver.instance.name"]], ""))
    service:
      pipelines:
        metrics:
          exporters: [signalfx]
          processors: [memory_limiter, batch, resourcedetection, resource, resource/k8s_cluster, resource/add_collector_k8s, transform/dbmon]
          receivers: [k8s_cluster, sqlserver/fraud, sqlserver/shopshim]
        logs/dbmon:
          receivers:
            - sqlserver/fraud
            - sqlserver/shopshim
          processors:
            - memory_limiter
            - batch
            - resourcedetection
            - resource
            - resource/add_collector_k8s
            - transform/dbmon
          exporters:
            - otlp_http/dbmon
agent:
  # 1Gi recommended by Splunk chart when persistentQueue is enabled.
  resources:
    limits:
      memory: 1Gi
  extraEnvs:
  - name: WORKSHOP_ENVIRONMENT
    valueFrom:
      secretKeyRef:
        name: workshop-secret
        key: instance
  config:
    exporters:
      # Disk-backed sending queues for agent export paths (see header comment).
      signalfx:
        sending_queue:
          storage: file_storage/persistent_queue
      otlp_http:
        sending_queue:
          storage: file_storage/persistent_queue
      otlp_http/secureapp:
        sending_queue:
          storage: file_storage/persistent_queue
    receivers:
      receiver_creator:
        receivers:
          mysql/online-boutique:
            rule: type == "port" && pod.name matches "mysql" && port == 3306
            config:
              tls:
                insecure: true
              username: root
              password: root
              database: LxvGChW075
          redis:
           rule: type == "port" && pod.name matches "redis-cart" && port == 6379
           config:
             endpoint: "redis-cart:6379"
             collection_interval: 10s
    processors:
      filter/drop_flagd:
        traces:
          span:
          - attributes["rpc.method"] == "EventStream"
          - attributes["rpc.method"] == "ResolveAll"
          - attributes["rpc.method"] == "ResolveBoolean"
          - attributes["rpc.method"] == "ResolveFloat"
          - attributes["rpc.method"] == "ResolveInt"
          - attributes["http.url"] == "http://flagd:8016/ofrep/v1/evaluate/flags/loadGeneratorFloodHomepage"
          - attributes["url.full"] == "http://flagd:8013/flagd.evaluation.v1.Service/ResolveBoolean"
          - attributes["otel.scope.name"] == "flagd.evaluation.v1"
          - attributes["url.full"] == "http://flagd:8013/flagd.evaluation.v1.Service/EventStream"

    service:
      pipelines:
        metrics:
          exporters: [signalfx]
          processors: [memory_limiter, k8s_attributes, batch, resourcedetection, resource]
          receivers: [host_metrics, kubeletstats, otlp, receiver_creator]
        traces:
          exporters: [signalfx, otlp_http]
          processors: [memory_limiter,  filter/drop_flagd, k8s_attributes, batch, resourcedetection, resource, resource/add_environment]
          receivers: [otlp, jaeger, zipkin]

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