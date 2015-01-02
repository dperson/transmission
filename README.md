[![logo](http://blogmmix.ch/sites/default/files/imagecache/gross/6/transmission-bittorrent1.png)](https://www.transmissionbt.com)

# Transmission / OpenVPN

Transmission and OpenVPN docker container

# What is Transmission?

Transmission is a BitTorrent client which features a simple interface on top of
a cross-platform back-end.

# How to use this image

This Transmission container was built to automatically download a level1 host
filter, and has openvpn available.

## Hosting a Transmission instance

    sudo docker run --name transmission -p 9091:9091 -d dperson/transmission

OR set local storage:

    sudo docker run --name transmission -p 9091:9091 \
                -v /path/to/directory:/var/lib/transmission-daemon/downloads \
                -d dperson/transmission

## Configuration

    sudo docker run -it --rm dperson/transmission -h

    Usage: transmission.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -t ""       Configure timezone
                    possible arg: "[timezone]" - zoneinfo timezone for container
        -v "<server;user;password>" Configure OpenVPN
                    required arg: "<server>;<user>;<password>"
                    <server> to connect to
                    <user> to authenticate as
                    <password> to authenticate with

    The 'command' (if provided and valid) will be run instead of transmission

ENVIROMENT VARIABLES (only available with `docker run`)

 * `TRUSER` - Set the username for transmission auth (default 'admin')
 * `TRPASSWD` - Set the password for transmission auth (default 'admin')
 * `TIMEZONE` - As above, set a zoneinfo timezone, IE `EST5EDT`
 * `VPN` - As above, setup a VPN connection

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec transmission.sh` (as of version 1.3 of docker).

    sudo docker run --name transmission -d dperson/transmission -t EST5EDT

Will get you the same settings as

    sudo docker run --name transmission -p 9091:9091 -d dperson/transmission
    sudo docker exec transmission transmission.sh -T EST5EDT \
                ls -AlF /etc/localtime
    sudo docker restart transmission

## VPN

**NOTE**: More than the basic privileges are needed for OpenVPN. With docker 1.2 or
newer you can use the `--cap-add=NET_ADMIN` option. Earlier versions or using
fig, you'll have to run it in privileged mode.

    sudo docker run --cap-add=NET_ADMIN --name transmission -d \
                dperson/transmission -v \
                "us-east.privateinternetaccess.com;username;password"

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/transmission/issues).
