FROM centos:centos7

MAINTAINER kimdane 

RUN yum install -y epel-release \
    && yum update -y \
    && yum install -y 389-ds-base 389-adminutil \
    && yum clean all

COPY ds-setup.inf /ds-setup.inf
COPY users.ldif /users.ldif

# The 389-ds setup will fail because the hostname can't reliable be determined, so we'll bypass it and then install.
RUN useradd ldapadmin \
    && rm -fr /var/lock /usr/lib/systemd/system \
    # The 389-ds setup will fail because the hostname can't reliable be determined, so we'll bypass it and then install. \
    && sed -i 's/checkHostname {/checkHostname {\nreturn();/g' /usr/lib64/dirsrv/perl/DSUtil.pm \
    # Not doing SELinux \
    && sed -i 's/updateSelinuxPolicy($inf);//g' /usr/lib64/dirsrv/perl/* \
    # Do not restart at the end \
    && sed -i '/if (@errs = startServer($inf))/,/}/d' /usr/lib64/dirsrv/perl/* \
    && setup-ds.pl --silent --file /ds-setup.inf \
    && /usr/sbin/ns-slapd -D /etc/dirsrv/slapd-dir \ 
    && sleep 5 \
    && ldapadd -H ldap:/// -f /users.ldif -x -D "cn=Directory Manager" -w "password" \
    && mkdir -p /opt/ldif
    
VOLUME /opt/ldif
EXPOSE 389 636

CMD /usr/sbin/ns-slapd -D /etc/dirsrv/slapd-dir && sleep 5 && for f in $(ls ldif); do ldapmodify -H ldap:/// -f /opt/ldif/$f -x -D "cn=Directory Manager" -w "password"; done &&  tail -F /var/log/dirsrv/slapd-dir/access
