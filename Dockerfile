FROM ubuntu:trusty
MAINTAINER David Personette <dperson@dperson.com>

# Install nginx and uwsgi
RUN export TERM=dumb && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys \
                976B5901365C5CA1 && \
    echo -n "deb http://ppa.launchpad.net/transmissionbt/ppa/ubuntu" >> \
                /etc/apt/sources.list && \
    echo " $(lsb_release -cs) main" >> /etc/apt/sources.list && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends transmission-daemon openvpn \
                curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure
COPY transmission.sh /usr/bin/

VOLUME ["/var/lib/transmission-daemon"]

EXPOSE 9091 51413/tcp 51413/udp

ENTRYPOINT ["transmission.sh"]
