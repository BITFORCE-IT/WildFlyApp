FROM jboss/wildfly:10.0.0.Final
MAINTAINER BITFORCE-IT GmbH René Mertins r.mertins@bitforce-it.de

# go root to do copy and rights stuff
USER root

# create folders and copy data
RUN mkdir /start
ADD bin/ /start
ADD customization /opt/jboss/wildfly/customization/
ADD modules/ /opt/jboss/wildfly/modules

# set owner ship and rights
RUN chown -R jboss:jboss /start
RUN chown -R jboss:jboss /opt/jboss/wildfly/modules
RUN chown -R jboss:jboss /opt/jboss/wildfly/customization
RUN chmod 775 /opt/jboss/wildfly/customization/execute.sh
RUN chmod 775 /start/entrypoint.sh

# switch back to app user
USER jboss

# setup environment
EXPOSE 8080
EXPOSE 9990
VOLUME /data/logs
ENV DB_HOST 10.0.0.1
ENV DB_PORT 3306
ENV DB_USER db_user
ENV DB_PASSWORD db_password
ENV DB_SCHEMA db_schema
ENV AWS_KEY AKXXXXXXXXXXXXXXXXXX
ENV AWS_SECRET fDEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# copy the application
# ADD Application.ear /opt/jboss/wildfly/standalone/deployments/Application.ear

# configure jboss wildfly 10 application server
RUN /opt/jboss/wildfly/bin/add-user.sh admin password --silent
# run our app service customization script using standalone mode with standalone.xml configuration
RUN /opt/jboss/wildfly/customization/execute.sh standalone standalone.xml


ENTRYPOINT ["/start/entrypoint.sh"]
CMD ["jboss"]
