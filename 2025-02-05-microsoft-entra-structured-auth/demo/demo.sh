#!/bin/bash
# import the magic file shout out to @paxtonhare ✨
# make sure you have pv installed for the pe and pei functions to work!
which pv
if [ $? -ne 0 ]; then
  echo "pv is not installed. Please install it using 'brew install pv' or 'sudo apt-get install pv'"
  exit 1
fi

. demo-magic.sh
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

TYPE_SPEED=40
cd ../

p "# get tenant id"
pei "MSFT_TENANT_ID=\$(terraform output -raw microsoft_tenant_id)"

p "# get client id"
pei "MSFT_CLIENT_ID=\$(terraform output -raw microsoft_client_id)"

p "# get the issuer url"
pei "MSFT_ISSUER_URL=\$(terraform output -raw microsoft_issuer_url)"

p "# get the device code"
p "response=\$(curl -X POST https://login.microsoftonline.com/\$MSFT_TENANT_ID/oauth2/v2.0/devicecode \\
  -H \"Content-Type: application/x-www-form-urlencoded\" \\
  -d \"client_id=\${MSFT_CLIENT_ID}&scope=https://graph.microsoft.com/.default offline_access openid profile\")"
response=$(curl -X POST https://login.microsoftonline.com/$MSFT_TENANT_ID/oauth2/v2.0/devicecode -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${MSFT_CLIENT_ID}&scope=https://graph.microsoft.com/.default offline_access openid profile")

p "# extract the device code and user code from response"
pei "DEVICE_CODE=\$(echo \"\$response\" | jq -r '.device_code') && USER_CODE=\$(echo \"\$response\" | jq -r '.user_code')"

p "# print login url and user code for device code flow login"
pei "echo \"https://microsoft.com/devicelogin\" && echo \"\$USER_CODE\""

p "# exchange the device code for bearer token"
p "curl -X POST https://login.microsoftonline.com/\$MSFT_TENANT_ID/oauth2/v2.0/token \\
  -H \"Content-Type: application/x-www-form-urlencoded\" \\
  -d \"grant_type=device_code&client_id=\${MSFT_CLIENT_ID}&device_code=\${DEVICE_CODE}\" | jq"
curl -X POST https://login.microsoftonline.com/$MSFT_TENANT_ID/oauth2/v2.0/token -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=device_code&client_id=${MSFT_CLIENT_ID}&device_code=${DEVICE_CODE}" | jq

p "# view kind config"
pei "less manifests/kindconfig1.yaml"

p "# create a new kind cluster"
pei "kind create cluster --config manifests/kindconfig1.yaml"

p "# add azure user entry in kubeconfig"
p "kubectl config set-credentials azure-user \\
--exec-api-version=client.authentication.k8s.io/v1 \\
--exec-interactive-mode=Never \\
--exec-command=kubectl \\
--exec-arg=oidc-login \\
--exec-arg=get-token \\
--exec-arg=--oidc-issuer-url=\${MSFT_ISSUER_URL} \\
--exec-arg=--oidc-client-id=\${MSFT_CLIENT_ID} \\
--exec-arg=--oidc-extra-scope=\"email offline_access profile openid\""
kubectl config set-credentials azure-user --exec-api-version=client.authentication.k8s.io/v1 --exec-interactive-mode=Never --exec-command=kubectl --exec-arg=oidc-login --exec-arg=get-token --exec-arg=--oidc-issuer-url=${MSFT_ISSUER_URL} --exec-arg=--oidc-client-id=${MSFT_CLIENT_ID} --exec-arg=--oidc-extra-scope="email offline_access profile openid"

p "# deploy a pod"
pei "kubectl run mybusybox --user=azure-user --image=busybox --restart=Never --command -- sleep 3600"

p "# create cluster role binding for the group"
pei "less manifests/azure-admin-rolebinding.yaml"
pe "kubectl apply -f manifests/azure-admin-rolebinding.yaml"

p "# deploy a pod"
pei "kubectl run mybusybox --user=azure-user --image=busybox --restart=Never --command -- sleep 3600"

p "# reset the cluster"
pei "kind delete cluster"
pei "kubectl config delete-user azure-user"
pei "kubectl oidc-login clean"

p "# view structured auth config"
pei "less manifests/structured-auth.yaml"

p "# view new kind config"
pei "less manifests/kindconfig2.yaml"

p "# create a new kind cluster"
pei "kind create cluster --config manifests/kindconfig2.yaml"

p "# create cluster role binding for the group"
pei "kubectl apply -f manifests/azure-admin-rolebinding.yaml"

p "# add azure user entry in kubeconfig"
p "kubectl config set-credentials azure-user \\
--exec-api-version=client.authentication.k8s.io/v1 \\
--exec-interactive-mode=Never \\
--exec-command=kubectl \\
--exec-arg=oidc-login \\
--exec-arg=get-token \\
--exec-arg=--oidc-issuer-url=\${MSFT_ISSUER_URL} \\
--exec-arg=--oidc-client-id=\${MSFT_CLIENT_ID} \\
--exec-arg=--oidc-extra-scope=\"email offline_access profile openid\""
kubectl config set-credentials azure-user --exec-api-version=client.authentication.k8s.io/v1 --exec-interactive-mode=Never --exec-command=kubectl --exec-arg=oidc-login --exec-arg=get-token --exec-arg=--oidc-issuer-url=${MSFT_ISSUER_URL} --exec-arg=--oidc-client-id=${MSFT_CLIENT_ID} --exec-arg=--oidc-extra-scope="email offline_access profile openid"

p "# test the structured auth"
pei "kubectl run mybusybox --user=azure-user --image=busybox --restart=Never --command -- sleep 3600"
pe "kubectl get nodes --user=azure-user"

p "# get okta issuer url"
pei "OKTA_ISSUER_URL=\$(terraform output -raw okta_issuer_url)"
p "# get okta client id"
pei "OKTA_CLIENT_ID=\$(terraform output -raw okta_client_id)"

p "# drop in a new jwt provider"
p "cat <<EOF >> manifests/structured-auth.yaml
  - issuer:
      url: \$OKTA_ISSUER_URL
      audiences:
      - \$OKTA_CLIENT_ID
    claimMappings:
      username:
        claim: "email"
        prefix: ""
      groups:
        claim: "groups"
        prefix: ""
EOF"
cat <<EOF >> manifests/structured-auth.yaml
  - issuer:
      url: $OKTA_ISSUER_URL
      audiences:
      - $OKTA_CLIENT_ID
    claimMappings:
      username:
        claim: "email"
        prefix: ""
      groups:
        claim: "groups"
        prefix: ""
EOF

p "# check the structured auth config"
pe "docker exec -it kind-control-plane cat /etc/kubernetes/structured-auth.yaml"

p "# check the kube-apiserver logs"
pe "docker exec -it kind-control-plane sh -c \"cat /var/log/containers/kube-apiserver-kind-control-plane_kube-system_kube-apiserver-*.log\""

p "# deploy reader role for okta user"
pei "less manifests/okta-reader-role.yaml"
pe "kubectl apply -f manifests/okta-reader-role.yaml"

p "# deploy reader role binding for okta user"
pei "less manifests/okta-reader-rolebinding.yaml"
pe "kubectl apply -f manifests/okta-reader-rolebinding.yaml"

p "# add okta user entry in kubeconfig"
p "kubectl config set-credentials okta-user \\
--exec-api-version=client.authentication.k8s.io/v1beta1 \\
--exec-command=kubectl \\
--exec-arg=oidc-login \\
--exec-arg=get-token \\
--exec-arg=--oidc-issuer-url=\${OKTA_ISSUER_URL} \\
--exec-arg=--oidc-client-id=\${OKTA_CLIENT_ID} \\
--exec-arg=--oidc-extra-scope=\"email offline_access profile openid\""
kubectl config set-credentials okta-user --exec-api-version=client.authentication.k8s.io/v1beta1 --exec-command=kubectl --exec-arg=oidc-login --exec-arg=get-token --exec-arg=--oidc-issuer-url=${OKTA_ISSUER_URL} --exec-arg=--oidc-client-id=${OKTA_CLIENT_ID} --exec-arg=--oidc-extra-scope="email offline_access profile openid"

p "# test with the okta user"
pei "kubectl get pods --user=okta-user"
pe "kubectl get nodes --user=okta-user"

p "# add claim validation rule"
p "cat <<EOF >> manifests/structured-auth.yaml
    claimValidationRules:
      - expression: \"claims.name.startsWith('Bob')\"
        message: only people named Bob are allowed
EOF"
cat <<EOF >> manifests/structured-auth.yaml
    claimValidationRules:
      - expression: "claims.name.startsWith('Bob')"
        message: only people named Bob are allowed
EOF

p "# check the structured auth config"
pe "docker exec -it kind-control-plane cat /etc/kubernetes/structured-auth.yaml"
pe "docker exec -it kind-control-plane sh -c \"cat /var/log/containers/kube-apiserver-kind-control-plane_kube-system_kube-apiserver-*.log\""

p "# clean token cache"
pei "kubectl oidc-login clean"

p "# test again as okta user"
pei "kubectl get pods --user=okta-user"

p "# edit validation rule"
pei "nano manifests/structured-auth.yaml"

p "# check the structured auth config"
pe "docker exec -it kind-control-plane cat /etc/kubernetes/structured-auth.yaml"
pe "docker exec -it kind-control-plane sh -c \"cat /var/log/containers/kube-apiserver-kind-control-plane_kube-system_kube-apiserver-*.log\""

p "# clean token cache"
pei "kubectl oidc-login clean"

p "# test again as okta-user"
pei "kubectl get pods --user=okta-user"

p "exit"

cd -
clear