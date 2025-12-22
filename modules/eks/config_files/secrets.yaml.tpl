apiVersion: v1
kind: Secret
metadata:
  name: workshop-secret
  namespace: default
type: Opaque
stringData:
  instance: ${environment}-astro-shop-demo
  app: ${environment}-store
  env: ${environment}-astro-shop-demo
  deployment: "deployment.environment=${environment}-astro-shop-demo"
  realm: eu0
  access_token: ${eks_access_token}
  api_token: ${eks_access_token}
  rum_token: ${rum_token}
  hec_token: ${hec_token}
  hec_url: ${hec_url}
  url: ${aws_lb_dns_name}
  appd_token: "xxx"
  flagd_auth: "false"
  flagd_user: "user"
  flagd_pw: "pw"
# data:
  # TEAGENT_ACCOUNT_TOKEN: -