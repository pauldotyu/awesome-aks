# LLMOps with AKS and KAITO

Work in progress...

## Azure Infrastructure Provisioning

To provision the Azure infrastructure, you need to have the following tools installed:

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)

You will also need access to an Azure subscription with the "Owner" role.

Clone the repository and change into the directory.

Using the Azure CLI, log in and set the subscription.

```bash
az login --use-device-code
```

Export the subscription ID and run Terraform commands to provision the infrastructure.

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform apply
```

The Terraform script will provision the following resources:

- Azure Kubernetes Service 
- Azure Container Registry 
- Azure Storage 
- Azure Event Hubs 
- Azure Monitor Action Groups 
- Azure Managed Prometheus 
- Azure Managed Grafana 
- Azure Log Analytics Workspace 

Once the Terraform script completes, connect to the AKS cluster.

```bash
az aks get-credentials -g $(terraform output -raw rg_name) -n $(terraform output -raw aks_name)
```

## Application Deployment

Deploy the ArgoCD application manifest which will deploy the AKS Store Demo application with a KAITO workspace for the ai-serivce to use.

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/pauldotyu/aks-store-demo/refs/heads/main/sample-manifests/argocd/pets.yaml
```

You can run the following command to watch the pods roll out.

```bash
kubectl get po -n pets -w
```

Optionally, you can also watch the ArgoCD application status using the ArgoCD web UI.

First, you'll need to get the initial password for the ArgoCD admin user.

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Copy the password and run the following command to port forward the ArgoCD server.

```bash
kubectl port-forward -n argocd svc/argocd-release-server 8080:443
```

Open a browser and navigate to `https://localhost:8080`. Log in with the username `admin` and the password you copied earlier.

Wait for the application status to show "Healthy" before proceeding.

## Argo Events and Workflow Setup

The Argo Events and Workflow components are not installed since the manifests need Azure resource specific configuration. The Terraform script will create the necessary manifests for you to deploy. So you can deploy the Argo Event and Workflow manifests using the following command.

```bash
kustomize build ./manifests | kubectl apply -f -
```

## Prometheus Metrics

The solution deploys a Prometheus ServiceMonitor to scrape the metrics from the product-service. You can confirm the configuration is setup correctly by port-forwarding the Prometheus pod and checking the configuration using the Prometheus web UI.

Run the following command to port-forward the Prometheus pod.

```bash
AMA_METRICS_POD_NAME="$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[0].metadata.name}')"
kubectl port-forward $AMA_METRICS_POD_NAME -n kube-system 9090
```

> If the first pod does not show the job configuration, try the second pod.

Open a browser and navigate to `http://localhost:9090`. Click on the "Status" dropdown and select "Targets". You should see the product-service target with the status "UP".

This ServiceMonitor will scrape the product_count metric from the product-service and use the value to trigger the tuning pipeline.

## Triggering the Tuning Pipeline

To trigger the tuning pipeline, you need to import the test data into the product-service.

Open a new terminal, port-forward the product-service.

```bash
kubectl port-forward -n pets svc/product-service 3002
```

Press **Ctrl+z** then type `bg` to move the process to the background.

Test the product-service metrics endpoint.

```bash
curl http://localhost:3002/metrics
```

You should see an initial product count of 10.

Gradually import the test data.

```bash
for i in {1..4}; do
  curl -X POST http://localhost:3002/import -H "Content-Type: application/json" --data-binary @testImport$i.json
  echo "Processed testImport$i.json"
  sleep 30
done
```

## Verifying the Tuning Pipeline

With the gradual import of product data, the product count will increase and the Prometheus rule will trigger and event which is sent to Azure Event Hub and eventually consumed by the Argo Event sensor.

To confirm the sensor is triggered, check the logs of the sensor pod.

```bash
SENSOR_POD_NAME=$(kubectl get po -n pets -l owner-name=tuning-sensor -ojsonpath='{.items[0].metadata.name}')
kubectl logs -n pets $SENSOR_POD_NAME -f
```

After 2 minutes or so, check the logs of the sensor pod. You should see the logs that look like the following:

```text
{"level":"info","ts":1732321849.38135,"logger":"argo-events.sensor","caller":"sensor/trigger_conn.go:115","msg":"starting ExactOnce cache clean up daemon ...","sensorName":"tuning-sensor","triggerName":"tuning-trigger","clientID":"client-734621638-6"}
Name:                tuning-pipeline-dwwqw
Namespace:           pets
ServiceAccount:      unset
Status:              Pending
Created:             Mon Nov 25 21:44:55 +0000 (now)
Progress:            
{"level":"info","ts":1732571095.3456018,"logger":"argo-events.sensor","caller":"sensors/listener.go:433","msg":"Successfully processed trigger 'tuning-trigger'","sensorName":"tuning-sensor","triggerName":"tuning-trigger","triggerType":"ArgoWorkflow","triggeredBy":["tuning-webhook-triggered"],"triggeredByEvents":["66633639656566312d356361642d346231652d393530662d646332636530343334333039"]}
```

The sensor pod logs indicate that the tuning pipeline was triggered by the tuning-webhook-triggered event. You can verify this by checking the Argo Workflow for the tuning pipeline.

```bash
kubectl describe workflow -n pets tuning-pipeline-dwwqw
```

In the event logs, you should see the following:

```text
Events:
  Type    Reason                 Age   From                 Message
  ----    ------                 ----  ----                 -------
  Normal  WorkflowRunning        88s   workflow-controller  Workflow Running
  Normal  WorkflowNodeRunning    88s   workflow-controller  Running node tuning-pipeline-jphf2
  Normal  WorkflowSucceeded      78s   workflow-controller  Workflow completed
  Normal  WorkflowNodeRunning    78s   workflow-controller  Running node tuning-pipeline-jphf2.tune-model
  Normal  WorkflowNodeSucceeded  78s   workflow-controller  Succeeded node tuning-pipeline-jphf2.tune-model
  Normal  WorkflowNodeSucceeded  78s   workflow-controller  Succeeded node tuning-pipeline-jphf2
```

You can also use the Argo Workflow web UI to view the workflow.

To access the Argo Workflow web UI, you will need a token to authenticate. Run

```bash
ARGO_TOKEN="Bearer $(kubectl get secret -n pets argo-workflow-ui-reader-service-account-token -o=jsonpath='{.data.token}' | base64 --decode)"
echo $ARGO_TOKEN
```

Next, port-forward the Argo Workflow UI.

```bash
kubectl port-forward svc/argoworkflows-release-argo-workflows-server -n argo 2746:2746
```

Open a browser and navigate to `http://localhost:2746`. Click on the "Login" button and paste the token you copied earlier.

You should see the tuning pipeline in the list of workflows. Click on the workflow to view the details.

## Cleanup

```bash
terraform state rm kubernetes_namespace.example
terraform destroy --auto-approve
rm terraform.tfstate*
```
