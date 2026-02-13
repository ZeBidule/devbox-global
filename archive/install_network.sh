#!/bin/bash
set -e

BACKUP_FOLDER=/mnt/d/sharedfolder
WSL_VPNKIT_VERSION=0.4.1
GOST_VERSION=3.2.6

# stop services if they are already installed
systemctl stop wsl-vpnkit || true
systemctl stop gost || true
systemctl stop cntlm || true

sleep 2

# add universe repository for cntlm
sudo add-apt-repository universe -y
sudo apt-get update -y

# install dependencies
sudo apt-get install iproute2 iptables iputils-ping dnsutils wget curl bzip2 git cntlm -y

# ----------------------------------------------------
# download wsl-vpnkit and unpack
# ----------------------------------------------------
mkdir -p /wsl-vpnkit
cd /wsl-vpnkit
wget https://github.com/sakai135/wsl-vpnkit/releases/download/v$WSL_VPNKIT_VERSION/wsl-vpnkit.tar.gz
tar --strip-components=1 -xf wsl-vpnkit.tar.gz \
    app/wsl-vpnkit \
    app/wsl-gvproxy.exe \
    app/wsl-vm \
    app/wsl-vpnkit.service
rm wsl-vpnkit.tar.gz

cat <<EOF > /etc/systemd/system/wsl-vpnkit.service
[Unit]
Description=wsl-vpnkit
#After=network.target
After=gost.service
Before=network-online.target

[Service]
ExecStart=/wsl-vpnkit/wsl-vpnkit
Environment=VMEXEC_PATH=/wsl-vpnkit/wsl-vm GVPROXY_PATH=/wsl-vpnkit/wsl-gvproxy.exe

Restart=always
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /usr/local/sbin/redsocks-iptables
#!/bin/bash
set -e

if [[ \$EUID -ne 0 ]]
then
        echo 'This script must be run as root' 1>&2
        exit 1
fi

case "\$1" in
set)
        iptables-save | grep -v REDSOCKS | iptables-restore

        iptables -w -t nat -N REDSOCKS
        iptables -w -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 199.19.250.205/32 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 199.19.248.205/32 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
        iptables -w -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
        iptables -w -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345

        iptables -w -t nat -A OUTPUT -p tcp -j REDSOCKS
        iptables -w -t nat -A PREROUTING -s 172.16.0.0/12 -p tcp -j REDSOCKS # Docker networks
        ;;

unset)
        iptables-save | grep -v REDSOCKS | iptables-restore
        ;;

*)
        echo "Usage: \$0 set|unset" 1>&2
        exit 1
        ;;
esac
EOF
chmod +x /usr/local/sbin/redsocks-iptables

# ----------------------------------------------------
# download gost and unpack
# ----------------------------------------------------
cd "$(mktemp -d)"
wget https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_amd64.tar.gz
tar -xvf gost_${GOST_VERSION}_linux_amd64.tar.gz gost
rm gost_${GOST_VERSION}_linux_amd64.tar.gz
sudo mv gost /usr/bin/
sudo chmod +x /usr/bin/gost

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=Gost transparent proxy redirector
Requires=cntlm.service
After=cntlm.service

[Service]
ExecStart=/usr/bin/gost -L=redirect://127.0.0.1:12345 -F=socks5://127.0.0.1:8010
ExecStartPost=/usr/local/sbin/redsocks-iptables set
ExecStop=/usr/local/sbin/redsocks-iptables unset

[Install]
WantedBy=multi-user.target
EOF

# ----------------------------------------------------
# import your previous cntlm config file from your backup folder
# ----------------------------------------------------
cp "$BACKUP_FOLDER/cntlm.conf" /etc/cntlm.conf


# ----------------------------------------------------
# reload systemd and start services
# ----------------------------------------------------
systemctl daemon-reload
systemctl restart wsl-vpnkit gost cntlm

systemctl enable wsl-vpnkit gost cntlm

systemctl status wsl-vpnkit gost cntlm
