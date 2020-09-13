FROM debian:buster
MAINTAINER David Personette <dperson@dperson.com>

# Install transmission
RUN export DEBIAN_FRONTEND='noninteractive' && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends transmission-daemon curl bind9utils bind9-host \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    apt-get clean && \
    usermod -d /var/lib/transmission-daemon debian-transmission && \
    [ -d /var/lib/transmission-daemon/downloads ] || \
                mkdir -p /var/lib/transmission-daemon/downloads && \
    [ -d /var/lib/transmission-daemon/incomplete ] || \
                mkdir -p /var/lib/transmission-daemon/incomplete && \
    [ -d /var/lib/transmission-daemon/info/blocklists ] || \
                mkdir -p /var/lib/transmission-daemon/info/blocklists && \
    chown -Rh debian-transmission. /var/lib/transmission-daemon && \
    rm -rf /var/lib/apt/lists/* /tmp/*
COPY transmission.sh /usr/bin/

VOLUME ["/run", "/tmp", "/var/cache", "/var/lib", "/var/log", "/var/tmp"]

EXPOSE 9091 51413/tcp 51413/udp

ENTRYPOINT ["transmission.sh"]
