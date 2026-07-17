FROM docker.io/bitnami/minideb:trixie
RUN install_packages krb5-kdc-ldap krb5-admin-server supervisor tini
ADD supervisord.conf /etc/supervisord.conf
ADD docker-entrypoint.sh /

EXPOSE 749 464 88
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/docker-entrypoint.sh"]
