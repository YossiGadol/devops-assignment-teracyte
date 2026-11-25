helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm --kube-context arn:aws:eks:us-east-2:999999999999:cluster/app-test upgrade --install keda kedacore/keda
helm --kube-context arn:aws:eks:us-east-2:999999999999:cluster/app-test upgrade --install http-add-on kedacore/keda-add-ons-http