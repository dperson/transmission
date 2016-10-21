FROM debian:stretch
MAINTAINER David Personette <dperson@gmail.com>

# Install transmission
RUN export DEBIAN_FRONTEND='noninteractive' && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends curl procps \
                transmission-daemon \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    apt-get clean && \
    dir="/var/lib/transmission-daemon" && \
    rm $dir/info && \
    mv $dir/.config/transmission-daemon $dir/info && \
    rmdir $dir/.config && \
    usermod -d $dir debian-transmission && \
    [ -d $dir/downloads ] || mkdir -p $dir/downloads && \
    [ -d $dir/incomplete ] || mkdir -p $dir/incomplete && \
    [ -d $dir/info/blocklists ] || mkdir -p $dir/info/blocklists && \
    file="$dir/info/settings.json" && \
    sed -i 's|\("download-dir":\) .*|\1 "'"$dir"'/downloads",|' $file && \
    sed -i '/"download-dir"/a\    "incomplete-dir": "'"$dir"'/incomplete",' \
                $file && \
    sed -i '/"incomplete-dir"/a\    "incomplete-dir-enabled": true,' $file && \
    sed -i '/"peer-port"/a\    "peer-socket-tos": "lowcost",' $file && \
    sed -i '/"port-forwarding-enabled"/a\    "queue-stalled-enabled": true,' \
                $file && \
    sed -i '/"queue-stalled-enabled"/a\    "ratio-limit-enabled": true,' \
                $file && \
    chown -Rh debian-transmission. $dir && \
    rm -rf /var/lib/apt/lists/* /tmp/*
COPY transmission.sh /usr/bin/

VOLUME ["/var/lib/transmission-daemon"]

EXPOSE 9091 51413/tcp 51413/udp

ENTRYPOINT ["transmission.sh"]