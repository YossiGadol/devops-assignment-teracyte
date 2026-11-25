slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
branch="$(git branch --show-current)"
env_name=$(slugify "${branch}")
cd "$(git rev-parse --show-toplevel)" || exit 1
helm upgrade --install "spin-test-env-${env_name}" .k8s/charts/spin-test-env
