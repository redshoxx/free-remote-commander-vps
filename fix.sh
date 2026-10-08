#!/usr/bin/env bash
# Free Remote Commander VPS 1.2 - isolated loopback reverse proxy recovery.
# Keeps the existing MCP backend, internal Docker network, workspace, and secrets unchanged.
set -Eeuo pipefail
umask 077

ROOT="$(pwd -P)"
BACKEND='frc-vps-folder-12'
BACKEND_NETWORK='frc-vps-internal-12'
PROXY='frc-vps-proxy-12'
PROXY_NETWORK='frc-vps-proxy-net-12'
PROXY_FILE="$ROOT/.frc-proxy.mjs"
IMAGE='node:22-alpine'
PORT='17887'
OWNER='frc-vps-folder-12'
CREATED_FILE=0
CREATED_NETWORK=0
CREATED_PROXY=0
DONE=0

fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
cleanup() {
  local status=$?
  if [[ "$DONE" != 1 ]]; then
    if [[ "$CREATED_PROXY" == 1 ]]; then
      local label=''
      label="$(docker inspect -f '{{index .Config.Labels "frc.owner"}}' "$PROXY" 2>/dev/null || true)"
      if [[ "$label" == "$OWNER" ]]; then docker rm -f "$PROXY" >/dev/null 2>&1 || true; fi
    fi
    if [[ "$CREATED_NETWORK" == 1 ]]; then
      local label=''
      label="$(docker network inspect -f '{{index .Labels "frc.owner"}}' "$PROXY_NETWORK" 2>/dev/null || true)"
      if [[ "$label" == "$OWNER" ]]; then docker network rm "$PROXY_NETWORK" >/dev/null 2>&1 || true; fi
    fi
    if [[ "$CREATED_FILE" == 1 ]]; then rm -f -- "$PROXY_FILE"; fi
    printf '\nRecovery stopped; original MCP backend and workspace remain unchanged.\n' >&2
  fi
  return "$status"
}
trap cleanup EXIT

