FROM ubuntu:16.04
ARG jmeter=apache-jmeter-3.0
ARG repo=https://github.com/Zimbra/zm-load-testing
ARG branch=master

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
# Install jmeter
RUN wget https://archive.apache.org/dist/jmeter/binaries/$jmeter.zip; \
    unzip /tmp/$jmeter.zip -d /opt/; \
    ln -s /opt/$jmeter /opt/apache-jmeter; \
    rm -rf $jmeter.zip
# Install zm-load-testing
RUN git clone $repo /opt/qa/zm-load-testing; \
    cd /opt/qa/zm-load-testing; git checkout $branch; \
    mkdir -p /opt/qa/zm-load-testing/src/build/jar
# Try to add zm-sync-common
COPY ./build/zm-sync-common.jar /opt/qa/zm-load-testing/src/build/jar
# Build and configure zm-load-testing
RUN if [ ! -s /opt/qa/zm-load-testing/src/build/jar/zm-sync-common.jar ]; \
    then rm /opt/qa/zm-load-testing/src/build/jar/zm-sync-common.jar; fi; \
    cd /opt/qa/zm-load-testing; \
    ant -Djmeter.home=/opt/$jmeter src; \
    mkdir -p /opt/qa/logs; \
    rm -rf /opt/qa/zm-load-testing/logs; \
    ln -s /opt/qa/logs /opt/qa/zm-load-testing/logs; \
    cd /opt/qa/zm-load-testing/src; \
    if [ -f /opt/qa/zm-load-testing/src/build/jar/zm-sync-common.jar ]; \
    then ant -Djmeter.home=/opt/$jmeter install; fi;
# Short term we will just copy in secrets and configs so this container
# works with or with out swarm long term a batch swarm option with
# secrets and config would be better
COPY .secrets/env.prop /opt/qa/zm-load-testing/config/env.prop
COPY .config/users.csv /opt/qa/zm-load-testing/config/users.csv

# add init script for test execution
RUN mkdir /zimbra
COPY ./build/zm-test /zimbra/zm-test
RUN chmod +x /zimbra/zm-test
