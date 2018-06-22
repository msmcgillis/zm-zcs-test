FROM ubuntu:16.04

# Install Basic Packages
RUN apt-get update && \
    apt-get install -y \
    ant \
    ant-contrib \
    build-essential \
    curl \
    dnsmasq \
    dnsutils \
    gettext \
    git \
    git-flow \
    libdigest-hmac-perl \
    linux-tools-common \
    maven \
    netcat \
    net-tools \
    npm \
    openjdk-8-jdk \
    python \
    python-pip \
    ruby \
    rsyslog \
    software-properties-common \
    vim \
    wget && \
    apt-get install -y man psutils psmisc ruby-dev gcc && \
    apt-get clean

WORKDIR /tmp
# Install STAF to /usr/local/staf
# Unpack the QA soapvalidator tests to /opt/qa/soapvalidator
# Unpack the QA genesis tests to /opt/qa/genesis
# Add the STAF libraries to the END of the list of places where libraries are searched
# Some of the libraries included with STAF are wonky and will bork normal commands
# if they are loaded first.
# Caching the STAF binary in S3 due to intermittent reliability issues with sourceforge
# Original URL: http://downloads.sourceforge.net/project/staf/staf/V3.4.26/STAF3426-setup-linux-amd64-NoJVM.bin
RUN curl -k -L -O https://docker.zimbra.com.s3.amazonaws.com/staf/STAF3426-setup-linux-amd64-NoJVM.bin
RUN wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.0.zip; \
    unzip /tmp/apache-jmeter-3.0.zip -d /opt/
RUN git clone https://github.com/Zimbra/zm-load-testing /opt/qa/zm-load-testing; \
    cd /opt/qa/zm-load-testing; ant jar; \
    rm -rf /opt/qa/zm-load-testing/logs; \
    ln -s /opt/qa/logs /opt/qa/zm-load-testing/logs; \
    ln -s /opt/qa/logs /opt/qa/zm-load-testing/logs; \
    rm /opt/qa/zm-load-testing/config/env.prop; \
    rm /opt/qa/zm-load-testing/config/users.csv
RUN git clone https://github.com/Zimbra/zimbra-package-stub.git -b master
RUN git clone https://github.com/Zimbra/zm-zcs.git -b develop
RUN git clone https://github.com/Zimbra/zm-mailbox.git -b develop
RUN git clone https://github.com/Zimbra/zm-soap-harness.git -b ha_limited
RUN git clone https://github.com/Zimbra/zm-genesis -b develop
RUN mkdir -p /root/.ivy2/cache
WORKDIR /tmp/zm-mailbox
RUN ant clean-ant publish-local-all -Dzimbra.buildinfo.version=8.8.3_GA
# Build soap testware
WORKDIR /tmp/zm-soap-harness
RUN ant build-soap-data-file
# Build genesis testware
WORKDIR /tmp/zm-genesis
RUN ant clean build-genesis

WORKDIR /tmp
RUN mkdir -p /opt/qa && \
    mkdir -p /opt/qa/logs/soap-harness && \
    mkdir -p /opt/qa/logs/genesis && \
    tar xf /tmp/zm-soap-harness/build/soapdata.tar -C /opt/qa/ && \
    tar xf /tmp/zm-genesis/build/genesis.tar -C /opt/qa/ && \
    sync && \
    chmod +x /tmp/STAF3426-setup-linux-amd64-NoJVM.bin;sync && \
    /tmp/STAF3426-setup-linux-amd64-NoJVM.bin -i silent \
       -DACCEPT_LICENSE=1 \
       -DCHOSEN_INSTALL_SET=Custom \
       -DCHOSEN_INSTALL_FEATURE_LIST=STAF,ExtSvcs,Langs,Codepage && \
    rm /tmp/STAF3426-setup-linux-amd64-NoJVM.bin;sync && \
    echo /usr/local/staf/lib > /etc/ld.so.conf.d/zzz-staf.conf && \
    ldconfig && \
    gpg --keyserver keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB && \
    \curl -sSL https://get.rvm.io -o rvm.sh && \
    /bin/bash -c 'cat rvm.sh | bash -s stable' && \
    /bin/bash -c 'source /etc/profile.d/rvm.sh && rvm install ruby --default --with-zlib-directory=/usr/local/rvm/usr --with-openssl-directory=/usr/local/rvm/usr' && \
    /bin/bash -c 'gem install soap4r log4r net-ldap json httpclient parseconfig' && \
    apt-get clean && \
    curl -o /root/s3curl.pl  https://raw.githubusercontent.com/rtdp/s3curl/master/s3curl.pl && \
    chmod +x /root/s3curl.pl

# Cleanup /tmp
WORKDIR /tmp
RUN rm -rf zimbra-package-stub zm-zcs zm-mailbox zm-soap-harness apache-jmeter-3.0.zip zm-genesis
# ************************************************************************
# The following is required for Genesis tests to be run.
# 1. Disable setting that prevents users from writing to current terminal device
# 2. Symlink in /bin/env (some genesis tests expect it to be there)
# 3. Add STAF commands to PATH
# ************************************************************************
RUN sed -i.bak 's/^mesg/# mesg/' /root/.profile && \
    ln -s /usr/bin/env /bin/env && \
    echo 'PATH=/usr/local/staf/bin:$PATH' >> /root/.bashrc
RUN sed -i '66 s/c\./c\.to\_s\./' /var/lib/gems/2.3.0/gems/soap4r-1.5.8/lib/xsd/xmlparser.rb


RUN mkdir /zimbra
COPY ./build/init /zimbra/init
COPY ./build/init-common /zimbra/init-common
RUN chmod +x /zimbra/init

