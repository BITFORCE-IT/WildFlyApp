#!/bin/bash

# Fail fast, including pipelines
set -eo pipefail

# get the ip address of the container to bind too
host_ip=$(hostname -I)

# replace our markers in the standalone.xml, which we added over the CLI Command script on container build.
sed -e "s/###DB_HOST###/${DB_HOST}/g" \
	-e "s/###DB_PORT###/${DB_PORT}/g" \
	-e "s/###DB_SCHEMA###/${DB_SCHEMA}/g" \
	-e "s/###DB_USER###/${DB_USER}/g" \
	-e "s/###DB_PASSWORD###/${DB_PASSWORD}/g" \
	-i /opt/jboss/wildfly/standalone/configuration/standalone.xml

# if the container CMD value is jboss, run wildfly
if [ "$1" = 'jboss' ]; then
    echo "Starting application on ${host_ip}"
    exec /opt/jboss/wildfly/bin/standalone.sh -b=${host_ip} -bmanagement=${host_ip} -bunsecure=${host_ip} --server-config=standalone.xml -Djboss.server.log.dir=/data/logs  -Daws.accessKeyId=${AWS_KEY} -Daws.secretKey=${AWS_SECRET}
fi

# if the container CMD value is not jboss, run the given CMD value directly on the system
# this allows for example to start the container running a bash shell instead of the wildfly.
exec "$@"
