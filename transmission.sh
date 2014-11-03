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
timezone() {
    local timezone="${1:-EST5EDT}"

    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified" >&2
        return
    }

    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
}

### vpn: setup openvpn client
# Arguments:
#   server) VPN GW server
#   user) user name on VPN
#   pass) password on VPN
# Return: configured .ovpn file
vpn() {
    local server="$1"
    local user="$2"
    local pass="$3"
    local conf="$dir/vpn.conf"
    local auth="$dir/vpn.auth"

    cat > $conf << EOF
client
dev tun
proto udp
remote $server 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca $dir/vpn-ca.crt
tls-client
remote-cert-tls server
auth-user-pass
comp-lzo
verb 1
reneg-sec 0
redirect-gateway def1
auth-user-pass $auth
log /dev/stdout
daemon
EOF

    echo "$user" > $auth
    echo "$pass" >> $auth

    chown debian-transmission. $dir/vpn*
    chmod 0600 $auth
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() {
    local RC=${1:-0}

    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -t \"\"       Configure timezone
                possible arg: \"[timezone]\" - zoneinfo timezone for container
    -v \"<server;user;password>\" Configure OpenVPN
                required arg: \"<server>;<user>;<password>\"
                <server> to connect to
                <user> to authenticate as
                <password> to authenticate with

The 'command' (if provided and valid) will be run instead of transmission
" >&2
    exit $RC
}

while getopts ":ht:v:" opt; do
    case "$opt" in
        h) usage ;;
        t) timezone "$OPTARG" ;;
        v) eval vpn $(sed 's/^\|$/"/g; s/;/" "/g' <<< $OPTARG) ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${TIMEZONE:-""}" ]] && timezone "$TIMEZONE"
[[ "${VPN:-""}" ]] && eval vpn $(sed 's/^\|$/"/g; s/;/" "/g' <<< $VPN)

[[ -d $dir/downloads ]] || mkdir -p $dir/downloads
[[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete
[[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists
chown -Rh debian-transmission. $dir

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
else
    [[ -e $dir/vpn-ca.crt ]] && openvpn --config $dir/vpn.conf
    curl -Ls 'http://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz' |
                gzip -cd > $dir/info/blocklists/bt_level1
    chown debian-transmission. $dir/info/blocklists/bt_level1
    exec transmission-daemon --foreground  --config-dir $dir/info --blocklist \
                --encryption-preferred --log-error --global-seedratio 2.0 \
                --incomplete-dir $dir/incomplete --paused --dht --auth \
                --username "${TRUSER:-admin}" --password "${TRPASSWD:-admin}" \
                --download-dir $dir/downloads --no-portmap --allowed "*" \
                --logfile /dev/stdout
fi
