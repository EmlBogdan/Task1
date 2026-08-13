#!/bin/bash
set -e

curl -fsSL https://ollama.com/install.sh | sh
apt update
apt install -y amazon-cloudwatch-agent

mkdir -p /etc/systemd/system/ollama.service.d
cat <<EOT > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOT

cat <<'EOT' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    {
      "metrics": {
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    EOT

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s


systemctl daemon-reload
systemctl restart ollama

ollama pull llama3.2:1b

apt install -y stress