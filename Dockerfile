FROM ubuntu:latest
MAINTAINER Abouzar Parvan <abzcoding@gmail.com>

ENV YARA 3.4.0
ENV SSDEEP ssdeep-2.13
ENV VOLATILITY 2.5
ENV LIBVIRT 1.3.1

WORKDIR /tmp/docker/build

COPY builddep.txt /tmp/
COPY packages.txt /tmp/
COPY requirements.txt /tmp/

# Install the build dependencies
RUN apt-get update &&\
    xargs apt-get install -y < /tmp/builddep.txt

# Install the cuckoo dependencies
RUN xargs apt-get install -y < /tmp/packages.txt &&\
    rm /tmp/packages.txt

# Install Python requirements
RUN pip install -r /tmp/requirements.txt &&\
    rm /tmp/requirements.txt

# Build and install yara
RUN wget https://github.com/plusvic/yara/archive/v$YARA.tar.gz &&\
    tar xzf v$YARA.tar.gz &&\
    cd yara-$YARA &&\
    ./bootstrap.sh &&\
    ./configure --with-crypto --enable-cuckoo --enable-magic &&\
    make &&\
    make install &&\
    cd yara-python &&\
    python setup.py build &&\
    python setup.py install &&\
    rm -rf /tmp/docker/build/*

# Build and install ssdeep, Install pydeep, which is used to generate fuzzy hashes
RUN wget http://www.mirrorservice.org/sites/dl.sourceforge.net/pub/sourceforge/s/ss/ssdeep/$SSDEEP/$SSDEEP.tar.gz &&\
    tar xzf $SSDEEP.tar.gz &&\
    cd $SSDEEP &&\
    ./bootstrap &&\
    ./configure &&\
    make &&\
    make install &&\
    git clone https://github.com/kbandla/pydeep.git &&\
    cd pydeep &&\
    python setup.py build &&\
    python setup.py install &&\
    rm -rf /tmp/docker/build/*

# Install Malheur, which is used for malware behavior correlation
RUN git clone https://github.com/rieck/malheur.git &&\
    cd malheur &&\
    ./bootstrap &&\
    ./configure --prefix=/usr &&\
    make &&\
    make install &&\
    rm -rf /tmp/docker/build/*

# Build and Install the Volatility memory analysis system
RUN wget https://github.com/volatilityfoundation/volatility/archive/$VOLATILITY.tar.gz &&\
    tar xzf $VOLATILITY.tar.gz &&\
    cd volatility-$VOLATILITY &&\
    python setup.py build &&\
    python setup.py install &&\
    rm -rf /tmp/docker/build/*

# Build and install libvirt with ESX driver
RUN wget http://libvirt.org/sources/libvirt-$LIBVIRT.tar.gz &&\
    tar xzf libvirt-$LIBVIRT.tar.gz &&\
    cd libvirt-$LIBVIRT &&\
    ./configure --with-esx &&\
    make &&\
    make install &&\
    git clone git://libvirt.org/libvirt-python.git &&\
    cd libvirt-python &&\
    git checkout -b v$LIBVIRT tags/v$LIBVIRT &&\
    python setup.py build &&\
    python setup.py install &&\
    ldconfig &&\
    rm -rf /tmp/docker/build/*

# Fetch and install Suricata
RUN add-apt-repository ppa:oisf/suricata-beta &&\
    apt-get update &&\
    apt-get install -y libhtp1 suricata

# Install the PyV8 JavaScript engine, used for analyzing malicious JavaScript
# COPY servers /root/.subversion/servers #if you want to use a proxy for getting code from googlecode
RUN svn checkout http://pyv8.googlecode.com/svn/trunk/ pyv8-read-only &&\
    cd pyv8-read-only &&\
    python setup.py build &&\
    python setup.py install &&\
    rm -rf /tmp/docker/build/*

# Configure Suricata to capture any file found over HTTP
COPY suricata/rules/cuckoo.rules /etc/suricata/rules/cuckoo.rules
COPY suricata/suricata-cuckoo.yaml /etc/suricata/suricata-cuckoo.yaml

# Download etupdate to update Emerging Threat's Open IDS rules
RUN git clone https://github.com/seanthegeek/etupdate.git &&\
    cp etupdate/etupdate /usr/sbin/etupdate &&\
    /usr/sbin/etupdate -V
RUN echo "42 * * * * /usr/sbin/etupdate" >> /var/spool/cron/crontabs/root

# Create Cuckoo user
RUN adduser cuckoo --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
RUN chown -R cuckoo:cuckoo /usr/var/malheur/
RUN chmod -R =rwX,g=rwX,o=X /usr/var/malheur/
RUN chown cuckoo:cuckoo /etc/suricata/suricata-cuckoo.yaml

# Clean up unnecessary files
RUN xargs apt-get purge -y --auto-remove < /tmp/builddep.txt &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
