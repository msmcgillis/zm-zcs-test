# Overview

This container is a standolne container that can be deployed to test zimbra environments. It requires a docker swarm server.

## performance

This container includes the Zimbra zm-load-testing software for performance testing.

## soapharness

TBD

## genesis

TBD

# Outline

To run tests the following things need to be resolved

## environment configuration

The test container must be configure for the target zimbra envronment to test.The make file uses the bin/env script to talk to a zimbra target environment and generate the nececary configuration information for the test. See the bin/env script for more details on how it works. The make file will create a .secrets/env.prop file which you can manually edit after the make is done if necessary.

Note: This probably needs more work/improvments but its a start

## account configuration

The test container must know what user accounts exist in zimbra for testing. The make file uses the bin/user script to generate a default set of users in a config file however these default users probably will not exist in zimbra. See the bin/user for more details on how it works, it can be used to add users to zimbra. The make file will create a .config/users.csv file which you can manually edit after the amke is done if necessary.

Note: This probably needs more work/improvments but its a start

## data collection

The tests store information in /opt/qa/log on the container which on default is mapped to ./log on default but really needs to be some sort of shared file system in a swam config.

# start service

update DOT_env for your environment -- old probably goes away when done

make PASS=adminpass URL=https://zimbra.server.com:7071/service/admin/soap
# PASS and URL have internal defaults but not sure they work in a default case

make up

# Run Test

1. determine containerid

  docker ps

2. connect container
  docker exec -it containerid /bin/bash
  $ /zimbra/init --run-performance yes --performance-target generic-lmtp

# Thoughts

Ideally test would not be a long running service as above but instead define a particular test by modifying the docker-compose.yml then execute it using

IMG=zimbra/zm-zcs-test:latest docker stack deploy -c docker-compose.yml zm-test

That would run the identified test then exit. Unfortunately services don't support this currently.

If the above did work then Inside the docker compose I would expect to get to the point where we have multiple servers to performe larger loads. So you may have a smtp, imap, zsoap, ... service defined in the compose file and each of those services would do an appropriate:

/zimbra/init --run-performance yes --performance-target generic-<test>

Then if we also support --performance-load you could increase the load for the specific jmeter instance up to jmeters determined reasonnable max but then in the yml file you could make multiple instances of each service to increase the load beyond a single jmeter instane.

In general it seems Docker is not perfect for Batch processing at a service level. More investigation into how best to do Batch processing in Docker is needed. It seems in general run is recommended for batch processing however we don't have access to config and secrets with run so that would have to be reworked if went that path.
