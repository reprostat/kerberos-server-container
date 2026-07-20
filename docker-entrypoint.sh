#!/bin/sh

if [ -z ${REALM} ]; then
    echo "No REALM provided. Using default example.com."
    REALM=example.com
fi
KRB5_REALM=$(echo $REALM | tr '[:lower:]' '[:upper:]')

if [ -z ${KRB5_KDC} ]; then
    echo "No KRB5_KDC provided. Using localhost instead."
    KRB5_KDC=localhost
fi

if [ -z ${KRB5_ADMINSERVER} ]; then
    echo "No KRB5_ADMINSERVER provided; Using ${KRB5_KDC} instead."
    KRB5_ADMINSERVER=${KRB5_KDC}
fi

if [ -z ${LDAP_URI} ]; then
    echo "No LDAP_URI provided; LDAP integration will not be available."
fi

if [ ! -e /etc/krb5.conf ] || [ "$(grep -oP '(?<=default_realm = ).*' /etc/krb5.conf)" != "${KRB5_REALM}" ]; then
    echo "No or generic Kerberos client configuration found. Creating one now."

if [ -z ${LDAP_DC} ]; then
    LDAP_DC=$(echo $REALM | sed 's/\./,dc=/g; s/^/dc=/')
fi

mkdir -p /var/log/kerberos

cat <<EOT1 > /etc/krb5.conf
[logging]
    kdc = FILE:/var/log/kerberos/krb5kdc.log
    admin_server = FILE:/var/log/kerberos/kadmin.log
    default = FILE:/var/log/kerberos/krb5lib.log

[libdefaults]
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    default_realm = ${KRB5_REALM}
 
 [realms]
 ${KRB5_REALM} = {
    kdc = ${KRB5_KDC}
    admin_server = ${KRB5_ADMINSERVER}
EOT1
    if [ ! -z ${LDAP_URI} ]; then
cat <<EOT2 >> /etc/krb5.conf
    default_domain = ${REALM}
    database_module = openldap_ldapconf
 }

[dbdefaults]
  ldap_kerberos_container_dn = cn=krbContainer,${LDAP_DC}

[dbmodules]
  openldap_ldapconf = {
    db_library = kldap

    # if either of these is false, then the ldap_kdc_dn needs to
    # have write access
    disable_last_success = true
    disable_lockout  = true

    # this object needs to have read rights on
    # the realm container, principal container and realm sub-trees
    ldap_kdc_dn = "uid=kdc-service,${LDAP_DC}"

    # this object needs to have read and write rights on
    # the realm container, principal container and realm sub-trees
    ldap_kadmind_dn = "uid=kadmin-service,${LDAP_DC}"

    ldap_service_password_file = /etc/krb5kdc/service.keyfile
    ldap_servers = ${LDAP_URI}
    ldap_conns_per_server = 5
  }
EOT2
    else    
        echo " }" >> /etc/krb5.conf
    fi
fi

echo "Creating default policy - Admin access for */admin"
echo "*/admin@${KRB5_REALM} *" > /etc/krb5kdc/kadm5.acl
echo "*/admin@${KRB5_REALM} *" > /var/lib/krb5kdc/kadm5.acl

if [ ! -f "/var/lib/krb5kdc/principal" ] && [ ! -f "/kerberos_initialized" ]; then

    echo "No Krb5 database found. Creating one now."

    if [ -z ${KRB5_ADMIN_PASSWORD} ]; then
        echo "No Password for kdb provided; Creating one now."
        KRB5_ADMIN_PASSWORD=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32})
        echo "Using Password ${KRB5_ADMIN_PASSWORD}"
    fi

    echo "Creating KDC configuration"
cat <<EOT > /var/lib/krb5kdc/kdc.conf
[kdcdefaults]
    kdc_listen = 88
    kdc_tcp_listen = 88
    
[realms]
    ${KRB5_REALM} = {
        kadmin_port = 749
        max_life = 12h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = aes256-cts
        supported_enctypes = aes256-cts:normal aes128-cts:normal
        default_principal_flags = +preauth
    }
EOT

    if [ ! -z ${LDAP_URI} ]; then
        kdb5_ldap_util -D cn=admin,${LDAP_DC} -w "$LDAP_ADMIN_PASSWORD" -H $LDAP_URI create -subtrees $LDAP_DC -r $KRB5_REALM -P "$KRB5_ADMIN_PASSWORD" -s

        kdb5_ldap_util -D cn=admin,${LDAP_DC} -w "$LDAP_ADMIN_PASSWORD" stashsrvpw -f /etc/krb5kdc/service.keyfile uid=kdc-service,${LDAP_DC} << EOT
$LDAP_KDC_PASSWORD
$LDAP_KDC_PASSWORD
EOT
        kdb5_ldap_util -D cn=admin,${LDAP_DC} -w "$LDAP_ADMIN_PASSWORD" stashsrvpw -f /etc/krb5kdc/service.keyfile uid=kadmin-service,${LDAP_DC} << EOT
$LDAP_KADMIN_PASSWORD
$LDAP_KADMIN_PASSWORD
EOT

        touch /kerberos_initialized
    else
    
        echo "Creating database"
        kdb5_util create -r ${KRB5_REALM} -s -P ${KRB5_ADMIN_PASSWORD}

        echo "Creating admin account"
        kadmin.local -q "addprinc -pw ${KRB5_ADMIN_PASSWORD} admin/admin@${KRB5_REALM}"
    fi
fi

/usr/bin/supervisord -c /etc/supervisord.conf
