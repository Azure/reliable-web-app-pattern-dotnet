
## Use a specific kube config file
`kubectl --kubeconfig=./relaz-kubeconfig.yaml {your commands here}`

## Check pods
`kubectl get pods`

## Get information about the pod that is running
`kubectl describe pod <pod-name>`

## Get the logs for a given pod
`kubectl logs <pod-name>`

## Deploy the web app
`kubectl apply -f web-app.yaml`

## Rollout updates to the deployment
This is if you change the managed identity's role assignments or something that is not k8s related and the deployment will need to refresh
`kubectl rollout restart deployment/relecloud-web-app`

