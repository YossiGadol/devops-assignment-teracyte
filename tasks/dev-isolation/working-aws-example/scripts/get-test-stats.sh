##!/bin/bash
deployments=$(kubectl get deployments -o name | grep "deployment.apps/working_example-test-" | sed 's|deployment.apps/working_example-test-||')
declare -A user_branches
declare -A user_counts
for deployment in $deployments; do
    branch_name="test/${deployment}"
    count=$(git branch --list -r "origin/$branch_name" | wc -l)
    if [ "$count" -gt 0 ]; then
        user=$(git log "origin/$branch_name" -1 --pretty=format:'%aE')
        if [ -n "$user" ]; then
            if [ -z "${user_counts[$user]}" ]; then
                user_counts[$user]=1
                user_branches[$user]="$branch_name"
            else
                ((user_counts[$user]++))
                user_branches[$user]="${user_branches[$user]}, $branch_name"
            fi
        fi
    fi
done
bearer_token=bearer_token
echo "Users and their pushed branches:"
echo "================================"
for user in "${!user_counts[@]}"; do
    if [[ ${user_counts[$user]} -lt 2 ]]; then continue; fi
    real_name=$(curl -s "https://slack.com/api/users.lookupByEmail?email=$user" -H "Authorization: Bearer $bearer_token" | jq -r ".user.profile.display_name_normalized")
    slack_id=$(curl -s "https://slack.com/api/users.lookupByEmail?email=$user" -H "Authorization: Bearer $bearer_token" | jq -r ".user.id")
    if [[ "$slack_id" == "null" ]]; then
        alternate_email=${user/%working-example.com/twik.io}
        slack_id=$(curl -s "https://slack.com/api/users.lookupByEmail?email=$alternate_email" -H "Authorization: Bearer $bearer_token" | jq -r ".user.id")
    fi
    if [[ "$slack_id" != "null" ]]; then
        echo "User: $real_name, $user, $slack_id"
        echo "  Count: ${user_counts[$user]}"
        echo "  Branches: ${user_branches[$user]}"
        echo ""
        md_block_data=""
        for branch in ${user_branches[$user]}; do
            md_block_data+="- $branch\n"
        done
    fi
    msg_data=$(printf '{"channel":"%s","blocks": [{"type":"section","text": {"type":"mrkdwn","text":"*Hi %s,*\n*You have %d active test branches.*\n*Please make sure you delete test branches that are not needed anymore.*"}},{"type":"section","text": {"type":"mrkdwn","text":"%s"}},{"type":"divider"}]}' "$slack_id" "$real_name" "${user_counts[$user]}" "$md_block_data")
    curl -s -X POST https://slack.com/api/chat.postMessage -H "Authorization: Bearer $bearer_token" -H 'Content-type: application/json' --data "$msg_data" -o /dev/null
done
