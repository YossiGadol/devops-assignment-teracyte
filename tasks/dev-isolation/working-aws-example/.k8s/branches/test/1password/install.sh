helm repo add 1password https://1password.github.io/connect-helm-charts/
helm repo update
helm upgrade --install connect 1password/connect -f values.yaml
kubectl apply -f secret.yaml
#helm upgrade connect 1password/connect -f values.yaml