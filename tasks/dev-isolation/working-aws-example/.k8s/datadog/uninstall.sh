kubectl config get-contexts | grep -E 'app-test' | awk '{print $2}' | while read -r context; do
  if kubectl --context="$context" cluster-info &>/dev/null; then
    cluster="${context##*/}"
    echo
    printf "\033[1;32mUninstalling from cluster: %s\033[0m\n" "$cluster"
    echo
    echo
    kubectl --context="$context" delete --ignore-not-found secret datadog-secret
    helm --kube-context="$context" uninstall --ignore-not-found datadog-agent
    helm --kube-context="$context" uninstall --ignore-not-found cronitor-kubernetes-0.6.0
    kubectl --context="$context" delete --ignore-not-found secret cronitor-secret
    kubectl --context="$context" delete --ignore-not-found configmap datadog-cluster-id
    kubectl --context="$context" delete --ignore-not-found configmap datadog-agenttoken
    kubectl --context="$context" delete --ignore-not-found configmap datadog-agent-leader-election
    resource_types=("pods" "deployments" "services" "configmaps" "secrets" "statefulsets" "daemonsets" "replicasets" "jobs" "cronjobs")
    for type in "${resource_types[@]}"; do
      kubectl get "$type" --all-namespaces | grep datadog | awk '{print $1, $2}' | while read -r namespace name; do
        kubectl delete "$type" "$name" -n "$namespace"
      done
    done
  else
    echo "Invalid context: $context, skipping..."
  fi
done