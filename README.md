# Tiered DNS Server

The objective of this project is to provide an easy stand up for a spoke-based DNS system.

## Why?

Because DNS filtering for basic trojan and malware sites is becoming a must.

## What do you mean?

```
                                 ┌─────────────────────┐
                                 │ upstream DNS server │
                                 └───────────┬─────────┘
                                             │ (DNS over HTTPS)
                                 ┌───────────▼─────────┐
             ┌───────────────────┼  tiered-dns-server  │────────────────────┐
             │                   └────────┬────────────┘                    │
             │                            │                                 │
             │                            │                                 │
             │                            │                                 │
             │                            │      (wireguard tunnels)        │
             │                            │                                 │
             │                            │                                 │
    ┌────────▼───────────┐     ┌──────────▼─────────┐         ┌─────────────▼──────┐
    │ on prem DNS server │     │ on prem DNS server │         │ on prem DNS server │
    │                    │     │                    │         │                    │
    └────────────────────┘     └────────────────────┘         └────────────────────┘
```

The objective is to provide a central server with multiple clients.
This central server should log all requests, and forward to a selected upstream (using DNS over HTTPS or DoH)

## Wait, why log everything?

The first objective in this build out is security.
Each "premise" is a location that I want to help the internet users to avoid phishing sites and malware.
Logging at the spoke level (and auditing those logs) allows the server admin to check on whether any premise has been
compromised (sites did get through that shouldn't have).

## Tech Stack

- Pi-hole used for DNS forwarding/filtering and logging
- dnscrypt-proxy (requirement from Pi-hole for DoH upstream)
- Chosen upstream DNS server (this is left to the user)
- Wireguard
  - wg-easy (admin Web UI)
- Cloudflare 0 Trust tunnel (in Docker)
  used for secure access to management without opening ports
- Automated backups of config using RSnapshot

## Why not (some favorite other project)?

In short, I'm building this for me and the premises I'm trying to make life easier and more secure for.
I will spare you the details on many of the choices in this tech stack, but if you would like to make a case for an alternative being a better option, feel free to open a Discussion.

## How is this tiered?

If an account is made with the upstream DNS server, it can be configured to do filtering (or use a DNS server that offers filtering already).
Running Pi-hole at this level allows for a second layer of shared filtering.
Finally, the on-prem nodes are also able to filter their own lists (without forwarding).

Ergo, there are 3 tiers of filtering in a standard deployment.


## Deploying

Example stack script to deploy on Linode (NOTE: for convenience, some secrets are added to this script, do NOT make public)
```bash
#!/bin/bash
#<UDF name="TOKEN_PASSWORD" label="Api token for attaching volume">
#<UDF name="restore_backup" label="Backup to restore from (optional)" example="hourly 1" default="">
#<UDF name="git_branch" label="Git Branch for source" default="main">

set -euo pipefail
trap 'echo "Error occurred on line $LINENO"; exit 1' ERR

exec > >(tee -i /var/log/stackscript_1.log)

# ================================================================
# Set config vars needed in core script
# ================================================================

export hostname=dns_hub
export fqdn=pihole.dns_hub.lan
export ClientNames=comma,separate,list-of-names,to,generate-configs-for
export BackupLocation=/mnt/tiered_dns_backup
export restore_backup="${restore_backup:-}"
export HTTP_PREFIX=""
export PIHOLE_WEBPASSWORD="..." # TODO: set this
export GIT_BRANCH="${git_branch:-main}"
export TZ=UTC
export WIREGUARD_PORT=... # TODO: pick a random port. Suggestion: python3 -c "import string, secrets; print(''.join(secrets.choice(string.digits) for _ in range(4)))"

# set time zone
timedatectl set-timezone ${TZ}

# ================================================================
# Attach and mount backup storage - used for persistent keys and back ups across deployments
# ================================================================

# pre-requisite
. <ssinclude StackScriptID="1">

. <ssinclude StackScriptID="632759">

# TODO: set this to the ID of the desired volume to attach
backupVolumeName=dns-hub-backup

attach_volume ${backupVolumeName}

cat >> /etc/fstab <<EOF
/dev/disk/by-id/scsi-0Linode_Volume_${backupVolumeName} ${BackupLocation} ext4 defaults,noatime,nofail 0 2
EOF

systemctl daemon-reload
mkdir -p ${BackupLocation}

volume_label="${backupVolumeName}"
mount_point="${BackupLocation}"
volume_path="$(
        get_volume_property "$volume_label" 'filesystem_path' | sed 's/"//g'
)"

echo "Expecting drive to exist at $volume_path"

wait_for_volume() {
# Wait for the volume to become available before proceeding
local x=20

while [ $x -gt 0 ]; do
  if [ -e $volume_path ]; then
     return
  else
    sleep 1
  fi
  ((x-=1))
done
}

wait_for_volume

if [ ! -e $volume_path ]; then
echo "- - -" | sudo tee /sys/class/scsi_host/host*/scan
wait_for_volume
fi

if [ ! -e $volume_path ]; then
echo "Drive still not attached!"
exit 1
fi

mount -a

sleep 1

# check that it is actually mounted
mountpoint ${BackupLocation} || exit 1

# ================================================================
# Include core
# ================================================================
# apparently there's nothing "stacked" about these...
echo <ssinclude StackScriptID="1">
echo <ssinclude StackScriptID="632759">
echo <ssinclude StackScriptID="2165897">

<ssinclude StackScriptID="2165897">


figlet Success
```
