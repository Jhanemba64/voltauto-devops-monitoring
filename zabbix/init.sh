#!/bin/sh
# Configure le host « Zabbix server » via l'API Zabbix (idempotent) :
# - son interface agent pointe vers le conteneur zabbix-agent (au lieu de 127.0.0.1) ;
# - le template « Docker by Zabbix agent 2 » lui est associé pour superviser les conteneurs,
#   avec une découverte limitée aux conteneurs du projet compose.
set -eu
API=http://zabbix-web:8080/api_jsonrpc.php

# call <méthode> <paramètres JSON> [jeton] : affiche le résultat, échoue sur erreur API
call() {
  r=$(curl -sf "$API" -H 'Content-Type: application/json-rpc' ${3:+-H "Authorization: Bearer $3"} \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":$2,\"id\":1}") || return 1
  if echo "$r" | jq -e .error >/dev/null; then echo "$r" >&2; return 1; fi
  echo "$r" | jq -c .result
}

until call apiinfo.version '{}' >/dev/null 2>&1; do echo "Attente de l'API Zabbix..."; sleep 5; done

TOKEN=$(call user.login "{\"username\":\"Admin\",\"password\":\"${ZBX_ADMIN_PASSWORD:-zabbix}\"}" | jq -r .)
HOST=$(call host.get '{"filter":{"host":["Zabbix server"]},"selectInterfaces":["interfaceid"]}' "$TOKEN")
HOSTID=$(echo "$HOST" | jq -r '.[0].hostid')
IFID=$(echo "$HOST" | jq -r '.[0].interfaces[0].interfaceid')
TPLID=$(call template.get '{"filter":{"host":["Docker by Zabbix agent 2"]}}' "$TOKEN" | jq -r '.[0].templateid')

call hostinterface.update "{\"interfaceid\":\"$IFID\",\"useip\":0,\"dns\":\"zabbix-agent\"}" "$TOKEN" >/dev/null
call host.massadd "{\"hosts\":[{\"hostid\":\"$HOSTID\"}],\"templates\":[{\"templateid\":\"$TPLID\"}]}" "$TOKEN" >/dev/null
call host.update "{\"hostid\":\"$HOSTID\",\"macros\":[{\"macro\":\"{\$DOCKER.LLD.FILTER.CONTAINER.MATCHES}\",\"value\":\"^/$COMPOSE_PROJECT-\"}]}" "$TOKEN" >/dev/null
call user.logout '[]' "$TOKEN" >/dev/null
echo "Host « Zabbix server » ($HOSTID) : agent zabbix-agent:10050 + template Docker ($TPLID), conteneurs ^/$COMPOSE_PROJECT-"
