FROM ubuntu

RUN apt --yes update && \
    apt --yes upgrade && \
    apt --yes install \
        krb5-kdc-ldap ldap-utils \
        supervisor tini \
        && \
    apt --yes clean && \
    apt --yes autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY rootfs /

EXPOSE 464 88

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/opt/scripts/docker-entrypoint.sh"]
