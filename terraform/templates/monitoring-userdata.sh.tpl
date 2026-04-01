#!/bin/bash

# wait for docker daemon to be fully ready
systemctl start docker
while ! docker info > /dev/null 2>&1; do
  sleep 5
done

# wait for internet connectivity through NAT gateway
while ! curl -s --max-time 5 https://registry-1.docker.io/v2/ > /dev/null 2>&1; do
  sleep 10
done

# get this instance's private ip
SELF_IP=$(hostname -I | awk '{print $1}')

# create prometheus config
mkdir -p /home/ec2-user/prometheus
cat > /home/ec2-user/prometheus/prometheus.yml <<PROMEOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets:
%{ for ip in private_ips ~}
          - '${ip}:9100'
%{ endfor ~}
  - job_name: 'monitoring'
    static_configs:
      - targets:
          - '$SELF_IP:9100'
PROMEOF

# create grafana provisioning directories
mkdir -p /home/ec2-user/grafana/provisioning/datasources
mkdir -p /home/ec2-user/grafana/provisioning/dashboards
mkdir -p /home/ec2-user/grafana/dashboards

# grafana datasource - point to prometheus on host IP
cat > /home/ec2-user/grafana/provisioning/datasources/datasource.yml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://$SELF_IP:9090
    isDefault: true
EOF

# grafana dashboard provider
cat > /home/ec2-user/grafana/provisioning/dashboards/dashboard-provider.yml <<'EOF'
${grafana_dashboard_provider_yml}
EOF

# grafana dashboard json
cat > /home/ec2-user/grafana/dashboards/node-metrics.json <<'EOF'
${grafana_dashboard_json}
EOF

# fix permissions
chown -R ec2-user:ec2-user /home/ec2-user/prometheus /home/ec2-user/grafana

# pull images with retry (NAT gateway may be slow to start)
until docker pull prom/prometheus:latest; do
  sleep 15
done
until docker pull grafana/grafana:latest; do
  sleep 15
done

# run prometheus
docker run -d \
  --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /home/ec2-user/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

# run grafana
docker run -d \
  --name grafana \
  --restart always \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -v /home/ec2-user/grafana/provisioning:/etc/grafana/provisioning \
  -v /home/ec2-user/grafana/dashboards:/var/lib/grafana/dashboards \
  grafana/grafana:latest
