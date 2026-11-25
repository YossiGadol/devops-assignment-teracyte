virtual_servers=$(kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get virtualservers -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
for vs in $virtual_servers; do
  echo "Processing VirtualServer: $vs"
  kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test patch virtualserver "$vs" \
  -p "{\"spec\":{\"upstreams\":[{\"name\":\"$vs\",\"port\":8080,\"service\":\"keda-add-ons-http-interceptor-proxy\"}]}}" --type=merge
done