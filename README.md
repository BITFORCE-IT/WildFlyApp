# JBoss Wildfly application image example
This is a Docker image based on jboss/wildfly official image.
Enhancing it with a useful configuration and deployment process.
This image is designed to make it as simple as possible to start, configure, 
deploy and run a JEE application on Wildfly application server.

It shows how to enable runtime configuration over environment variables, to make 
it really easy to deploy huge amounts of this image.

## Usage
First clone this repository.

    git clone https://github.com/BITFORCE-IT/WildflyApp

Then enter the repository directory "WildflyApp"

Copy your JEE application package (.ear,.war,.sar) into the repository folder.

Open the "Dockerfile" with your favorite text editor. Uncomment and change 
the ADD my application line. To copy your application package into the image.

    ADD Application.ear /opt/jboss/wildfly/standalone/deployments/Application.ear 

Build the image running the build command inside the repository folder.

    docker build -t my-wildlfy-app .
    
Then run it with the run command.

    docker run my-wildfly-app

> Doing this will start the Wildfly server, trying to deploy your application. 
> Which will in most cases work. But this image also setups a data source which 
> tries to connect to a MySQL db. That will give you some errors or probably let the 
> application server crash. This is no mistake! Further configuration and customization 
> is explained later.

## Structure
This image has the following structure:

1. bin/

    scripting stuff is located, that is copied to /start and made runnable

    1. entrypoint.sh

    is the entry point shell script of this image

