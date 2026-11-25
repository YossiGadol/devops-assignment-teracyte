helm --kube-context arn:aws:eks:us-east-2:999999999999:cluster/app-test upgrade --install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress -f default-values.yaml
# --set controller.image.repository=public.ecr.aws/nginx/nginx-ingress
# --set controller.service.create=false
