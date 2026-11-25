deployments=$(kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get deployments -o custom-columns='NAME:.metadata.name' --no-headers)

# Check for redis-test- deployments without matching working_example-test- deployments
echo "Checking for unmatched redis-test- deployments..."
unmatched_found=false

for deployment in $deployments; do
  if [[ $deployment == redis-test-* ]]; then
    # Extract the suffix after 'redis-test-'
    suffix="${deployment#redis-test-}"
    working_example_match="working_example-test-$suffix"

    # Check if matching working_example-test- deployment exists
    if ! echo "$deployments" | grep -q "^$working_example_match$"; then
      echo "No match found for: $deployment"
      kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test delete deployment "$deployment"
      unmatched_found=true
    fi
  fi
done

if [ "$unmatched_found" = false ]; then
  echo "All redis-test- deployments have matching working_example-test- deployments."
fi

