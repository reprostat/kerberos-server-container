↖️ Table of Contents

# A Docker container of a Kerberos server

## Kerberos server
-----------

This is a reprostat fork of the gcavalcante8808/krb5-server image with MIT Kerberos v5, which allows to deploy a Kerberos server with optional LDAP backend.

Modifications:
  - installed on ubuntu as base image
  - previous configuration, including /etc/krb5.conf and database can be provided
  - LDAP backend can be specified

## Deployment
------------

If you just want to deploy a Kerberos server, you can use docker-compose to bring it up quickly.
You may want to create and mount a volume on /var/lib/krb5kdc:

```yml
volumes:
  kerberos-server-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /tmp/kerberos-server-data

services:
  kerberos-server:
    container_name: kerberos-server
    image: reprostat/kerberos-server-container:latest
    build:
      context: .
      dockerfile: primary.dockerfile
    environment:
      - REALM=example.com
      - KRB5_KDC=localhost
      - LDAP_URI=ldaps://10.10.10.10
      - LDAP_CACERT=/etc/ldap/ca.crt
      - LDAP_ADMIN_PASSWORD=adminpass
      - LDAP_KADMIN_PASSWORD=kadminpass
      - LDAP_KDC_PASSWORD=kdcpass
    ports:
      - 88:88
      - 464:464
      - 749:749
    volumes:
      - kerberos-server-data:/etc/krb5kdc
      - $PWD/ca.crt:/etc/ldap/ca.crt
```

## Usage
-----

You need to supply the following environment variables:

| Environment variables | Description                                                          | Default value                                        |
| --------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| `REALM`               | Kerberos/LDAP realm name in DNS format                               | example.com                                          |
| `KRB5_KDC`            | Kerberos KDC address. It's recommended that you use a text DNS entry | localhost (you can't setup the KDC slaves later)     |
| `KRB5_ADMINSERVER`    |                                                                      | same value that was provided for `KRB5_KDC`          |
| `KRB5_ADMIN_PASSWORD` | KDB and **admin** password for the database                          | one will be created and printed in the first startup |
| `LDAP_URI`            | URI of the LDAP server (e.g., ldaps://ldap)                          |                                                      | 
| `LDAP_CACERT`         | CA certificate for the LDAP server when using TLS (i.e., ldaps://)   |                                                      | 
| `LDAP_DC`             | Domain base (e.g., dc=example,dc=com)                                | generated from `REALM`                               |
| `LDAP_ADMIN_PASSWORD` | LDAP admin user password                                             |                                                      |
| `LDAP_KADMIN_PASSWORD`| cn=kadmin user password in LDAP                                      |                                                      |
| `LDAP_KDC_PASSWORD`   | cn=kdc user password in LDAP                                         |                                                      |
 
**CAVE: write down the KDB/admin password, it is necessary to login with kadmin and unblock the kdb files**

**N.B.: LDAP_\* variables are optional. If they to not exist (only LDAP_URI is checked), then LDAP integration will not be configured**

With all this information, you can now run the container:

```
    docker run -d --name kerberos-server -e REALM=example.com -e KRB5_KDC=localhost -e KRB5_ADMIN_PASSWORD=mypass -p 88:88 -p 464:464 -p 749:749 reprostat/kerberos-server-container
```

If you haven't provided the password, find it at the logs:

```
    docker logs kerberos-server
```

To acquire a ticket from your new domain, create a krb5.conf on "/etc" with the following config:

```
[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = YOURREALM.FQDN
 
[realms]
 YOURREALM.FQDN = {
    kdc = localhost
    admin_server = localhost
 }

```

By default Kerberos client on Apple laptops is having troubles to connect to KDC with following error message:
```
kinit admin@EXAMPLE.COM
admin@EXAMPLE.COM's password: 
kinit: krb5_get_init_creds: unable to reach any KDC in realm EXAMPLE.COM, tried 1 KDC
```

It happens because Kerberos client doesn't fall to TCP protocol to fix it, you have to change your krb5.conf file
```
[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = YOURREALM.FQDN
 
[realms]
 YOURREALM.FQDN = {
    kdc = tcp/localhost:88
    admin_server = tcp/localhost:749
 }

```

After that changes you can successfully run `kinit` command mentioned above

By Default just the user admin/admin@REALM is created; to test the setup, try to acquire the ticket with the following commands:

```
    kinit admin/admin@YOURREALM.FQDN # Will prompt for the password provided or the generated.
    klist
```

**The Default Kadmin policy allows all members inside /admin policy to do anything in your kerberos database(default to * perm); if you need a more simple user, you can create users with /service policy (which defaults to aci perm)**.

Other Information
-----------------

This container uses the Kerberos packages provided by the Ubuntu Team. Take a look at the Ubuntu site to verify the available versions of the package.

For more information on how to configure the clients or even the server take a loot at the MIT Kerberos Documentation.

Check the issues page at github if you want to contribute or profile a bug/request/enhancement.
