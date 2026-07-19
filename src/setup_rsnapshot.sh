#!/bin/bash -v

set -euo pipefail

apt-get install --no-install-recommends -y rsnapshot

backed_up_folder=/app/tiered-dns-server/src/

# use literal \t in the config file, but replace with actual tab characters before writing to file
# this ensures editors / git don't introduce spaces instead of tabs, which would break rsnapshot
cat > /etc/rsnapshot.conf << EOF
config_version\t1.2
snapshot_root\t${BackupLocation}/snapshots/

# If no_create_root is enabled, rsnapshot will not automatically create the
# snapshot_root directory. This is particularly useful if you are backing
# up to removable media, such as a FireWire or USB drive.
#
no_create_root\t1

#################################
# EXTERNAL PROGRAM DEPENDENCIES #
#################################

# LINUX USERS:\tBe sure to uncomment "cmd_cp". This gives you extra features.
# EVERYONE ELSE: Leave "cmd_cp" commented out for compatibility.
#
# See the README file or the man page for more details.
#
cmd_cp\t/bin/cp

# uncomment this to use the rm program instead of the built-in perl routine.
#
cmd_rm\t/bin/rm

# rsync must be enabled for anything to work. This is the only command that
# must be enabled.
#
cmd_rsync\t/usr/bin/rsync

# Comment this out to disable syslog support.
#
cmd_logger\t/usr/bin/logger

#########################################
#\tBACKUP LEVELS / INTERVALS\t#
# Must be unique and in ascending order #
# e.g. alpha, beta, gamma, etc.\t#
#########################################

retain\thourly\t24
retain\tdaily\t7
retain\tweekly\t7
retain\tmonthly\t6


############################################
#\tGLOBAL OPTIONS\t#
# All are optional, with sensible defaults #
############################################

# Verbose level, 1 through 5.
# 1\tQuiet\tPrint fatal errors only
# 2\tDefault\tPrint errors and warnings only
# 3\tVerbose\tShow equivalent shell commands being executed
# 4\tExtra Verbose\tShow extra verbose information
# 5\tDebug mode\tEverything
#
verbose\t2

# Same as "verbose" above, but controls the amount of data sent to the
# logfile, if one is being used. The default is 3.
# If you want the rsync output, you have to set it to 4
#
loglevel\t3


# If enabled, rsnapshot will write a lockfile to prevent two instances
# from running simultaneously (and messing up the snapshot_root).
# If you enable this, make sure the lockfile directory is not world
# writable. Otherwise anyone can prevent the program from running.
#
lockfile\t/var/run/rsnapshot.pid

# LOCALHOST
backup\t${backed_up_folder}\tlocalhost/
EOF

sed -e 's/\\t/\t/g' -i /etc/rsnapshot.conf

cat > /etc/cron.d/rsnapshot << EOF
0 * * * * root /usr/bin/rsnapshot hourly
50 23 * * * root /usr/bin/rsnapshot daily
40 23 * * 6 root /usr/bin/rsnapshot weekly
30 23 1 * * root /usr/bin/rsnapshot monthly
EOF

if [ mount | grep -q "${BackupLocation}" ]; then
    echo "Backup location ${BackupLocation} is already mounted."
    mkdir -p ${BackupLocation}/snapshots/
else
    echo "Backup location ${BackupLocation} is not mounted. Not making directories."
    echo "Please ensure that ${BackupLocation} is mounted before running rsnapshot."
fi

restore_script=/usr/local/bin/restore-backup
cat > ${restore_script} << EOF
#!/bin/bash

set -euo pipefail
trap 'echo "Error occurred on line $LINENO"; exit 1' ERR

backupToRestoreFrom="\$1 \$2"
srcDir="${BackupLocation}/snapshots/\${backupToRestoreFrom/ /.}"
echo "Copying '\${srcDir}' to '${backed_up_folder}'"
cp -r --dereference -f "\${srcDir}/localhost${backed_up_folder}/" "${backed_up_folder}/"

echo "Resetting tracked files"
cd ${backed_up_folder}
git checkout .

figlet "Backup restored"
EOF

chmod +x ${restore_script}