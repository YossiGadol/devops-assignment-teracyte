kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get deployments -o custom-columns='NAME:.metadata.name,AGE:.metadata.creationTimestamp' --no-headers | awk -vAGE_HOURS=8 '{
    # Calculate age in days
    cmd = "date -d "$2" +%s"
    cmd | getline creation_timestamp
    close(cmd)
    current_timestamp = systime()
    age_seconds = current_timestamp - creation_timestamp
    age_hours = age_seconds / 3600

    # Print only if age is greater than AGE_HOURS
    if (age_hours > AGE_HOURS && $1 ~ /-test-/) {
        system("kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test delete deployment "$1"")
    }
}'
