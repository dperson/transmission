#!/usr/bin/env bash
#===============================================================================
#          FILE: transmission.sh
#
#         USAGE: ./transmission.sh
#
#   DESCRIPTION: Entrypoint for transmission docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#  ORGANIZATION:
#       CREATED: 09/28/2014 12:11
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

dir="/var/lib/transmission-daemon"

### timezone: Set the timezone for the container
# Arguments:
#   timezone) for example EST5EDT
# Return: the correct zoneinfo file will be symlinked into place
timezone() { local timezone="${1:-EST5EDT}"
    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified" >&2
        return
    }

    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC=${1:-0}
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -t \"\"       Configure timezone
                possible arg: \"[timezone]\" - zoneinfo timezone for container

The 'command' (if provided and valid) will be run instead of transmission
" >&2
    exit $RC
}

cd /tmp

while getopts ":ht:" opt; do
    case "$opt" in
        h) usage ;;
        t) timezone "$OPTARG" ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${TIMEZONE:-""}" ]] && timezone "$TIMEZONE"

[[ -d $dir/downloads ]] || mkdir -p $dir/downloads
[[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete
[[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists
chown -Rh debian-transmission. $dir

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v 'grep|transmission.sh' | grep -q transmission; then
    echo "Service already running, please restart container to apply changes"
else
    curl -Ls 'http://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz' |
                gzip -cd > $dir/info/blocklists/bt_level1
    chown debian-transmission. $dir/info/blocklists/bt_level1
    grep -q peer-socket-tos $dir/info/settings.json ||
        sed -i '/"peer-port"/a \
    "peer-socket-tos": "lowcost",' $dir/info/settings.json
    sed -i '/"queue-stalled-enabled"/s/:.*/: true,/' $dir/info/settings.json
    sed -i '/"speed-limit-up"/s/:.*/: 10,/' $dir/info/settings.json
    sed -i '/"speed-limit-up-enabled"/s/:.*/: true,/' $dir/info/settings.json
    exec su -l debian-transmission -s /bin/bash -c "exec transmission-daemon \
                --config-dir $dir/info --blocklist --encryption-preferred \
                --log-error -e /dev/stdout --global-seedratio 2.0 --dht \
                --incomplete-dir $dir/incomplete --paused --auth --foreground \
                --username '${TRUSER:-admin}' --password '${TRPASSWD:-admin}' \
                --download-dir $dir/downloads --no-portmap --allowed \\* 2>&1"
fi
