. ./util.sh

run 'clear'

cd ../../../aks-store-demo-manifests
run 'pwd'

#desc 'Checkout the london branch'
run 'git checkout london'

#desc 'Merge in changes from the london-ai branch'
run 'git merge origin/london-ai'

#desc 'Show the changes'
run 'git diff origin/london'

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

#desc 'Merge in changes from the london-ai-canary branch'
run 'git merge origin/london-ai-canary'

#desc 'Show the changes'
run 'git diff origin/london'

#desc 'Push changes and let Flux do its thing again'
run 'git push'

#desc 'Force a flux reconciliation of the image update resources'
run 'flux reconcile kustomization aks-store-demo-manifests-dev-image'

#desc 'Watch for a new image repository to be deployed for the ai-service'
run 'flux get image repository -w'

#desc 'Check the status of the image policy'
run 'flux get image policy ai-service'

#desc 'Force a flux reconciliation of the canary resources'
run 'flux reconcile kustomization aks-store-demo-manifests-dev-canary'

#desc 'Watch for the canary to be initialized'
run 'kubectl get canary -n dev ai-service -w'

#desc 'Check the status of the canary'
run 'kubectl describe canary -n dev ai-service'

run 'cd ../aks-store-demo && pwd'
cd ../aks-store-demo && pwd

#desc 'Open the repo in VS Code'
run 'code .'

#desc 'Commit and push the changes'
run 'git add -A'
run 'git status'
run 'git diff origin/main'
run 'git commit -m "feat: tweaking temp"'
run 'git push'

#desc 'Create a new release of aks-store-demo'
run 'gh release create 2.0.0 --generate-notes'

#desc 'Watch the release deploy'
run 'gh run watch'

run 'cd -'
cd -

#desc 'Force a flux reconciliation of the image repository for the ai-service'
run 'flux reconcile image repository ai-service'

#desc 'Force a flux reconciliation of the image policy for the ai-service'
run 'flux get image policy ai-service'

#desc 'Pull the latest changes'
run 'git pull'

#desc 'Show the changes'
run 'git log --oneline'

run 'clear'

#desc 'Watch for the canary to be promoted'
run 'kubectl get canary -n dev ai-service -w'