deployments=$(kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get deployments -o custom-columns='NAME:.metadata.name' --no-headers)
for deployment in $deployments; do
  if [[ $deployment == working_example-test-* ]]; then
    echo "Scaling down: $deployment"
    svc_host="${deployment#working_example-}.working-example.com"
    cat <<EOF | kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test apply --server-side --force-conflicts -f -
kind:       HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
  name: $deployment
spec:
  hosts:
    - $svc_host
    - trainer-$svc_host
  pathPrefixes:
    - /
  scaleTargetRef:
    name:       $deployment
    kind:       Deployment
    apiVersion: apps/v1
    service:    nginx-cluster-ip
    port:       80
  replicas:
    min: 1
    max: 1
  scaledownPeriod: 28800
  scalingMetric:
    requestRate:
      granularity: 1s
      targetValue: 5
      window:      1m
EOF
  fi
done