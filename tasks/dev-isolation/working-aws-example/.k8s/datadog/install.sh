helm repo add datadog https://helm.datadoghq.com
helm repo update
kubectl config get-contexts | grep -E 'app-test' | awk '{print $2}' | while read -r context; do
  kubectl config use-context "$context"  &>/dev/null
  if kubectl cluster-info &>/dev/null; then
    cluster="${context##*/}"
    echo "Installing Datadog in cluster: $cluster"
    kubectl apply -f datadog-secret.yaml
    helm upgrade --install datadog-agent -f datadog-values.yaml --set datadog.clusterName="$cluster" --set datadog.tags="{env:$cluster}" datadog/datadog
  else
    echo "Invalid context: $context, skipping..."
  fi
done
