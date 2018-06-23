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
# Install jmeter
RUN wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.0.zip; \
    unzip /tmp/apache-jmeter-3.0.zip -d /opt/; \
    rm -rf apache-jmeter-3.0.zip
# Install zm-load-testing and configure
RUN git clone https://github.com/Zimbra/zm-load-testing /opt/qa/zm-load-testing; \
    cd /opt/qa/zm-load-testing; ant src; \
    mkdir -p /opt/qa/logs; \
    rm -rf /opt/qa/zm-load-testing/logs; \
    ln -s /opt/qa/logs /opt/qa/zm-load-testing/logs;
# Short term we will just copy in secrets and configs so this container
# works with or with out swarm long term a batch swarm option with
# secrets and config would be better
COPY .secrets/env.prop /opt/qa/zm-load-testing/config/env.prop
COPY .config/users.csv /opt/qa/zm-load-testing/config/users.csv

# add init script for test execution
RUN mkdir /zimbra
COPY ./build/zm-test /zimbra/zm-test
RUN chmod +x /zimbra/zm-test
