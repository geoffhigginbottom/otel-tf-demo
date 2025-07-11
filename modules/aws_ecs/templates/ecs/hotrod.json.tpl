[
  {
    "name": "hotrod",
    "image": "${app_image}",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${environment}/ecs",
          "awslogs-region": "${region}",
          "awslogs-stream-prefix": "hotrod"
        }
    },
    "portMappings": [
      {
        "containerPort": ${app_port},
        "hostPort": ${app_port},
        "protocol": "tcp"
      }
    ]
  },
  {
    "environment": [
      {
          "name": "METRICS_TO_EXCLUDE",
          "value": "[]"
      },
      {
          "name": "SPLUNK_CONFIG",
          "value": "/etc/otel/collector/fargate_config.yaml"
      },
      {
          "name": "SPLUNK_REALM",
          "value": "${realm}"
      },
      {
          "name": "SPLUNK_ACCESS_TOKEN",
          "value": "${access_token}"
      },
      {
          "name": "ECS_METADATA_EXCLUDED_IMAGES",
          "value": "[\"quay.io/signalfx/splunk-otel-collector:latest\"]"
      },
      {
          "name": "OTEL_RESOURCE_ATTRIBUTES",
          "value": "deployment.environment=${environment}-hotrod,service.name=hotrod"
      }
    ],
    "image": "quay.io/signalfx/splunk-otel-collector:latest",
    "essential": true,
    "name": "splunk-otel-collector"
  }
]