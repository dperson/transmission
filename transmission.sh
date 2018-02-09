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

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -n          No auth config; don't configure authentication at runtime

The 'command' (if provided and valid) will be run instead of transmission
" >&2
    exit $RC
}

while getopts ":hn" opt; do
    case "$opt" in
        h) usage ;;
        n) export NOAUTH=true ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o transmission
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]]&& groupmod -g $GROUPID -o transmission
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
                --foreground --log-info --no-portmap \
                $([[ ${NOAUTH:-""} ]] && echo '--no-auth' || echo "--auth \
                --username ${TRUSER:-admin} --password ${TRPASSWD:-admin}")"
fi