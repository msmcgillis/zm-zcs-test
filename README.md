# Overview

This container is a stand alone container that can be deployed to test zimbra environments using docker.

## performance

This container includes the Zimbra zm-load-testing software for performance testing.

# Outline

To run tests the following things must be resolved

## Environment Configuration

The test container must be configured for the target zimbra envronment to test. The make file uses the bin/env script to talk to a zimbra target environment and generate the necessary configuration information for the test. See the bin/env script for more details on how it works. The make file will create a .secrets/env.prop file which you can manually edit after the make is done if necessary.

Generate a environment file for review:

```
make .secrets/env.prop
cat .secrets/env.prop
```

If that doesn't produce anything you may need to either modify the Makefile or pass an appropriate ADMIN, PASS, and URL value for you environment.

note if you did the above and want to force make to recreate the secrets use -B: make -B .secrets/env.prop

```
PASS=mypass make .secrets/env.prop
PASS=mypass URL=https://my.zimbra.server.com:7071/service/admin/soap make .secrets/env.prop
```

If the above is generating a env.prop file it still may not be correct if you have different external access so you may still need to make some addjustements to the generated env.prop file.

You can experiment with bin/env directly it generates output to stdout on default.

```
bin/env -a admin -p adminpass -url https://my.zimbra.server.com:7071/service/admin/soap
```

## Account Configuration

The test container must know what user accounts exist in zimbra for testing. The make file uses the bin/users script to generate a default set of users in a config file however these default users probably will not exist in zimbra. See the bin/users script for more details on how it works. The make file will create a .config/users.csv file which you can manually edit after the make is done if necessary.

To see the file it generates by default from make you can

```
make .config/users.csv
cat .config/users.csv
```

You can also run the command manully with

```
bin/users -a perf -n 1
```

You can use the script to generate zmprov batch file that will create the set of users generated in the users.csv file.

```
bin/users -a create -n 1 >zmprov.create
zmprov <zmprov.create
```

You can also use the script to generate a zmprov batch file that will delete the set of users generated in the users.csv file.

```
bin/users -a delete -n 1 >zmprov.delete
zmprov <zmprov.delete
```

## Data Collection

The tests store information in /opt/qa/log on the container which should be mapped to some external storage.

## Container Generation

If you have all the above items resolved you can generate your performance test container:

```
make
```

or perhaps

```
make PASS=adminpass URL=https://my.zimbra.server.com:7071/service/admin/soap
```

After the above you should have a docker image named zimbra/zm-zcs-test

```
$ docker image ls
REPOSITORY                   TAG                    IMAGE ID            CREATED             SIZE
zimbra/zm-zcs-test           latest                 79583d4880a5        35 seconds ago      1.19GB
```

# testing

Once you have a zm-zcs-test image you can begin testing:

Run the zm-load-testing generic lmtp test.

```
docker run --rm -v /test/path/logs:/opt/qa/logs zimbra/zm-zcs-test:latest /zimbra/zm-test -t lmtp
```

List available tests in zm-load-testing.

```
docker run --rm -v /test/path/logs:/opt/qa/logs zimbra/zm-zcs-test:latest /zimbra/zm-test
```

Get short help about zm-test script.

```
docker run --rm -v /test/path/logs:/opt/qa/logs zimbra/zm-zcs-test:latest /zimbra/zm-test -h
```

# service

If you want a permenant container running that you can connect to and run zm-test from it you can do:

```
make up
```

This will start a container using the zimbra/zm-zcs-test image that will remain running until you stop it. You should have a continer with the name perf running.

```
$ docker ps 
CONTAINER ID        IMAGE                                 COMMAND                  CREATED              STATUS              PORTS                      NAMES
0514fc4521c3        zimbra/zm-zcs-test:latest             "/zimbra/zm-test --s…"   About a minute ago   Up About a minute                              perf
```

With the above container running you can then connect to it

```
docker exec -it perf /bin/bash
```

Once connected with the above you can then run a test

```
$ /zimbra/zm-test
$ /zimbra/zm-test -t lmtp
```

# Thoughts

Ideally test would not be a long running service but instead define a particular test by modifying the docker-compose.yml then execute it using

IMG=zimbra/zm-zcs-test:latest docker stack deploy -c docker-compose.yml zm-test

That would run the identified test then exit. Unfortunately services don't support this currently.

If the above did work then inside the docker compose we could have multiple services to performe larger loads. So you may have a smtp, imap, pop, zsoap, ... service defined in the compose file and each of those services would do an appropriate:

/zimbra/zm-test -t smtp -u 200 -i -1
/zimbra/zm-test -t imap -u 500 -i -1
/zimbra/zm-test -t pop -u 300 -i -1
/zimbra/zm-test -t zsoap -u 200 -i -1

Note the above is using the zm-test ability to adjust the default thread and loop counts. In jmeter the -user specifies the thread count and -iteration specifiec the loopcount for the thread. Using -1 for the loop count means the test will loop forever. So if you had 4 containers all running with the above you would be simulating 1200 concurrent users 200 smtp 500 imap 300 pop and 200 zsoap.

In general it seems Docker is not perfect for Batch processing at a service level. More investigation into how best to do Batch processing in Docker is needed. It seems in general run is recommended for batch processing however we don't have access to config and secrets with run. Although this is set up to create secrets and configs during the image generation we put the files in the image through the Dockerfile so the container will function went started with run or docker-compose vs docker stack. 
