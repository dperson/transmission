[![logo](https://raw.githubusercontent.com/dperson/transmission/master/logo.png)](https://www.transmissionbt.com/)

# Transmission

Transmission docker container

# What is Transmission?

Transmission is a BitTorrent client which features a simple interface on top of
a cross-platform back-end.

# How to use this image

This Transmission container was built to automatically download a level1 host
filter (can be used with dperson/openvpn).

    sudo docker run -it --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
                --dns 8.8.4.4 --dns 8.8.8.8 --restart=always \
                -d dperson/openvpn-client ||
    sudo docker run -it --name bit --net=container:vpn \
                -d dperson/transmission
    sudo docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
                -d dperson/nginx -w "http://bit:9091/transmission;/transmission"

**NOTE**: The default username/password are `admin`/`admin`. See `TRUSER` and
`TRPASSWD` below, for how to change them.

**NOTE2**: To connect to the transmission container, point your browser to the
actual `<hostname_or_IP_address>` of the system running docker with a URI as
below:

    https://<hostname_or_IP_address>/transmission/web/

**NOTE3**: To open the peer connection port add the following to the
`docker run` command:

    -p 51413:51413 -p 51413:51413/udp

## Hosting a Transmission instance

    sudo docker run -it --name transmission -p 9091:9091 -d dperson/transmission

OR set local storage (see *Complex configuration* below):

    sudo docker run -it --name transmission -p 9091:9091 \
                -v /path/to/directory:/var/lib/transmission-daemon \
                -d dperson/transmission

**NOTE**: The configuration is in `/var/lib/transmission-daemon/info`, downloads
are in `/var/lib/transmission-daemon/downloads`, and partial downloads are in
`/var/lib/transmission-daemon/incomplete`.

## Configuration

    sudo docker run -it --rm dperson/transmission -h

    Usage: transmission.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -n          No auth config; don't configure authentication at runtime
        -t ""       Configure timezone
                    possible arg: "[timezone]" - zoneinfo timezone for container

    The 'command' (if provided and valid) will be run instead of transmission

ENVIRONMENT VARIABLES

 * `TRUSER` - Set the username for transmission auth (default 'admin')
 * `TRPASSWD` - Set the password for transmission auth (default 'admin')
 * `TZ` - Configure the zoneinfo timezone, IE `EST5EDT`
 * `USERID` - Set the UID for the app user
 * `GROUPID` - Set the GID for the app user

Other environment variables beginning with `TR_` will edit the configuration
file accordingly:

 * `TR_MAX_PEERS_GLOBAL=400` will translate to `"max-peers-global": 400,`

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec -it transmission transmission.sh` (as of version 1.3 of docker).

### Setting the Timezone

    sudo docker run -it --name transmission -e TZ=EST5EDT \
                -d dperson/transmission

## Complex configuration

If you wish to adapt the default configuration, use something like the following
to copy it from a running container:

    sudo docker cp transmission:/var/lib/transmission-daemon /some/path

You can use the modified configuration with:

    sudo docker run -it --name transmission -p 9091:9091 \
                -v /some/path:/var/lib/transmission-daemon -d dperson/transmission

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/transmission/issues).