[[ "$EUID" -eq 0 ]] || fail 'Run as root in the existing installation folder.'
[[ -f "$ROOT/server/index.mjs" && -f "$ROOT/scripts/verify.sh" && -f "$ROOT/.env" ]] || fail 'Not inside the installed free-remote-commander-vps folder.'
[[ -d "$ROOT/workspace" && ! -L "$ROOT/workspace" ]] || fail 'Workspace missing or symbolic link.'
[[ "$(stat -c '%u:%g' "$ROOT/workspace")" == '65050:65050' ]] || fail 'Unexpected workspace ownership.'
[[ "$(stat -c '%a' "$ROOT/workspace")" == 700 ]] || fail 'Workspace mode is not 0700.'
for cmd in docker curl ss stat grep; do command -v "$cmd" >/dev/null || fail "Missing tool: $cmd"; done
[[ "$(docker inspect -f '{{index .Config.Labels "frc.owner"}}' "$BACKEND" 2>/dev/null)" == "$OWNER" ]] || fail 'Backend label does not match; refusing to touch it.'
[[ "$(docker inspect -f '{{.Config.Image}}' "$BACKEND")" == 'frc-vps-folder:1.2-local' ]] || fail 'Unexpected backend image.'
[[ "$(docker inspect -f '{{.State.Running}}' "$BACKEND")" == true ]] || fail 'Backend is not running; start it with docker start frc-vps-folder-12 first.'
[[ "$(docker network inspect -f '{{.Internal}}' "$BACKEND_NETWORK" 2>/dev/null)" == true ]] || fail 'Backend network is not internal.'
[[ "$(docker network inspect -f '{{index .Labels "frc.owner"}}' "$BACKEND_NETWORK")" == "$OWNER" ]] || fail 'Unexpected owner on backend network.'
[[ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$BACKEND")" == false ]] || fail 'Backend unexpectedly privileged.'
[[ "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$BACKEND")" == true ]] || fail 'Backend filesystem is not read-only.'
[[ "$(docker inspect -f '{{.Config.User}}' "$BACKEND")" == 65050:65050 ]] || fail 'Unexpected backend runtime user.'
[[ -r "$ROOT/.env" ]] || fail 'Configuration not readable.'
[[ "$(sed -n 's/^FRC_PORT=//p' "$ROOT/.env")" == "$PORT" ]] || fail 'Configuration uses an unexpected port.'
[[ "$(sed -n 's/^FRC_MCP_PATH=//p' "$ROOT/.env")" =~ ^/mcp/[a-f0-9]{64}$ ]] || fail 'Invalid MCP path secret in .env.'
if docker inspect "$PROXY" >/dev/null 2>&1; then fail 'Proxy container already exists; inspect it before retrying.'; fi
if docker network inspect "$PROXY_NETWORK" >/dev/null 2>&1; then fail 'Proxy network already exists; inspect it before retrying.'; fi
[[ ! -e "$PROXY_FILE" && ! -L "$PROXY_FILE" ]] || fail 'Proxy file already exists; refusing to overwrite.'
if ss -ltnH | grep -Eq '(^|:)17887([[:space:]]|$)'; then fail 'TCP port 17887 is already occupied.'; fi
docker image inspect "$IMAGE" >/dev/null 2>&1 || fail 'node:22-alpine is not in the local Docker cache; no automatic image pull permitted.'

cat > "$PROXY_FILE" <<'JS'
import http from 'node:http';
const backendHost = 'frc-vps-folder-12';
const backendPort = 8787;
const listenPort = 8787;
const server = http.createServer((request, response) => {
  const path = request.url || '';
  if (path !== '/health' && !/^\/mcp\/[0-9a-f]{64}$/.test(path)) {
    response.writeHead(404, { 'content-type': 'application/json', 'cache-control': 'no-store' });
    response.end('{"error":"Not found"}');
    return;
  }
  const headers = { ...request.headers, host: `${backendHost}:${backendPort}` };
  delete headers.connection;
  delete headers['proxy-connection'];
  delete headers.upgrade;
  const upstream = http.request({
    hostname: backendHost, port: backendPort, method: request.method,
    path, headers, timeout: 8000,
  }, (fromBackend) => {
    response.writeHead(fromBackend.statusCode || 502, fromBackend.headers);
    fromBackend.pipe(response);
  });
  upstream.on('timeout', () => upstream.destroy(new Error('Backend timeout')));
  upstream.on('error', () => {
    if (!response.headersSent) response.writeHead(502, { 'content-type': 'text/plain' });
    response.end('Backend unavailable');
  });
  request.on('error', () => upstream.destroy());
  request.pipe(upstream);
});
server.headersTimeout = 10000;
server.requestTimeout = 15000;
server.listen(listenPort, '0.0.0.0', () => console.error('FRC local proxy ready'));
JS
CREATED_FILE=1
chmod 0444 "$PROXY_FILE"

printf 'Creating a separate non-internal bridge for localhost port mapping (no existing networks altered).\n'
docker network create \
  --driver bridge \
  --opt com.docker.network.bridge.enable_icc=false \
  --opt com.docker.network.bridge.host_binding_ipv4=127.0.0.1 \
  --label "frc.owner=$OWNER" \
  "$PROXY_NETWORK" >/dev/null
CREATED_NETWORK=1

docker run --detach \
  --name "$PROXY" \
  --label "frc.owner=$OWNER" \
  --label 'frc.role=local-proxy' \
  --network "$PROXY_NETWORK" \
  --publish "127.0.0.1:$PORT:8787" \
  --mount "type=bind,source=$PROXY_FILE,target=/app/proxy.mjs,readonly" \
  --user 65050:65050 \
  --read-only --init --cap-drop ALL --security-opt no-new-privileges:true \
  --pids-limit 32 --memory 96m --cpus 0.25 \
  --restart unless-stopped \
  --log-driver json-file --log-opt max-size=2m --log-opt max-file=2 \
  "$IMAGE" node /app/proxy.mjs >/dev/null
CREATED_PROXY=1

docker network connect "$BACKEND_NETWORK" "$PROXY"

READY=0
for i in $(seq 1 25); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"ok"'; then READY=1; break; fi
  sleep 1
done
[[ "$READY" == 1 ]] || fail 'The local proxy health check failed; only the new proxy/network will be removed.'
PORT_OUTPUT="$(docker port "$PROXY" 8787/tcp)"
[[ "$PORT_OUTPUT" == "127.0.0.1:$PORT" ]] || fail 'Proxy port was not bound exclusively to 127.0.0.1.'
DONE=1
printf '\nSUCCESS: localhost connection repaired without altering the existing backend, workspace, secrets, Wardogs service, or firewall.\n'
printf 'Local health: http://127.0.0.1:%s/health\n' "$PORT"
printf 'Next: bash scripts/verify.sh\n'
