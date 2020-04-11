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
[[ -d $dir/downloads ]] || mkdir -p $dir/downloads
[[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete
[[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists
[[ -r $dir/info/settings.json ]] || cat >$dir/info/settings.json <<-EOF
	{
	    "blocklist-enabled": 0,
	    "dht-enabled": true,
	    "download-dir": "/var/lib/transmission-daemon/downloads",
	    "incomplete-dir": "/var/lib/transmission-daemon/incomplete",
	    "incomplete-dir-enabled": true,
	    "download-limit": 100,
	    "download-limit-enabled": 0,
	    "encryption": 1,
	    "max-peers-global": 200,
	    "peer-port": 51413,
	    "peer-socket-tos": "lowcost",
	    "pex-enabled": 1,
	    "port-forwarding-enabled": 0,
	    "queue-stalled-enabled": true,
	    "ratio-limit-enabled": true,
	    "rpc-authentication-required": 1,
	    "rpc-password": "transmission",
	    "rpc-port": 9091,
	    "rpc-username": "transmission",
	    "rpc-whitelist": "127.0.0.1",
	    "upload-limit": 100,
	    "upload-limit-enabled": 0
	}
	EOF

### timezone: Set the timezone for the container
# Arguments:
#   timezone) for example EST5EDT
# Return: the correct zoneinfo file will be symlinked into place
timezone() { local timezone="${1:-EST5EDT}"
    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified: $timezone" >&2
        return
    }

    if [[ -w /etc/timezone && $(cat /etc/timezone) != $timezone ]]; then
        echo "$timezone" >/etc/timezone
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    fi
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -n          No auth config; don't configure authentication at runtime
    -t \"\"       Configure timezone
                possible arg: \"[timezone]\" - zoneinfo timezone for container

The 'command' (if provided and valid) will be run instead of transmission
" >&2
    exit $RC
}

while getopts ":hnt:" opt; do
    case "$opt" in
        h) usage ;;
        n) export NOAUTH=true ;;
        t) timezone $OPTARG ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o transmission
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]]&& groupmod -g $GROUPID -o transmission
[[ "${TZ:-""}" ]] && timezone $TZ
for env in $(printenv | grep '^TR_'); do
    name="$(cut -c4- <<< ${env%%=*} | tr '_A-Z' '-a-z')"
    val="\"${env##*=}\""
    [[ "$val" =~ ^\"([0-9]+|false|true)\"$ ]] && val="$(sed 's|"||g' <<< $val)"
    sed -i 's|\([0-9A-Za-z"]\)$|\1,|' $dir/info/settings.json
    if grep -q "\"$name\"" $dir/info/settings.json; then
        sed -i "/\"$name\"/s|:.*|: $val,|" $dir/info/settings.json
    else
        sed -i "/^}/i\    \"$name\": $val," $dir/info/settings.json
    fi
    sed -rzi 's/,([^,]*)$/\1/' $dir/info/settings.json
done

watchdir="$(awk -F'=' '/"watch-dir"/ {print $2}' $dir/info/settings.json |
            sed 's/[,"]//g')"
[[ -d $dir/downloads ]] || mkdir -p $dir/downloads
[[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete
[[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists
[[ $watchdir && ! -d $watchdir ]] && mkdir -p $watchdir

chown -Rh transmission. $dir 2>&1 | grep -iv 'Read-only' || :
# Ensure su is owned by root to avoid setgid issues when using user namespaces in daemon
chown root:root /bin/su

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v 'grep|transmission.sh' | grep -q transmission; then
    echo "Service already running, please restart container to apply changes"
else
    if [[ -z $(find $dir/info/blocklists/bt_level1 -mmin -1080 2>&-) && \
                "${BLOCKLIST:-""}" != "no" ]]; then
        # Initialize blocklist
        url='http://list.iblocklist.com'
        curl -Ls "$url"'/?list=bt_level1&fileformat=p2p&archiveformat=gz' |
                    gzip -cd >$dir/info/blocklists/bt_level1
        chown transmission. $dir/info/blocklists/bt_level1
    fi
    exec su -l transmission -s /bin/bash -c "exec transmission-daemon \
                --allowed \\* --blocklist --config-dir $dir/info \
                --foreground --log-error --no-portmap \
                $([[ ${NOAUTH:-""} ]] && echo '--no-auth' || echo "--auth \
                --username ${TRUSER:-admin} --password ${TRPASSWD:-admin}")"
fi