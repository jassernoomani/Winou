#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu server (Oracle Cloud "Always Free" ARM). Run as the default
# "ubuntu" user, from the repo root:
#
#   deploy/setup-server.sh <duckdns subdomain> <duckdns token>
#
# Installs Docker, opens ports 80 and 443 in the server's own firewall (Oracle's Ubuntu images
# block them even when the cloud firewall allows them), keeps the DuckDNS name pointing here,
# and schedules a nightly database backup.
set -euo pipefail

subdomain=${1:?usage: deploy/setup-server.sh <duckdns subdomain> <duckdns token>}
token=${2:?usage: deploy/setup-server.sh <duckdns subdomain> <duckdns token>}
repo=$(pwd)

echo "== Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

echo "== Firewall: allow HTTP and HTTPS"
for port in 80 443; do
  if ! sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport "$port" -j ACCEPT
  fi
done
sudo apt-get install -y netfilter-persistent iptables-persistent >/dev/null
sudo netfilter-persistent save

echo "== DuckDNS: $subdomain.duckdns.org -> this server, refreshed every 5 minutes"
mkdir -p ~/duckdns
cat > ~/duckdns/update.sh <<EOF
#!/usr/bin/env bash
curl -fsS "https://www.duckdns.org/update?domains=$subdomain&token=$token&ip=" -o ~/duckdns/last.log
EOF
chmod 700 ~/duckdns/update.sh
~/duckdns/update.sh
echo "DuckDNS answered: $(cat ~/duckdns/last.log)"

echo "== Nightly backup at 03:00"
( crontab -l 2>/dev/null | grep -v -e duckdns/update.sh -e deploy/backup.sh || true
  echo "*/5 * * * * ~/duckdns/update.sh"
  echo "0 3 * * * cd $repo && deploy/backup.sh >> ~/backups/backup.log 2>&1"
) | crontab -
mkdir -p ~/backups

echo
echo "Done. Log out and back in (so your user can run docker), then follow deploy/README.md."
