#!/bin/sh
# Importe dans Kibana la vue de données filebeat-* et le tableau de bord
# « Surveillance de l'application » (idempotent : overwrite=true).
set -eu
KIBANA=http://kibana:5601

until curl -sf "$KIBANA/api/status" | grep -q '"overall":{"level":"available"'; do
  echo "Attente de Kibana..."; sleep 5
done

curl -sf -X POST "$KIBANA/api/saved_objects/_import?overwrite=true" \
  -H 'kbn-xsrf: true' --form file=@/dashboard.ndjson | grep -q '"success":true'
echo "Tableau de bord importé : http://localhost:5601/app/dashboards#/view/dashboard-surveillance-app"
