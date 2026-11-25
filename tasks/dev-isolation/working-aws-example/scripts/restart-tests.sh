deployments=$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep 'working_example-test-')
for deployment in $deployments; do
    printf "\n\e[1;32mRestarting deployment: %s\e[0m\n" "$deployment"
    kubectl rollout restart deployment "$deployment"
done

