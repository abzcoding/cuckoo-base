FROM alpine:latest

MAINTAINER Abouzar Parvan <abzcoding@gmail.com>

ENV YARA 3.4.0
ENV SSDEEP ssdeep-2.13
ENV VOLATILITY 2.5

WORKDIR /tmp/docker/build

RUN buildDeps='curl \
               g++ \
               libboost-all-dev \
               libconfig-dev \
               libcurl4-openssl-dev \
               libcurlpp-dev \
               libdevmapper-dev \
               libffi-dev \
               libjansson-dev \
               libjpeg62-turbo-dev \
               libmagic-dev \
               libnl-3-dev \
               libnl-route-3-dev \
               libpciaccess-dev \
               libssl-dev \
               libxml2-dev \
               libxslt1-dev \
               libyaml-dev \
               libpcap-dev \
               libnet1-dev \
               libpcre3-dev \
               zlib1g-dev \
               libmagic-dev \
               libcap-ng-dev \
               make \
               autoconf \
               automake \
               numactl \
               python-dev \
               python-pip \
               subversion \
               wget \
               zlib1g-dev' \
 && set -x \
 && apk add --update    $buildDeps \
                        cron \
                        libtool \
                        adduser \
                        apt-utils \
                        git-core \
                        pkg-config \
                        jansson \
                        py-libvirt \
                        libvirt \
                        python \
                        software-properties-common \
                        sudo \
                        supervisor \
                        tcpdump \
                        zlib1g --no-install-recommends \
 && echo "Installing Python Requirements " \
 && pip install bottle \
                chardet \
                django \
                django-ratelimit \
                dnspython \
                jinja2 \
                jsbeautifier \
                mitmproxy \
                nose \
                pefile \
                pygal \
                pymongo \
                sqlalchemy \
 && echo "Build and install yara [$YARA] " \
 && wget https://github.com/plusvic/yara/archive/v$YARA.tar.gz \
 && tar xzf v$YARA.tar.gz \
 && cd yara-$YARA \
 && ./bootstrap.sh \
 && ./configure --with-crypto --enable-cuckoo --enable-magic \
 && make \
 && make install \
 && cd yara-python \
 && python setup.py build \
 && python setup.py install \
 && cd \
 && echo "Build and install ssdeep, Install pydeep, which is used to generate fuzzy hashes " \
 && wget http://www.mirrorservice.org/sites/dl.sourceforge.net/pub/sourceforge/s/ss/ssdeep/$SSDEEP/$SSDEEP.tar.gz \
 && tar xzf $SSDEEP.tar.gz \
 && cd $SSDEEP \
 && ./bootstrap \
 && ./configure \
 && make \
 && make install \
 && git clone https://github.com/kbandla/pydeep.git \
 && cd pydeep \
 && python setup.py build \
 && python setup.py install \
 && cd \
 && echo "Install Malheur, which is used for malware behavior correlation" \
 && git clone https://github.com/rieck/malheur.git \
 && cd malheur \
 && ./bootstrap \
 && ./configure --prefix=/usr \
 && make \
 && make install \
 && cd \
 && echo "Build and Install the Volatility memory analysis system" \
 && wget https://github.com/volatilityfoundation/volatility/archive/$VOLATILITY.tar.gz \
 && tar xzf $VOLATILITY.tar.gz \
 && cd volatility-$VOLATILITY \
 && python setup.py build \
 && python setup.py install \
 && cd \
 && echo "Fetch and install Suricata" \
 && wget http://www.openinfosecfoundation.org/download/suricata-3.0RC3.tar.gz \
 && tar -zxf suricata-3.0RC3.tar.gz \
 && cd suricata-3.0RC3 \
 && ./configure \
 && make \
 && make install \
 && cd \
 && echo "Install the PyV8 JavaScript engine, used for analyzing malicious JavaScript" \
 && svn checkout http://pyv8.googlecode.com/svn/trunk/ pyv8-read-only \
 && cd pyv8-read-only \
 && python setup.py build \
 && python setup.py install \
 && cd \
 && echo "Download etupdate to update Emerging Threat's Open IDS rules" \
 && git clone https://github.com/seanthegeek/etupdate.git \
 && cp etupdate/etupdate /usr/sbin/etupdate \
 && /usr/sbin/etupdate -V \
 && mkdir -p /var/spool/cron/crontabs \
 && echo "42 * * * * /usr/sbin/etupdate" >> /var/spool/cron/crontabs/root \
 && echo "Create Cuckoo user" \
 && adduser cuckoo --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password \
 && chown -R cuckoo:cuckoo /usr/var/malheur/ \
 && chmod -R =rwX,g=rwX,o=X /usr/var/malheur/ \
 && chown cuckoo:cuckoo -R /etc/suricata \
 && echo "Clean up unnecessary files" \
 && apk del $buildDeps \
 && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Configure Suricata to capture any file found over HTTP
COPY suricata/rules/cuckoo.rules /etc/suricata/rules/cuckoo.rules
COPY suricata/suricata-cuckoo.yaml /etc/suricata/suricata-cuckoo.yaml
