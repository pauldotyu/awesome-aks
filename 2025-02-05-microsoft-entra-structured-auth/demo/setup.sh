#! /bin/bash

cd ../
# if [ ! -f okta.auto.tfvars ]; then
#   echo "okta.auto.tfvars is missing"
#   exit 1
# fi
terraform apply --auto-approve
cd -