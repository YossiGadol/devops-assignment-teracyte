kubectl config get-contexts | grep -E 'python' | awk '{print $2}' | while read context; do
  kubectl config use-context "$context"  &>/dev/null
  if kubectl cluster-info &>/dev/null; then
    echo "Restarting MCP server in context: $context"
    kubectl rollout restart deployment mcp-server
  else
    echo "Invalid context: $context, skipping..."
  fi
done