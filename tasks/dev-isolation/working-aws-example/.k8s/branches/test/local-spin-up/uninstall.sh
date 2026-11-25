slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
branch="$(git branch --show-current)"
env_name=$(slugify "${branch}")
helm uninstall "spin-test-env-${env_name}"
