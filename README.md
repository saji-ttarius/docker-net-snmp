# docker-net-snmp

## What this is
A small Docker image and compose setup that builds and runs Net‑SNMP (master agent) together with the Net‑SNMP example AgentX subagent (example-demon). Useful for testing SNMP queries, AgentX subagent behavior, and local SNMP tooling in a Debian Trixie environment.

### Stack
- **Language(s):** Dockerfile + shell (bash)
- **Framework / runtime:** Debian Trixie (slim) base images; Net‑SNMP (snmpd / snmp utilities)
- **Notable packages / components:** libsnmp-dev (build), snmpd, snmp (runtime), net-snmp/subagent-example (example subagent built from git)

## How it's organized
```
Dockerfile            # Multi-stage build: compiles net-snmp subagent example, creates runtime image
docker-compose.yml    # Example compose service exposing mapped ports, env vars, healthcheck
config/
  snmpd.conf          # snmpd configuration (AgentX, community, sysLocation, sysContact)
scripts/
  start.sh            # Entrypoint script: start snmpd, wait, start example-demon, wait
```

How it fits together:
- The Dockerfile uses a multi-stage build: the `builder` stage installs build tools and libsnmp-dev, clones net-snmp/subagent-example, and runs `make` to produce the example-demon subagent.
- The runtime image installs `snmpd` and `snmp` utilities, creates a non-root `snmp` user, copies the compiled example-demon and the provided `snmpd.conf` and `start.sh`, then runs `/start.sh` as the container command.
- `start.sh` launches `snmpd` (master agent) and then the example AgentX subagent. AgentX communication is configured in `config/snmpd.conf` (currently `agentXSocket tcp:127.0.0.1:705`).
- docker-compose.yml demonstrates mapping host ports (1610 -> container 161/udp, 705 -> 705/tcp), environment overrides, logging options, and a healthcheck that uses `snmpwalk` to query sys OIDs.

## How to run it
Clone the repo and run with Docker Compose (recommended):
```bash
git clone https://github.com/akiranger/docker-net-snmp.git
cd docker-net-snmp
docker-compose up --build
```

Or build and run with plain Docker:
```bash
docker build -t net-snmp-trixie:latest .
# Map host port 1610 to container 161/udp to avoid privileged host port requirements
docker run --rm -it --name snmp-trixie -p 1610:161/udp -p 705:705/tcp net-snmp-trixie:latest
```

Quick test from the host (docker-compose maps 1610 by default):
```bash
# SNMP v2c, community "public" (default in docker-compose.yml)
snmpwalk -v2c -c public 127.0.0.1:1610 .1.3.6.1.2.1.1
```

Notes and environment variables:
- docker-compose.yml shows optional environment variables you can set:
  - SNMP_COMMUNITY (default: public)
  - SNMP_LOCATION
  - SNMP_CONTACT
- The image runs the `snmp` user inside the container. The compose file maps host port 1610 instead of 161 to avoid needing root privileges on the host; mapping host port 161 to container 161 requires root privileges on the host.

## Configuration
- Edit config/snmpd.conf to change community strings, AgentX socket (tcp or unix domain socket), sysLocation, sysContact, or other snmpd behavior.
- The Dockerfile currently builds the subagent from the upstream net-snmp/subagent-example repository. To use a custom subagent:
  - Replace the git clone step or modify the Dockerfile to COPY your subagent source into the builder stage and run make there.
  - Ensure the compiled binary is placed at /opt/subagent-example/example-demon (or update scripts/start.sh accordingly).

## Troubleshooting
- If healthcheck fails, exec into the container and run `snmpwalk` locally:
  docker exec -it snmp-trixie snmpwalk -v2c -c public 127.0.0.1 .1.3.6.1.2.1.1
- If snmpd fails to bind to port 161 inside the container, confirm the container is not running as a user without permission; the image creates a non-root `snmp` user and relies on Docker port mapping — the container's internal 161/udp should be bindable.
- To inspect logs:
  docker-compose logs -f snmp-agent
  or check /var/log/snmp inside the container (compose mounts snmp-logs).

## Notes & next steps
- There is no LICENSE file in this repository. Add a LICENSE if you plan to publish or redistribute this image.
- The Dockerfile currently clones the subagent example at build time; for reproducible builds, pin the commit or vendor the subagent source.

## Try asking
- How can I add custom MIB files to this image and load them into snmpd? (see config/snmpd.conf and where to place MIBs)
- How do I change AgentX to use a UNIX domain socket instead of TCP? (check `agentXSocket` in config/snmpd.conf and update start/paths)
- I want to build a custom subagent from local sources instead of cloning upstream — which Dockerfile lines should I change?
