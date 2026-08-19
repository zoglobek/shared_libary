#!/bin/bash
set -e

# ============================
# CONFIGURATION (edit if needed)
# ============================
PROMTAIL_USER="${SUDO_USER:-$USER}"
PROMTAIL_BIN="/usr/bin/promtail"
PROMTAIL_DIR="/etc/promtail"
PROMTAIL_POS="/var/lib/promtail"
PROMTAIL_SERVICE="/etc/systemd/system/promtail.service"
LOKI_URL="http://192.168.1.226:3100/loki/api/v1/push"

echo "Installing Promtail for user: $PROMTAIL_USER"

# ============================
# 1. Download Promtail
# ============================
echo "[1/6] Downloading Promtail..."
cd /tmp
wget -q https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip
unzip -o promtail-linux-amd64.zip

# ============================
# 2. Install binary
# ============================
echo "[2/6] Installing Promtail binary..."
sudo mv promtail-linux-amd64 $PROMTAIL_BIN
sudo chmod +x $PROMTAIL_BIN

# ============================
# 3. Create directories
# ============================
echo "[3/6] Creating directories..."
sudo mkdir -p $PROMTAIL_DIR
sudo mkdir -p $PROMTAIL_POS
sudo chown $PROMTAIL_USER:$PROMTAIL_USER $PROMTAIL_POS
sudo chmod 700 $PROMTAIL_POS

# ============================
# 4. Generate promtail.yaml
# ============================
echo "[4/6] Writing promtail.yaml..."

sudo bash -c "cat > $PROMTAIL_DIR/promtail.yaml" <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: $PROMTAIL_POS/positions.yaml

clients:
  - url: $LOKI_URL

scrape_configs:
  - job_name: system
    static_configs:
      - targets: [localhost]
        labels:
          job: system
          host: ${HOSTNAME}
          __path__: /var/log/*log

  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          host: ${HOSTNAME}
          __path__: /var/log/syslog

  - job_name: auth
    static_configs:
      - targets: [localhost]
        labels:
          job: auth
          host: ${HOSTNAME}
          __path__: /var/log/auth.log

  - job_name: kernel
    static_configs:
      - targets: [localhost]
        labels:
          job: kernel
          host: ${HOSTNAME}
          __path__: /var/log/kern.log
EOF

# ============================
# 5. Create systemd service
# ============================
echo "[5/6] Creating systemd service..."

sudo bash -c "cat > $PROMTAIL_SERVICE" <<EOF
[Unit]
Description=Promtail Log Collector
After=network.target

[Service]
User=$PROMTAIL_USER
ExecStart=$PROMTAIL_BIN -config.file=$PROMTAIL_DIR/promtail.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ============================
# 6. Enable + start Promtail
# ============================
echo "[6/6] Starting Promtail..."
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl restart promtail

echo "======================================"
echo "Promtail installation complete!"
echo "Status: systemctl status promtail"
echo "Logs:   journalctl -u promtail -f"
echo "======================================"
