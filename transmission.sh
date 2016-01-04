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
        echo "ERROR: invalid timezone specified: $timezone" >&2
        return
    }

    if [[ $(cat /etc/timezone) != $timezone ]]; then
        echo "$timezone" >/etc/timezone
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    fi
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

[[ "${TZ:-""}" ]] && timezone "$TZ"
[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o debian-transmission
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]]&& groupmod -g $GROUPID -o debian-transmission

[[ -d $dir/downloads ]] || mkdir -p $dir/downloads
[[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete
[[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists

chown -Rh debian-transmission. $dir 2>&1 | grep -iv 'Read-only' || :

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v 'grep|transmission.sh' | grep -q transmission; then
    echo "Service already running, please restart container to apply changes"
else
    # init blocklist
    url='http://list.iblocklist.com'
    curl -Ls "$url"'/?list=bt_level1&fileformat=p2p&archiveformat=gz' |
                gzip -cd >$dir/info/blocklists/bt_level1
    chown debian-transmission. $dir/info/blocklists/bt_level1

    settings_file=$dir/info/settings.json

    # settings
    for env in $(printenv); do
        name=$(echo -n $env | cut -d= -f1)
        val=$(echo -n $env | cut -d= -f2)

        echo $name | grep -v '^TR_' > /dev/null && continue

        # handled via command line
        case $name in
            TR_USER | TR_PASSWD) continue ;;
        esac

        tr_name=$(echo -n $name | cut -c4- | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
        grep $tr_name $settings_file > /dev/null
        is_present=$?

        tr_value="\"$val\""
        case $val in
            true) tr_value="true" ;;
            false) tr_value="false" ;;
        esac
        echo -n $val | grep -P '^\d+$' > /dev/null && tr_value=$val

        if [ $is_present -eq 0 ]; then
            sed -i "/\"$tr_name\"/s/:.*/: $tr_value,/" $settings_file
        else
            sed -i "/^{/a \"$tr_name\": $tr_value," $settings_file
        fi
    done

    exec su -l debian-transmission -s /bin/bash -c "exec transmission-daemon \
                --config-dir $dir/info --blocklist --encryption-preferred \
                --log-error -e /dev/stdout --dht \
                --incomplete-dir $dir/incomplete --auth --foreground \
                --username '${TR_USER:-${TRUSER:-admin}}' \
                --password '${TR_PASSWD:-${TRPASSWD:-admin}}' \
                --download-dir $dir/downloads --no-portmap --allowed \\* 2>&1"
fi
