
Use a specific kube config file
`kubectl --kubeconfig=./relaz-kubeconfig.yaml {your commands here}`

Check pods
`kubectl get pods`

Get information about the pod that is running
`kubectl describe pod <pod-name>`

Get the logs for a given pod
`kubectl logs <pod-name>`

Deploy the web app
`kubectl apply -f ../app/files/web-app.yaml`
