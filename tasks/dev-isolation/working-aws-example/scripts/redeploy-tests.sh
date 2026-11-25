branches=$(git branch -r | grep 'origin/test/' | sed 's|origin/||')
#branches=('test/check-migrations')
for branch in $branches; do
    printf "\n\e[1;32mRedeploying branch: %s\e[0m\n" "$branch"
    gh workflow run "deploy-test-env-without-rebuild.yaml" --ref "$branch"
    sleep 5
    run_id=$(gh run list --workflow "deploy-test-env-without-rebuild.yaml" --event workflow_dispatch --branch "$branch" --limit 1 --json  databaseId | jq -r '.[].databaseId')
    printf "\e[33mTriggered workflow run with ID: %s\e[0m\n" "$run_id"
    gh run watch "$run_id" --exit-status
done