2. customization/

    Wildfly configuration stuff is in here, which is run at image build phase

    1. execute.sh

        this script is run by Dockerfile on image build. It starts 
        the application server, enters the CLI and runs a command script 
        to configure Wildfly for your needs.
        Thanks to [this blog post](https://goldmann.pl/blog/2014/07/23/customizing-the-configuration-of-the-wildfly-docker-image/)

    2. commands.cli

        Wildfly configuration commands file, which can be used with the 
        Wildfly CLI to configure the Wildfly for your needs.

3. modules/

    this folder is copied over the Wildfly modules folder. Place your modules 
    like jdbc drivers in here and use the correct folder structure.
    For example a MySQL driver jar would end up in `modules/system/layers/base/com/mysql`

4. Dockerfile

    The Dockerfile himself.

## Description
What happens here?

It's very simple. This image does two things.

1. It builds a Docker image based on jboss/wildfly. In the build process
    the application server is started one time and the CLI is used to configure 
    the application server. Doing this it places placeholders in the configuration file 
    which are later replaced by environment variables during start up.

2. On start, the image uses his own entry point script, which checks environment 
    and replaces placeholders with environment variables in the configuration file and then 
    starts the application server.

The result is, that you have an image which you can easily setup during build 
phase by simple editing of commands.cli file and fine-tune to current environment during 
start.

### Configure Wildfly during build phase
The Wildfly application server in this image is configured over his CLI 
during the build phase. This is done by calling the customization/execute.sh script 
inside the Dockerfile.

    RUN /opt/jboss/wildfly/customization/execute.sh standalone standalone.xml

It accepts two parameters:

- start in **standalone** or **domain** mode
- used configuration filename

When not given any parameters the defaults are **standalone** mode with **standalone.xml** 
configuration.

> This example is tested with standalone mode and standalone.xml file. 
> When using domain mode or other configuration file, look through Dockerfile 
> , entrypoint.sh and execute.sh for hardcoded configuration file names and command names.
> Change them to your according needs.

The execute.sh script will start the Wildfly and waits till it is up and running in default configuration 
like it comes from JBoss. Then it uses the Wildfly CLI to run the commands.cli file. After this it stops 
Wildfly again.

In this example, 4 different common tasks are done over CLI.

1. It registers the MySQL driver module which was copied into Wildfly
2. Creates an XA data source using the MySQL driver and placing placeholders instead 
of real parameters.
3. It adds a periodic log file handler
4. It adds a logger category using the new periodic log file handler.

These are all very common steps, which nearly every JEE app needs to run.
A good place to learn something about CLI and find some examples in the JBoss docs.

[CLI Recipes Wildfly Docs](https://docs.jboss.org/author/display/WFLY8/CLI%20Recipes)

[CLI Recipes AS71 *still works*](https://docs.jboss.org/author/display/AS71/CLI%20Recipes)

You can do any kind of configuration here. The outcome of the CLI is printed out 
to the Docker build process standard out, so you can see errors or success message during build.

### Execution
When the image is build and ready to run, it uses its own entry point 
script to run the application server.
This entry point checks the environment for usable variables and replaces 
them in the application server’s configuration file.

The same way can be used to alter other configurations as well.

In this example 5 different placeholders for the database connection are 
placed in the standalone.xml during build phase by the commands.cli script.

These placeholders are:

1. \#\#\#DB_HOST\#\#\#

    hostname or IP address of the MySQL server host
    

2. \#\#\#DB_PORT\#\#\#

    TCP Port number on which the MySQL server is listening
    

3. \#\#\#DB_SCHEMA\#\#\#

    the default database schema to apply to
    

4. \#\#\#DB_USER\#\#\#

    the user name to use for connecting the database
    

5. \#\#\#DB_PASSWORD\#\#\#

    the password of the user for connecting the database
    

To make sure these environment variables exist, they are all defined 
with default values in Dockerfile like this:

    ENV DB_HOST 10.0.0.1
    ENV DB_PORT 3306
    ENV DB_USER db_user
    ENV DB_PASSWORD db_password
    ENV DB_SCHEMA db_schema

Now when you run the image you can overwrite all of this values by 
supplying these variables to the run command.

    docker run -e DB_HOST=192.168.0.100 -e DB_USER=dbuser -e DB_PASSWORD=password -e DB_SCHEMA=myDB my-wildfly-app

When you have looked in the Dockerfile, you will have recognized that 
there are two more environment variables defined.

    ENV AWS_KEY AKXXXXXXXXXXXXXXXXXX
    ENV AWS_SECRET fDEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

This is an example for passing in AWS credentials to the application 
server environment. They are used in the entry point script and placed 
as Java properties.

    exec /opt/jboss/wildfly/bin/standalone.sh -b=${host_ip} -bmanagement=${host_ip} -bunsecure=${host_ip} --server-config=standalone.xml -Djboss.server.log.dir=/data/logs  -Daws.accessKeyId=${AWS_KEY} -Daws.secretKey=${AWS_SECRET}

They are set to the properties: aws.accessKeyId and aws.secretKey.
When you are using the correct credentials provider for your AWS connection 
these values are used.

### Logging Volume
The Dockerfile defines a mountable volume, which is passed to the 
application server as base log directory.
This way you get your application server logs, where you want them, 
outside of the container.

Definition of volume in Dockerfile:

    VOLUME /data/logs

And in the entrypoint.sh it is passed to the application server by:

    -Djboss.server.log.dir=/data/logs

## Example
To use everything included in this example, you need to do.

1. Place a JEE application archive as described in usage chapter.

    This application should include a persistence unit using the 
    "MyCustomDS" data source and uses the AWS Java SDK. 

2. Provide all environment variables in the docker run command


Full command example using all environment parameters, volumes and ports. 

    docker run --name my-app --rm -e DB_HOST=192.168.0.100 -e DB_PORT=3306 -e DB_USER=user -e DB_PASSWORD=password -e DB_SCHEMA=example -e AWS_KEY=XXXXXXXXXXXXXXXXXXXX -e AWS_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX -p 8080:8080 -p 9990:9990 -v /mnt/logs:/data/logs wildfly-app

Parameter description:

- \-\-name

    defines a custom name for the container instance. 
    A container is easer to identify by a custom name then by the auto 
    generated one from Docker.

- \-\-rm

    tells docker to remove this container after it stops to keep the cache clean.

- \-e 

    defines an environment variable. This parameter needs to be followed 
    by case sensitive property name and value, seperated by equals sign.

- \-p

    defines the network NAT rules for binding Docker host ports to 
    container ports.

- \-v

    maps a local directory to the provided volume mount of the container.


## Links and References
Following a list of Webpages of all used software and knowledge resources 
we used to build this example.

[Wildfly application server](http://wildfly.org/)

[Official Wildfly Docker Image](https://hub.docker.com/r/jboss/wildfly/)

[Official Wildfly Docker Git Repo](https://github.com/jboss-dockerfiles/wildfly)

[Blog Post *Customizing the configuration of the WildFly Docker image*](https://goldmann.pl/blog/2014/07/23/customizing-the-configuration-of-the-wildfly-docker-image/)

[Blog Post *Logging with the WildFly Docker image*](https://goldmann.pl/blog/2014/07/18/logging-with-the-wildfly-docker-image/)

[AWS Java SDK](https://aws.amazon.com/de/sdk-for-java/)

[Docker Reference](https://docs.docker.com/engine/reference/builder/)

[Best practices for writing Dockerfiles](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/)