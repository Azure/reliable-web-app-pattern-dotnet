kubectl --kubeconfig=kube_config.yaml get pods -n app

kubectl --kubeconfig=kube_config.yaml get pods -o wide -n app

kubectl -n app logs [pod-name]

kubectl --kubeconfig=kube_config.yaml apply -f web-app.yaml