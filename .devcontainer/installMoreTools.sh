#!bin/bash

sudo apt update

# install pv for demo scripts
sudo apt install pv -y

# install flux cli
curl -s https://fluxcd.io/install.sh | FLUX_VERSION=2.0.0 bash