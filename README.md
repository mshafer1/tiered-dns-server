# Tiered DNS Server

The objective of this project is to provide an easy stand up for a spoke-based DNS system.

## Why?

Because DNS filtering for basic trojan and malware sites is becoming a must.

## What do you mean?

```
                                 ┌─────────────────────┐
                                 │ upstream DNS server │
                                 └───────────┬─────────┘
                                             │ (DNS over HTTPS)
                                 ┌───────────▼─────────┐
             ┌───────────────────┼  tiered-dns-server  │────────────────────┐
             │                   └────────┬────────────┘                    │
             │                            │                                 │
             │                            │                                 │
             │                            │                                 │
             │                            │      (wiregaurd tunnels)        │
             │                            │                                 │
             │                            │                                 │
    ┌────────▼───────────┐     ┌──────────▼─────────┐         ┌─────────────▼──────┐
    │ on prem DNS server │     │ on prem DNS server │         │ on prem DNS server │
    │                    │     │                    │         │                    │
    └────────────────────┘     └────────────────────┘         └────────────────────┘
```

The objective is to provide a central server with multiple clients.
This central server should log all requests, and forward to a selected upstream (using DNS over HTTPS or DoH)

## Wait, why log everything?

The first objective in this build out is security.
Each "premise" is a location that I want to help the internet users to avoid phishing sites and malware.
Logging at the spoke level (and auditing those logs) allows the server admin to check on whether any premise has been
compromised (sites did get through that shouldn't have).

## Tech Stack

- Pi-hole used for DNS forwarding/filtering and logging
- dnscrypt-proxy (requirement from Pi-hole for DoH upstream)
- Chosen upstream DNS server (this is left to the user)
- Wireguard
  - wg-easy (admin Web UI)
- Cloudflare 0 Trust tunnel (in Docker)
  used for secure access to management without opening ports
- Automated backups of config using RSnapshot

## Why not (some favorite other project)?

In short, I'm building this for me and the premises I'm trying to make life easier and more secure for.
I will spare you the details on many of the choices in this tech stack, but if you would like to make a case for an alternative being a better option, feel free to open a Discussion.

## How is this tiered?

If an account is made with the upstream DNS server, it can be configured to do filtering.
Running Pi-hole at this level allows for a second layer of shared filtering.
Finally, the on-prem nodes are also able to filter their own lists (without forwarding).

In this way, there are 3 tiers of configuration available.
