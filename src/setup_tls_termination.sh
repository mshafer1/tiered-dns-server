#!/bin/bash -v
set -euo pipefail

#TODO: renovate update this?
(pushd /tmp/
wget https://github.com/DNSCrypt/doh-server/releases/download/0.11.1/doh-proxy_0.11.1-1_amd64.deb
apt-get install -y ./doh-proxy_0.11.1-1_amd64.deb
popd)

DEBIAN_FRONTEND=noninteractive apt-get install -y nginx gettext-base pipx

force="${TLS_RESETUP_FORCE:-}"
source_dir=$(dirname $0)

# region: render templates
if [ -f /etc/nginx/sites-enabled/pihole ] && [ -z "${force}" ]; then
    echo "Skipping rendering nginx config to avoid resetting it"
    echo "use TLS_RESETUP_FORCE=t to force"
else
    # only replace FQDN and HTTP_PREFIX
    envsubst '${FQDN} ${HTTP_PREFIX}' < ${source_dir}/templates/nginx.conf > /etc/nginx/sites-enabled/pihole
fi


envsubst '${FQDN}' < ${source_dir}/templates/doh-server.conf > /etc/dns-over-https/doh-server.conf
# endregion

# region: start up doh-server
systemctl enable doh-server
systemctl start doh-server
# endregion

# region: TLS config
export PIPX_BIN_DIR=/usr/local/bin
pipx install --force certbot

if which certbot; then
    echo "Certbot is installed"
else
    echo "Error: Certbot failed to install"
    exit 1
fi
 
certbot_bin=$(command -v certbot)
cat > /etc/cron.d/certbot-renew <<EOF
17 6 2,14 * * root ${certbot_bin} renew --quiet --deploy-hook "/usr/sbin/nginx -t && /usr/bin/systemctl reload nginx"
EOF
 

pipx inject certbot certbot-nginx || true # pipx considers already installed a failure


mkdir -p /etc/letsencrypt
wget -O /etc/letsencrypt/acme-dns-auth.py https://github.com/mshafer1/acme-dns-certbot-joohoi/raw/refs/heads/master/acme-dns-auth.py
chmod +x /etc/letsencrypt/acme-dns-auth.py

export ACME_DNS_USE_MTLS=${ACME_DNS_USE_MTLS:-true}
export HTTP_PREFIX=${HTTP_PREFIX:-40}

if [ ! -f /etc/letsencrypt/conf.json ] || [ -n "${force}" ]; then
    # replace only ${ACME_DNS_USE_MTLS} and ${ACME_DNS_URL}
    mkdir -p /etc/letsencrypt
    envsubst '${ACME_DNS_USE_MTLS} ${ACME_DNS_URL}' < ${source_dir}/templates/acme-dns-conf.json > /etc/letsencrypt/conf.json
    # trigger registration / CNAME prompt
    echo "#######"
    CERTBOT_DOMAIN=${FQDN} CERTBOT_VALIDATION=placeholder /etc/letsencrypt/acme-dns-auth.py

    echo "Once DNS records are set, run the following command to register with acme-dns:"
    echo "certbot --nginx -v --non-interactive --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
        --preferred-challenges dns --no-redirect --debug-challenges -d ${FQDN}"
    echo "#######"
else
    echo "Skipping rendering acme-dns config to avoid resetting it"
    echo "use TLS_RESETUP_FORCE=t to force"
fi

if [[ "${ACME_DNS_USE_MTLS}" == "true" ]] && [ ! -f /etc/letsencrypt/client.crt ]; then
    echo "MTLS is enabled but mTLS certificate for ${ACME_DNS_URL} does not exist"
    exit 1
fi

# check if cert exists
if [ -f /etc/letsencrypt/live/${FQDN}/fullchain.pem ]; then
    echo "TLS certificate for ${FQDN} exists"
    nginx -t
    systemctl reload nginx
else
    echo "TLS certificate for ${FQDN} does not exist. Please run certbot to obtain it. (skipping nginx reload)"
fi
# end region
