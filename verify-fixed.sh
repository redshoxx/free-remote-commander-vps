#!/usr/bin/env bash
# Free Remote Commander VPS 1.2 - read-only runtime audit for Docker 29 local proxy mode.
# Does NOT create, alter, stop, or restart containers. Does not print MCP secrets.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
NAME='frc-vps-folder-12'
NET='frc-vps-internal-12'
PORT=17887
WORKSPACE="$ROOT/workspace"
[[ -f "$ROOT/.env" ]] || { echo 'Missing .env: install first' >&2; exit 1; }
PATH_SECRET="$(sed -n 's/^FRC_MCP_PATH=//p' "$ROOT/.env")"
[[ "$PATH_SECRET" =~ ^/mcp/[0-9a-f]{64}$ ]] || { echo 'Invalid local endpoint secret' >&2; exit 1; }
URL="http://127.0.0.1:$PORT$PATH_SECRET"
post() { curl -fsS --max-time 10 -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' --data "$1" "$URL"; }

printf '[1/9] Standalone container running ... '
[[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" == true ]]
[[ "$(docker inspect -f '{{index .Config.Labels "frc.owner"}}' "$NAME")" == "$NAME" ]]
echo OK
printf '[2/9] Local health ... '
[[ "$(curl -fsS --max-time 8 "http://127.0.0.1:$PORT/health")" == *'"ok"'* ]]
echo OK
printf '[3/9] MCP initialize ... '
[[ "$(post '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')" == *'"protocolVersion"'* ]]
echo OK
printf '[4/9] Allowed tools only ... '
TOOLS="$(post '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')"
[[ "$TOOLS" == *'"list_directory"'* && "$TOOLS" != *'"delete_file"'* && "$TOOLS" != *'"execute_command"'* ]]
echo OK
printf '[5/9] Path traversal rejected ... '
ATTACK="$(post '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"read_text_file","arguments":{"path":"../../etc/passwd"}}}')"
[[ "$ATTACK" == *'"isError":true'* ]]
echo OK
printf '[6/9] Invalid endpoint rejected ... '
[[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://127.0.0.1:$PORT/mcp/not-authorized")" == 404 ]]
echo OK
printf '[7/9] Port bound to localhost only ... '
# Docker Engine 29 may publish ports using nftables DNAT without a socket visible to ss.
# Verify Docker's explicit IPv4 localhost binding AND actual end-to-end health above.
PROXY='frc-vps-proxy-12'
PROXY_NET='frc-vps-proxy-net-12'
[[ "$(docker inspect -f '{{.State.Running}}' "$PROXY")" == true ]]
[[ "$(docker inspect -f '{{index .Config.Labels "frc.owner"}}' "$PROXY")" == "$NAME" ]]
[[ "$(docker port "$PROXY" 8787/tcp)" == "127.0.0.1:$PORT" ]]
echo OK
printf '[8/9] Isolation and mount ... '
[[ "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$NAME")" == true ]]
[[ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$NAME")" == false ]]
[[ "$(docker inspect -f '{{json .HostConfig.CapDrop}}' "$NAME")" == *ALL* ]]
[[ "$(docker inspect -f '{{json .HostConfig.SecurityOpt}}' "$NAME")" == *no-new-privileges* ]]
[[ "$(docker inspect -f '{{.Config.User}}' "$NAME")" == 65050:65050 ]]
MOUNTS="$(docker inspect -f '{{json .Mounts}}' "$NAME")"
[[ "$MOUNTS" == *"$WORKSPACE"* && "$MOUNTS" != *docker.sock* ]]
[[ "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$PROXY")" == true ]]
[[ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$PROXY")" == false ]]
[[ "$(docker inspect -f '{{json .HostConfig.CapDrop}}' "$PROXY")" == *ALL* ]]
[[ "$(docker inspect -f '{{json .HostConfig.SecurityOpt}}' "$PROXY")" == *no-new-privileges* ]]
[[ "$(docker inspect -f '{{.Config.User}}' "$PROXY")" == 65050:65050 ]]
PROXY_MOUNTS="$(docker inspect -f '{{json .Mounts}}' "$PROXY")"
[[ "$PROXY_MOUNTS" == *'.frc-proxy.mjs'* && "$PROXY_MOUNTS" != *docker.sock* && "$PROXY_MOUNTS" != *"$WORKSPACE"* ]]
echo OK
printf '[9/9] Dedicated internal network ... '
[[ "$(docker network inspect -f '{{.Internal}}' "$NET")" == true ]]
[[ "$(docker network inspect -f '{{index .Labels "frc.owner"}}' "$NET")" == "$NAME" ]]
[[ "$(docker network inspect -f '{{.Internal}}' "$PROXY_NET")" == false ]]
[[ "$(docker network inspect -f '{{index .Labels "frc.owner"}}' "$PROXY_NET")" == "$NAME" ]]
[[ "$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$NAME")" == "$NET" ]]
PROXY_NETWORKS="$(docker inspect -f '{{json .NetworkSettings.Networks}}' "$PROXY")"
[[ "$PROXY_NETWORKS" == *"$NET"* && "$PROXY_NETWORKS" == *"$PROXY_NET"* ]]
echo OK
printf '\nAll nine runtime checks passed. Existing containers were not inspected or changed by the installer.\n'
