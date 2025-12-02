default:
  envOverrides:
    - name: OTEL_RESOURCE_ATTRIBUTES
      value: "deployment.environment=astro-shop-demo-${environment},env=eks"

opentelemetry-collector:
  enabled: false
jaeger:
  enabled: false
prometheus:
  enabled: false
grafana:
  enabled: false
opensearch:
  enabled: false

components:
  frontend-proxy:
    service:
      type: NodePort
      nodePort: 30080
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "external"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
        service.beta.kubernetes.io/aws-load-balancer-target-type: "ip"  # register pods directly
        service.beta.kubernetes.io/aws-load-balancer-tags: "splunkit_environment_type=non-prd,splunkit_data_classification=private"
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"



  accounting:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  ad:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  cart:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  checkout:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  currency:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  email:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  flagd:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  fraud-detection:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  frontend:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  image-provider:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  load-generator:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  payment:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  postgresql:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  product-catalog:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  quote:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  recommendation:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  shipping:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"

  valkey-cart:
    envOverrides:
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: "grpc"
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: "http://splunk-otel-collector-agent:4317"
      - name: SPLUNK_OTEL_COLLECTOR_RESOURCE_ATTRIBUTES
        value: "deployment.environment=astro-shop-demo-${environment},env=eks"
