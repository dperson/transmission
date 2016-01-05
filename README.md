[![logo](https://raw.githubusercontent.com/dperson/transmission/master/logo.png)](https://www.transmissionbt.com/)

# Transmission

Transmission docker container

# What is Transmission?

Transmission is a BitTorrent client which features a simple interface on top of
a cross-platform back-end.

# How to use this image

This Transmission container was built to automatically download a level1 host
filter (can be used with dperson/openvpn).

    sudo docker run --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
                --dns 8.8.4.4 --dns 8.8.8.8 --restart=always \
                -d dperson/openvpn-client ||
    sudo docker run --name bit --net=container:vpn \
                -d dperson/transmission
    sudo docker run --name web -p 80:80 -p 443:443 --link vpn:bit \
                -d dperson/nginx -w "http://bit:9091/transmission;/transmission"

## Hosting a Transmission instance

    sudo docker run --name transmission -p 9091:9091 -d dperson/transmission

OR set local storage:

    sudo docker run --name transmission -p 9091:9091 \
                -v /path/to/directory:/var/lib/transmission-daemon/downloads \
                -d dperson/transmission

**NOTE**: The configuration is in `/var/lib/transmission-daemon/info`, downloads
are in `/var/lib/transmission-daemon/downloads`, and partial downloads are in
`/var/lib/transmission-daemon/incomplete`.

## Configuration

    sudo docker run -it --rm dperson/transmission -h

    Usage: transmission.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -t ""       Configure timezone
                    possible arg: "[timezone]" - zoneinfo timezone for container

    The 'command' (if provided and valid) will be run instead of transmission

ENVIRONMENT VARIABLES (only available with `docker run`)

 * `TRUSER` - Set the username for transmission auth (default 'admin')
 * `TRPASSWD` - Set the password for transmission auth (default 'admin')
 * `TZ` - As above, configure the zoneinfo timezone, IE `EST5EDT`
 * `USERID` - Set the UID for the app user
 * `GROUPID` - Set the GID for the app user

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec transmission.sh` (as of version 1.3 of docker).

### Setting the Timezone

    sudo docker run --name transmission -d dperson/transmission -t EST5EDT

OR using `environment variables`

    sudo docker run --name transmission -e TZ=EST5EDT -d dperson/transmission

Will get you the same settings as

    sudo docker run --name transmission -p 9091:9091 -d dperson/transmission
    sudo docker exec transmission transmission.sh -t EST5EDT \
                ls -AlF /etc/localtime
    sudo docker restart transmission

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/transmission/issues).
