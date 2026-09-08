#!/bin/bash -v
set -euo pipefail

apt-get install -y nginx doh-server gettext-base pipx

force="${TLS_RESETUP_FORCE:-}"
source_dir=$(dirname $0)

# region: render templates
if [ -f /etc/nginx/sites-available/pihole ] && [ -z "${force}" ]; then
    echo "Skipping rendering nginx config to avoid resetting it"
    echo "use TLS_RESETUP_FORCE=t to force"
else
    envsubst < ${source_dir}/templates/nginx.conf > /etc/nginx/sites-enabled/pihole
fi


envsubst < ${source_dir}/templates/doh-server.conf > /etc/dns-over-https/doh-server.conf
# endregion

# region: start up doh-server
systemctl enable doh-server
systemctl start doh-server
# endregion

# region: TLS config
pipx install certbot || true # pipx considers already installed a failure

if which certbot; then
    echo "Certbot is installed"
else
    echo "Error: Certbot failed to install"
    exit 1
fi

pipx inject certbot certbot-nginx || true # pipx considers already installed a failure


wget -O /etc/letsencrypt/acme-dns-auth.py https://github.com/mshafer1/acme-dns-certbot-joohoi/raw/refs/heads/master/acme-dns-auth.py
chmod +x /etc/letsencrypt/acme-dns-auth.py

export ACME_DNS_USE_MTLS=${ACME_DNS_USE_MTLS:-true}
export HTTP_PREFIX=${HTTP_PREFIX:-40}

if [ -f /etc/letsencrypt/conf.json ] && [ -z "${force}" ]; then
    echo "Skipping rendering acme-dns config to avoid resetting it"
    echo "use TLS_RESETUP_FORCE=t to force"
else
    envsubst < ${source_dir}/templates/acme-dns-conf.json > /etc/letsencrypt/conf.json
    # trigger registration / CNAME prompt
    echo "#######"
    CERTBOT_DOMAIN=${FQDN} CERTBOT_VALIDATION=placeholder /etc/letsencrypt/acme-dns-auth.py

    echo "Once DNS records are set, run the following command to register with acme-dns:"
    echo "certbot -v --nginx -d ${FQDN} --agree-tos --non-interactive --cert-name ${FQDN} --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns"
    echo "certbot --nginx -v --non-interactive --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
        --preferred-challenges dns --no-redirect --debug-challenges -d ${FQDN}"
    echo "#######"
fi

if [[ "${ACME_DNS_USE_MTLS}" == "true" ]] && [ ! -f /etc/letsencrypt/client.crt ]; then
    echo "MTLS is enabled but mTLS certificate for ${ACME_DNS_URL} does not exist"
    exit 1
fi

# check if cert exists
if [ -f /etc/letsencrypt/live/${FQDN}/fullchain.pem ]; then
    echo "TLS certificate for ${FQDN} already exists"
    nginx -t
    systemctl reload nginx
else
    echo "TLS certificate for ${FQDN} does not exist. Please run certbot to obtain it. (skipping nginx reload)"
fi
# end region
