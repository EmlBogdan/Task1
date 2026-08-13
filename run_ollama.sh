#!/bin/bash
set -e

curl -fsSL https://ollama.com/install.sh | sh

mkdir -p /etc/systemd/system/ollama.service.d
cat <<EOT > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOT

systemctl daemon-reload
systemctl restart ollama

ollama pull llama3.2:1b