#! /bin/bash

if [ ! -f okta.config.auto.tfvars ]; then
  echo "okta.config.auto.tfvars is missing"
  exit 1
fi

terraform apply --auto-approve