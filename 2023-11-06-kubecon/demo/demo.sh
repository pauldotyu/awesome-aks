. ./util.sh

# Start off by showing the app without AI capabilities
# Then merge in the changes from the kubecon-ai branch
# Finally, show the app with AI capabilities after Flux has reconciled the changes

run 'clear'

cd ../../../aks-store-demo-manifests
run 'pwd'

#desc 'Checkout the kubecon branch'
run 'git checkout kubecon'

#desc 'Merge in changes from the kubecon-ai branch'
run 'git merge origin/kubecon-ai'

#desc 'Show the changes'
run 'git diff origin/kubecon'

#desc 'Confirm there is no ai-service pod running'
run 'kubectl get po -n dev'

#desc 'Push changes and let Flux do its thing'
run 'git push'

#desc 'Force a flux reconciliation of the app resources'
run 'flux reconcile kustomization aks-store-demo-manifests-dev-app --with-source'

#desc 'Confirm the ai-service pod is running'
run 'kubectl get po -n dev'

#desc 'Show the logs of the ai-service pod'
run 'kubectl logs -lapp=ai-service -n dev -f'

#desc 'Show the public IP of the Istio external ingress'
run 'echo "http://$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath=\'{.status.loadBalancer.ingress[0].ip}\')"'