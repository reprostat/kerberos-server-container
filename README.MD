↖️ Table of Contents

# A Docker container of a Kerberos server

## Kerberos server
-----------

This is a reprostat fork of the gcavalcante8808/krb5-server image with MIT Kerberos v5.

Modifications:
  - installed on Debian trixie as base image
  - /etc/krb5.conf can be provided

## Deployment
------------

If you just want to deploy a Kerberos server, you can use docker-compose to bring it up quickly.
You may want to create and mount a volume on /var/lib/krb5kdc:

```yml
volumes:
    krb5kdc-data:

services:
   kdc:
     image: reprostat/kerberos-server-container
     build: .
     restart: always
     ports:
      - "88:88"
      - "464:464"
      - "749:749"
     environment:
       REALM: example.com
       KRB5_KDC: localhost
     volumes:
      - krb5kdc-data:/var/lib/krb5kdc
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
| `LDAP_URI`            | URI of the LDAP server (e.g., ldap://ldap)                           |                                                      | 
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

Note About Low Entropy and Kerberos Database Creation
-----------------------------------------------------

If your container won't start properly and show a message like "Loading random data" for a couple minutes, it indicates that the system don't have enough entropy available to provide a secure cryptographic loop to the program.

In this case you can use rngd (will be necessary to restart the container after this):

```
    /sbin/rngd
```

You can use `havaged` as well, as we can see in the digitalOcean tutorial:

https://www.digitalocean.com/community/tutorials/how-to-setup-additional-entropy-for-cloud-servers-using-haveged

After this, you just need to restart your container and it is g-n-go.

Other Information
-----------------

This container uses the Kerberos packages provided by the Debian Team. Take a look at the Debian site to verify the available versions of the package.

For more information on how to configure the clients or even the server take a loot at the MIT Kerberos Documentation.

Check the issues page at github if you want to contribute or profile a bug/request/enhancement.
