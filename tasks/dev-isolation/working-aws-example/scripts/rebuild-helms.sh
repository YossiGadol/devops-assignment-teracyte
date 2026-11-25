CONTEXT=arn:aws:eks:us-east-2:999999999999:cluster/app-test
helms=$(helm --kube-context=$CONTEXT list -q --filter 'spin-test-env-')
mkdir -p chart-values
for helm in $helms; do
    printf "\n\e[1;32mRebuilding Helm release: %s\e[0m\n" "$helm"
    helm --kube-context=$CONTEXT get values "$helm" -o yaml >"chart-values/helm-$helm-values.yaml"
    yq -i '.no_migrations = "yes"' "chart-values/helm-$helm-values.yaml"
    helm --kube-context=$CONTEXT uninstall "$helm"
    helm --kube-context=$CONTEXT upgrade --install "$helm" .k8s/charts/spin-test-env -f "chart-values/helm-$helm-values.yaml"
    rm -f "chart-values/helm-$helm-values.yaml"
done
