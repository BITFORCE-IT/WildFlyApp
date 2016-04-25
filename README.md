# JBoss Wildfly Application Container example
This is a Docker container based on jboss/wildfly official container.
Enhancing it with a useful configuration and deployment process.
This container is designed to make it as simple as possible to start, configure, 
deploy and run a JEE application on Wildfly application server.

It shows how to enable runtime configuration over environment variables, to make 
it really easy to deploy huge amounts of this container.

## Usage
First clone this repository.

    git clone https://github.com/BITFORCE-IT/WildflyApp

Then enter the repository Directory "WildflyApp"

Copy you’re JEE application package (.ear,.war,.sar) into the repository folder.

Open the "Dockerfile" with your favorite text editor. Uncomment and change 
the ADD my application line. To copy your application package into the container.

    ADD Application.ear /opt/jboss/wildfly/standalone/deployments/Application.ear 

Build the container running the build command inside the repository folder.

    docker build -t my-wildlfy-app .
    
Then run it with the run command.

    docker run my-wildfly-app

> Doing this will start the Wildfly server, trying to deploy your application. 
> Which will in most cases work. But this container also setups a data source which 
> tries to connect to a MySQL db. That will give you some errors or probably let the 
> application server crash. This is no mistake! Further configuration and customization 
> is explained later.

## Structure
This container has the following structure:

1. bin/

    in here are scripting stuff that is copied to /start and made runnable
        
    1. entrypoint.sh     
        is the entrypoint shell script of this container
    
2. customization/

    in here are Wildfly configuration stuff, which is run at container build phase
    
    1. execute.sh        
        this script is run by Dockerfile on container build. It starts 
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
What is happens here? 
It's very simple. This container does two things.

1. It builds a Docker container based on jboss/wildfly. In the build process
the application server is started one time and the CLI is used to configure 
the application server. Doing this it places placeholders in configuration file 
which are later replaced by environment variables during start up.

2. On start, the container uses his own entry point script, which checks environment 
and replaces environment variables with placeholders in configuration files and then 
starts the application server.

The result is, that you have a container which you can easily setup during build 
phase by simple editing the commands.cli file and fine-tune to actual environment on 
start.

### Configure Wildfly during build phase
The Wildfly application server in this container is configured over his CLI 
during the build phase. This is done by calling the customization/execute.sh script 
inside the Dockerfile.

    RUN /opt/jboss/wildfly/customization/execute.sh standalone standalone.xml

It accepts two parameters:

- start in standalone or domain mode
- used configuration

When not given any parameter the defaults are standalone mode with standalone.xml 
configuration.

> This example is tested with standalone mode and standalone.xml file. 
> When using domain mode or other configuration file, look through Dockerfile 
> , entrypoint.sh and execute.sh for hardcoded configuration filenames and command names.
> Change them to your needs.

The execute.sh script will start the Wildfly and waits till it is up and running in default configuration 
like it comes from JBoss. Then it uses the Wildfly CLI to run the commands.cli file. After this it stops 
Wildfly again.

In this example 4 different common tasks are done over CLI.

1. It registers the MySQL driver module which was copied into Wildfly
2. Creates an XA Data source using the MySQL driver and placing placeholders instead 
of real parameters.
3. It add a periodic log file handler
4. It adds a logger category using the new logger handle.

These are all very common steps, which nearly needs every JEE app to run.
A good place to learn something about CLI and find some examples in the JBoss docs.

[CLI Recipes Wildfly Docs](https://docs.jboss.org/author/display/WFLY8/CLI%20Recipes)

[CLI Recipes AS71 *still works*](https://docs.jboss.org/author/display/AS71/CLI%20Recipes)

You can do any kind of configuration here. The outcome of the CLI is printed out 
to the Docker build process standard out, so you can see errors or success message during build.

### Execution
When the Container is build and ready to run. It uses its own entry point 
script to run the application server.
This entry point checks the environment for usable variables and replaces 
them in the application server’s configuration file.

The same way can be used to alter other configurations as well.

In this example 5 different placeholders for the database connection are 
placed in the standalone.xml during build phase by the commands.cli script.

These placeholders are:

1. \#\#\#DB_HOST\#\#\#

    Hostname or IP address of the MySQL server host
2. \#\#\#DB_PORT\#\#\#

    TCP Port number on which the MySQL server is listening
3. \###DB_SCHEMA###

    The default database schema to apply to
4. \###DB_USER###

    The user name to use for connecting the database
5. \###DB_PASSWORD###

    The password of the user for connecting the database

To make sure these environment variables exist, they are all defined 
with default values in Dockerfile like this:

    ENV DB_HOST 10.0.0.1
    ENV DB_PORT 3306
    ENV DB_USER db_user
    ENV DB_PASSWORD db_password
    ENV DB_SCHEMA db_schema

Now when you run the container you can overwrite every of this values by 
supplying these variables to the run command.

    docker run -e DB_HOST=192.168.0.100 -e DB_USER=dbuser -e DB_PASSWORD=password -e DB_SCHEMA=myDB my-wildfly-app

When you have looked in the Dockerfile, you will have recognized that 
are two more environment variables defined.

    ENV AWS_KEY AKXXXXXXXXXXXXXXXXXX
    ENV AWS_SECRET fDEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

These is an example for passing in AWS credentials to the application 
server environment. They are used in the entry point script and placed 
as Java properties.

    exec /opt/jboss/wildfly/bin/standalone.sh -b=${host_ip} -bmanagement=${host_ip} -bunsecure=${host_ip} --server-config=standalone.xml -Djboss.server.log.dir=/data/logs  -Daws.accessKeyId=${AWS_KEY} -Daws.secretKey=${AWS_SECRET}

They are set to the properties: aws.accessKeyId and aws.secretKey.
When you are using the correct credentials provider for your AWS connection 
this values are used.

### Logging Volume
The Dockerfile defines a mount able volume, which is passed to the 
application server as base log dir.
This way you get your application server logs, where you want them. 
Outside of the container.

Definition of Volume in Dockerfile:

    VOLUME /data/logs

And in the entrypoint.sh it is passed to the application server by:

    -Djboss.server.log.dir=/data/logs

## Example
To use everything included in this example, you have to do two things.

1. Place a JEE application archive as described in usage chapter. 
    
    This application should include a persistence unit using the 
    "MyCustomDS" data source and uses the AWS Java SDK. 
    
2. Provide all environment variables in the docker run command

Full command example using all environment parameters, volumes and ports. 

    docker run --name my-app --rm -e DB_HOST=192.168.0.100 -e DB_PORT=3306 -e DB_USER=user -e DB_PASSWORD=password -e DB_SCHEMA=example -e AWS_KEY=XXXXXXXXXXXXXXXXXXXX -e AWS_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX -p 8080:8080 -p 9990:9990 -v /mnt/logs:/data/logs wildfly-app

Parameter description:

- --name

    defines a custom name for the container instance. Better to identify then the auto generated one
    
- --rm

    tells docker to remove this container after it stops. Keep the cache clean.

- -e 

    defines an environement variable, this parameter needs to be followed 
    by case sensitive property name and value, seperated by equals sign.

- -p

    defines the network NAT rules for binding docker host ports to 
    container ports.

- -v

   maps a local directory to the provied volume mount of the container.