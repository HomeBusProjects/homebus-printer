# homebus-printer

This is a simple HomeBus data source which queries a printer using SNMP to track usage and ink and toner consumption.

## Usage

On its first run, `homebus-printer` needs to know how to find the HomeBus provisioning server.

```
bundle exec homebus-printer -b homebus-server-IP-or-domain-name -P homebus-server-port
```

The port will usually be 80 (its default value).

Once it's provisioned it stores its provisioning information in `.env.provisioning`.

`homebus-printer` also needs to know:

- the IP address or name of the printer it's monitoring
- the SNMP community string (default: 'public') for the printer

```
homebus-printer -a printer-IP-or-name -c community-string
```

