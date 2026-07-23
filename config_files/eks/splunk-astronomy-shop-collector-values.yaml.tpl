# =============================================================================
# Splunk OTel Collector — Astronomy Shop demo Helm values overlay
# =============================================================================
# Apply AFTER splunk-otel-collector-values.yaml (this file overrides duplicate keys):
#   helm install|upgrade ... \
#     -f splunk-otel-collector-values.yaml \
#     -f splunk-astronomy-shop-collector-values.yaml
#
# Related manifests (not Helm values):
#   splunk-astronomy-shop.yaml     — shop Deployments/Services (kubectl apply)
#   secrets.yaml                   — workshop-secret (realm, tokens, instance)
#   log-generator.yaml             — test workload; logs hit agents on each node
#
# Adds:
#   - clusterReceiver: k8s object watches, SQL DBMON (shopshim + fraud)
#   - agent: receiver_creator (mysql, redis), flagd trace drops
#
# k8s events: enabled via helm --set splunkObservability.infrastructureMonitoringEventsEnabled=true
# Gateway forwarding: clusterReceiver must define otlp_grpc when overriding config.exporters
# (empty exporters would wipe chart defaults via mustMergeOverwrite).
# =============================================================================

# Cluster receiver: single-replica Deployment — persistent queue not supported
# by the chart (pod may reschedule to a different node; hostPath would not follow).
clusterReceiver:
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
        events: &sqlserver_dbmon_events
          db.server.query_sample:
            enabled: true
          db.server.top_query:
            enabled: true
        metrics: &sqlserver_dbmon_metrics
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
          sqlserver.instance.name:
            enabled: true
        events: *sqlserver_dbmon_events
        metrics: *sqlserver_dbmon_metrics
    exporters:
%{ if gateway_enabled ~}
      # Forward cluster receiver telemetry to the gateway Deployment.
      # Do not leave exporters empty here — mustMergeOverwrite would wipe chart defaults
      # (signalfx, splunk_hec, etc.) and break k8s events/object pipelines.
      otlp_grpc:
        endpoint: splunk-otel-collector:4317
        tls:
          insecure: true
%{ else ~}
      # Direct DBMON log export when gateway is disabled.
      otlp_http/dbmon:
        headers:
          X-SF-Token: ${eks_access_token}
          X-splunk-instrumentation-library: dbmon
        logs_endpoint: https://ingest.${realm}.signalfx.com/v3/event
        sending_queue:
          batch:
            flush_timeout: 15s
            max_size: 10485760 # 10 MiB
            sizer: bytes
%{ endif ~}
    processors:
      resource/add_collector_k8s:
        attributes:
          - action: insert
            key: k8s.node.name
            value: $${K8S_NODE_NAME}
          - action: insert
            key: k8s.pod.name
            value: $${K8S_POD_NAME}
          - action: insert
            key: k8s.pod.uid
            value: $${K8S_POD_UID}
          - action: insert
            key: k8s.namespace.name
            value: $${K8S_NAMESPACE}
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
          exporters:
%{ if gateway_enabled ~}
            - otlp_grpc
%{ else ~}
            - signalfx
%{ endif ~}
          # Omit resourcedetection — cluster receiver is not node-local; avoids misleading host.name.
          processors: [memory_limiter, batch, resource, resource/k8s_cluster, resource/add_collector_k8s, transform/dbmon]
          receivers: [k8s_cluster, sqlserver/fraud, sqlserver/shopshim]
        logs/dbmon:
          receivers:
            - sqlserver/fraud
            - sqlserver/shopshim
          processors:
            - memory_limiter
            - batch
            - resource
            - resource/add_collector_k8s
            - transform/dbmon
          exporters:
%{ if gateway_enabled ~}
            - otlp_grpc
%{ else ~}
            - otlp_http/dbmon
%{ endif ~}

# Agent overlays — replaces base agent metrics/traces pipelines (Helm fully redefines lists).
agent:
  config:
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
          exporters:
%{ if gateway_enabled ~}
            - otlp_grpc
            - signalfx/host_metadata
%{ else ~}
            - signalfx
%{ endif ~}
          processors: [memory_limiter, k8s_attributes, batch, resourcedetection, resource]
          receivers: [host_metrics, kubeletstats, otlp, receiver_creator]
        traces:
          exporters:
%{ if gateway_enabled ~}
            - otlp_grpc
%{ else ~}
            - signalfx
            - otlp_http
%{ endif ~}
          processors: [memory_limiter, filter/drop_flagd, k8s_attributes, batch, resourcedetection, resource, resource/add_environment]
          receivers: [otlp, jaeger, zipkin]
