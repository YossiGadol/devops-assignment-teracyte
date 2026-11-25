objects=$(kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get httpscaledobject | grep -v NAME | awk '{print $1}')
for object in $objects; do kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test delete httpscaledobject "$object"; done
objects=$(kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test get scaledobject | grep -v NAME | awk '{print $1}')
for object in $objects; do kubectl --context=arn:aws:eks:us-east-2:999999999999:cluster/app-test delete scaledobject "$object"; done
helm --kube-context arn:aws:eks:us-east-2:999999999999:cluster/app-test uninstall http-add-on
helm --kube-context arn:aws:eks:us-east-2:999999999999:cluster/app-test uninstall keda
