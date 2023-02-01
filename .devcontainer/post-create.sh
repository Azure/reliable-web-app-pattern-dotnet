#!/bin/bash

# this runs at Codespace creation - not part of pre-build

echo "$(date)    post-create start" >> ~/status

# Install Azure Developer Cli
curl -fsSL https://aka.ms/install-azd.sh | bash

# Install Taskfile
sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

echo "$(date)    post-create complete" >> ~/status
