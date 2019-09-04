FROM arm64v8/alpine
COPY qemu-aarch64-static /usr/bin/
MAINTAINER David Personette <dperson@gmail.com>

# Install transmission
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash curl shadow sed tini \
                transmission-daemon tzdata && \
    dir="/var/lib/transmission-daemon" && \
    file="$dir/info/settings.json" && \
    mv /var/lib/transmission $dir && \
    usermod -d $dir transmission && \
    [[ -d $dir/downloads ]] || mkdir -p $dir/downloads && \
    [[ -d $dir/incomplete ]] || mkdir -p $dir/incomplete && \
    [[ -d $dir/info/blocklists ]] || mkdir -p $dir/info/blocklists && \
    /bin/echo -e '{\n    "blocklist-enabled": 0,' >$file && \
    echo '    "dht-enabled": true,' >>$file && \
    echo '    "download-dir": "'"$dir"'/downloads",' >>$file && \
    echo '    "incomplete-dir": "'"$dir"'/incomplete",' >>$file && \
    echo '    "incomplete-dir-enabled": true,' >>$file && \
    echo '    "download-limit": 100,' >>$file && \
    echo '    "download-limit-enabled": 0,' >>$file && \
    echo '    "encryption": 1,' >>$file && \
    echo '    "max-peers-global": 200,' >>$file && \
    echo '    "peer-port": 51413,' >>$file && \
    echo '    "peer-socket-tos": "lowcost",' >>$file && \
    echo '    "pex-enabled": 1,' >>$file && \
    echo '    "port-forwarding-enabled": 0,' >>$file && \
    echo '    "queue-stalled-enabled": true,' >>$file && \
    echo '    "ratio-limit-enabled": true,' >>$file && \
    echo '    "rpc-authentication-required": 1,' >>$file && \
    echo '    "rpc-password": "transmission",' >>$file && \
    echo '    "rpc-port": 9091,' >>$file && \
    echo '    "rpc-username": "transmission",' >>$file && \
    echo '    "rpc-whitelist": "127.0.0.1",' >>$file && \
    echo '    "upload-limit": 100,' >>$file && \
    /bin/echo -e '    "upload-limit-enabled": 0\n}' >>$file && \
    chown -Rh transmission. $dir && \
    rm -rf /tmp/*

COPY transmission.sh /usr/bin/

EXPOSE 9091 51413/tcp 51413/udp

HEALTHCHECK --interval=60s --timeout=15s \
            CMD netstat -lntp | grep -q '0\.0\.0\.0:9091'

VOLUME ["/var/lib/transmission-daemon"]

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/transmission.sh"]