git checkout main
git branch -l 'origin/test/*' 'origin/feat/*' 'origin/feature/*' 'test/*' 'feat/*' 'feature/*' | xargs -r git branch -D
for branch in $(git branch -r -l 'origin/test/*' 'origin/feat/*' 'origin/feature/*' | cut -d/ -f2-); do
    if [ "$branch" != "main" ]; then
        printf "\e[33mUpdating branch: %s\e[0m\n" "$branch"
                git checkout "$branch"
                git restore --source main .gitignore
                git restore --source main .k8s/
                git restore --source main .github/
                git add .
                git commit -m "Update .k8s dir from main"
                git stash clear
    fi
done
git checkout main
git push origin --all
git branch -l 'origin/test/*' 'origin/feat/*' 'origin/feature/*' 'test/*' 'feat/*' 'feature/*' | xargs -r git branch -D
printf "\n\e[1;32mDone.\e[0m\n"
