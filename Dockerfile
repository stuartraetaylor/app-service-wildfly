
### This sample Dockerfile shows how to build a Wildfly image for use on Azure 
### App Service. The base image uses the Azul JRE, which receives free support
### when used on Azure. For more information about Azul on Azure: 
### https://docs.microsoft.com/en-us/java/azure/jdk/

FROM mcr.microsoft.com/java/jre-headless:8u242-zulu-alpine-with-tools

LABEL maintainer="Stuart Taylor"

ENV WILDFLY_VERSION 15.0.1.Final
ENV WILDFLY_SHA1 23d6a5889b76702fc518600fc5b2d80d6b3b7bb1
ENV JBOSS_HOME /opt/jboss/wildfly

ENV PORT 80
ENV SSH_PORT 2222

# Copy configuration files and JSP parking page
COPY tmp/standalone-full.xml    /tmp/wildfly/standalone-full.xml
COPY tmp/init_container.sh      /bin/init_container.sh
COPY tmp/sshd_config            /etc/ssh/
COPY tmp/index.jsp              /tmp/wildfly/webapps/ROOT/index.jsp

RUN apk add --update openssh-server bash openrc \
        && rm -rf /var/cache/apk/* \
        # Remove unnecessary services
        && rm -f /etc/init.d/hwdrivers \
                 /etc/init.d/hwclock \
                 /etc/init.d/mtab \
                 /etc/init.d/bootmisc \
                 /etc/init.d/modules \
                 /etc/init.d/modules-load \
                 /etc/init.d/modloop \
        # Can't do cgroups
        && sed -i 's/\tcgroup_add_service/\t#cgroup_add_service/g' /lib/rc/sh/openrc-run.sh \
        # Add Postgres certificate 
        && mkdir /root/.postgresql \
        && wget -O /root/.postgresql/root.crt https://www.digicert.com/CACerts/BaltimoreCyberTrustRoot.crt \
        # Set username and password for SSH
        && echo "root:Docker!" | chpasswd \
        # Allow access to the container entrypoint
        && chmod 755 /bin/init_container.sh

# Download and unpack Wildfly
RUN wget -O /tmp/wildfly-$WILDFLY_VERSION.tar.gz https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
        && sha1sum /tmp/wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
        && tar xvzf /tmp/wildfly-$WILDFLY_VERSION.tar.gz -C /tmp \
        && mkdir -p `dirname $JBOSS_HOME` \
        # Copy core Wildfly and the standalone configuration  
        && mv /tmp/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
        && mv /tmp/wildfly/standalone-full.xml $JBOSS_HOME/standalone/configuration/standalone-full.xml

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

EXPOSE 80 2222

ENTRYPOINT ["/bin/init_container.sh"]
