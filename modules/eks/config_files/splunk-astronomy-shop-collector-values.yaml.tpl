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
#   - clusterReceiver: k8s events/objects, SQL DBMON (shopshim + fraud)
#   - agent: receiver_creator (mysql, redis), flagd trace drops, WORKSHOP_* envs
# =============================================================================

# Cluster receiver: single-replica Deployment — persistent queue not supported
# by the chart (pod may reschedule to a different node; hostPath would not follow).
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
    exporters:
%{ if gateway_enabled ~}
      # Forward custom cluster-receiver pipelines to the gateway Deployment.
      otlp_grpc:
        endpoint: splunk-otel-collector:4317
        tls:
          insecure: true
%{ endif ~}
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
          exporters:
%{ if gateway_enabled ~}
            - otlp_grpc
%{ else ~}
            - signalfx
%{ endif ~}
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
%{ if gateway_enabled ~}
            - otlp_grpc
%{ else ~}
            - otlp_http/dbmon
%{ endif ~}

# Agent overlays for Astronomy Shop. Merged after base file — replaces metrics/traces
# pipelines to add receiver_creator (mysql, redis-cart) and filter/drop_flagd (flagd noise).
agent:
  extraEnvs:
  - name: WORKSHOP_ENVIRONMENT
    valueFrom:
      secretKeyRef:
        name: workshop-secret
        key: instance
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
