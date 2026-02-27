#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="klaudimero"
VENV_DIR="$REPO_DIR/.venv"
PORT="${KLAUDIMERO_PORT:-8585}"
USER="$(whoami)"

echo "Installing Klaudimero service..."
echo "  Repo:    $REPO_DIR"
echo "  User:    $USER"
echo "  Port:    $PORT"
echo ""

# Create venv and install dependencies
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

echo "Installing dependencies..."
"$VENV_DIR/bin/pip" install -q -r "$REPO_DIR/requirements.txt"

# Create storage directory
mkdir -p "$HOME/.klaudimero/jobs" "$HOME/.klaudimero/executions"

# Generate systemd unit file
UNIT_FILE="/etc/systemd/system/$SERVICE_NAME.service"
echo "Writing systemd unit to $UNIT_FILE..."

sudo tee "$UNIT_FILE" > /dev/null <<EOF
[Unit]
Description=Klaudimero - Claude Code Cron Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$REPO_DIR
ExecStart=$VENV_DIR/bin/uvicorn klaudimero.main:app --host 0.0.0.0 --port $PORT
Restart=on-failure
RestartSec=5
Environment=HOME=$HOME
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

echo ""
echo "Klaudimero installed and running on port $PORT"
echo ""
echo "  Start:   sudo systemctl start klaudimero"
echo "  Stop:    sudo systemctl stop klaudimero"
echo "  Status:  sudo systemctl status klaudimero"
echo "  Logs:    journalctl -u klaudimero -f"
