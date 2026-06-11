#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENTRYPOINT="$SCRIPT_DIR/docker/ros_entrypoint.sh"
DEFAULT_MASTER_IP=192.168.0.101

get_ip()  { hostname -I | awk '{print $1}'; }
get_os()  { grep -w ID /etc/os-release | cut -d= -f2 | tr -d '"'; }
has_gpu() { command -v nvidia-smi &>/dev/null && echo gpu || echo cpu; }

firewall() {
    case "$1" in
        ubuntu) sudo ufw allow from 192.168.0.0/24 ;;
        fedora) sudo firewall-cmd --zone=trusted --add-source=192.168.0.0/24 --permanent && sudo firewall-cmd --reload ;;
    esac
} &>/dev/null

master_roscore() {
    # Append roscore auto-start if not already added or it is commented out
    grep -qP '^\s*exec roscore' "$ENTRYPOINT" 2>/dev/null && return
    cat >> "$ENTRYPOINT" <<'EOF'

# Auto-start roscore (master role)
exec roscore
EOF
}

setup() {
    local my_ip="$1"
    echo "IP: $my_ip"
    echo "1) Master  2) Simulator  3) Controller"
    read -rp "Role [1/2/3]: " role

    local role_name master_ip ros_cmd
    # Master IP is set via DHCP reservation in your router, change DEFAULT_MASTER_IP if needed
    case "$role" in
        1) role_name=master;  master_ip="$my_ip" ;;
        2) role_name=sim;     master_ip=$DEFAULT_MASTER_IP ;;
        3) role_name=control; master_ip=$DEFAULT_MASTER_IP ;;
        *) echo "Invalid role" >&2; exit 1 ;;
    esac

    if [ "$role" != "1" ]; then
        read -rp "Master IP [$master_ip]: " inp
        master_ip="${inp:-$master_ip}"
        ping -c1 -W2 "$master_ip" &>/dev/null || { echo "Cannot reach $master_ip" >&2; exit 1; }
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<EOF
ROS_MASTER_URI=http://${master_ip}:11311
ROS_IP=${my_ip}
ROLE=${role_name}
COMPOSE_PROFILES=$(has_gpu)
EOF

    [ "$role" = "1" ] && master_roscore

    firewall "$(get_os)"
    echo "Saved $ENV_FILE"
}

if [ -f "$ENV_FILE" ]; then
    existing_role=$(grep -oP '(?<=^ROLE=)\w+' "$ENV_FILE")
    if [ "$existing_role" = "control" ]; then
        read -rp "Override existing config? [y/N]: " ov
        [[ "$ov" =~ ^[Yy]$ ]] && cp "$ENV_FILE" "${ENV_FILE}.bak" && setup "$(get_ip)"
    fi
fi

xhost +local:docker &>/dev/null
docker compose --env-file "$ENV_FILE" -f "$SCRIPT_DIR/docker-compose.yaml" up -d --build
