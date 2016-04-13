# JBoss WildFly Application Container example
This is an Docker container based on jboss/wildfly official container.
Enhancing it with a usefull configuration and deployment process.
This container is designed to make it as simple as possible to start, configure, 
deploy and run a JEE application on WilFly application server.

It shows how to enable runtime configuration over environment variables, to make 
it realy easy to deploy hughe amounts of this container.

## Usage
First clone this repository.

    git clone https://github.com/BITFORCE-IT/WildflyApp

Then enter the repository Directory "WildflyApp"

Copy your JEE application package (.ear,.war,.sar) into the repository folder.

Open the "Dockerfile" with your favorite text editor. Uncomment and change 
the ADD my application line. To copy your application package into the container.

    ADD Application.ear /opt/jboss/wildfly/standalone/deployments/Application.ear 

Build the container running the build command inside the repository folder.

    docker build -t my-wildlfy-app .
    
Then run it with the run command.

    docker run my-wildfly-app

> Doing this will start the wildfly server, trying to deploy your application. 
> Which will in most cases work. But this container also setups a datasource which 
> tries to connect to a mysql db. That will give you some error or probaly let the 
> application server crash. This is no mistake! Further configuration and customization 
> is explained later.

## Structure
This container has the following structure:

1. bin/

    in here are scripting stuff that is copied to /start and made runable
        
    1. entrypoint.sh     
        is the entrypoint shell script of this container
    
2. customization/

    in here are wildfly configuration stuff, which in run at container build
    
    1. execute.sh        
        this script is run by Dockerfile on container build. It starts 
        the application server, enters the CLI and runs a command script 
        to configure wildfly for your needs.
        Thanks to [this blog post](https://goldmann.pl/blog/2014/07/23/customizing-the-configuration-of-the-wildfly-docker-image/)
        
    2. commands.cli         
        WildFly configuration commands file, which can be used with the 
        wildfly CLI to configure the wildfly for your needs.

3. modules/

    this folder is copied over the wildfly modules folder. Place your modules 
    like jdbc drivers in here, in the correct folder structure.
    For example a mysql driver jar would end up in `modules/system/layers/base/com/mysql`


4. Dockerfile

    The Dockerfile him self.
    
## Description
What is happening here? It's very simple. This container does two things.

1. It build a docker container based on jboss/wildfly. In the build process
the application server is started one time and the CLI is used to configure 
the application server. Doing this it places placeholders in configuration file 
which are later replaced by environment variables on start up.

2. On start, the container uses his own entrypoint script, which checks environment 
and replaces environment variables with placeholders in configuration files and then 
starts the application server.

The result is, that you have a container which you can easyly setup during build 
phase by simple editing the commands.cli file and finetun to actual environment on 
start.

### Configure wildfly during build phase
The wildfly application server in this container is configured over his CLI 
during the build phase. This done by calling the customization/execute.sh script 
inside the Dockerfile.

    RUN /opt/jboss/wildfly/customization/execute.sh standalone standalone.xml

It accepts two parameters:

- start in standalone or domain mode
- used configuration

When not giving any parameter the defaults are standalone mode with standalone.xml 
configuration.

> This example is tested with standalone mode and standalone.xml file. 
> When using domain mode or other configuration file, look through Dockerfile 
> , entrypoint.sh and execute.sh for hardcoded configuration filenames and command names.
> Change them to your needs.

The execute.sh script will start the wildfly and waits till it is up and running in default configuration 
like it comes from Jboss. Then it uses the wildfly CLI to run the commands.cli file. After this it stops 
wildfly again.