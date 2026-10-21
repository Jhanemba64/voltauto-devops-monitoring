# DevOps et monitoring — architecture web supervisée

Architecture web prête à l'emploi sous Docker, complétée par une chaîne de
supervision : monitoring (Zabbix), observabilité (Elasticsearch + Kibana) et
alerting (Grafana).

## Application

Projet repris de [docker/awesome-compose](https://github.com/docker/awesome-compose/tree/master/react-express-mysql)
(`react-express-mysql`) :

| Service    | Rôle                              | Accès                          |
|------------|-----------------------------------|--------------------------------|
| `frontend` | React (serveur de dev, port 3000) | http://localhost:3000          |
| `backend`  | API Node.js / Express             | http://127.0.0.1:80            |
| `db`       | MariaDB 10.6                      | réseau interne `private`       |

Le frontend appelle le backend via `/api` ; le backend répond avec la version
de la base (`{"message":"Hello from MySQL ..."}`).

## Supervision — Zabbix 7.0 LTS

| Service         | Rôle                                                  | Accès                                  |
|-----------------|-------------------------------------------------------|----------------------------------------|
| `zabbix-db`     | MySQL 8.4, base de configuration et d'historique      | réseau interne `monitoring`            |
| `zabbix-server` | Serveur Zabbix : collecte, déclencheurs, problèmes    | port 10051                             |
| `zabbix-web`    | Interface web                                         | http://localhost:8080 (Admin / zabbix) |
| `zabbix-agent`  | Agent 2, avec accès au socket Docker en lecture seule | réseau interne `monitoring`            |
| `zabbix-init`   | Tâche ponctuelle de configuration par l'API           | —                                      |

`zabbix-init` ([zabbix/init.sh](zabbix/init.sh)) pointe l'interface du host
« Zabbix server » vers le conteneur `zabbix-agent` et lui associe le template
**Docker by Zabbix agent 2**, limité aux conteneurs du projet : chaque
conteneur est découvert (état, CPU, mémoire, réseau) et un problème est levé
s'il s'arrête en erreur.

> Mot de passe `Admin / zabbix` par défaut : à changer dès la première connexion
> hors laboratoire.

## Observabilité — Elasticsearch / Kibana 8.19

| Service         | Rôle                                                       | Accès                    |
|-----------------|------------------------------------------------------------|--------------------------|
| `elasticsearch` | Stockage et recherche des logs (nœud unique)               | http://127.0.0.1:9200    |
| `kibana`        | Exploration des logs et tableaux de bord                   | http://localhost:5601    |
| `filebeat`      | Collecte des logs des conteneurs `frontend`, `backend`, `db` | réseau interne `monitoring` |
| `kibana-init`   | Tâche ponctuelle : import du tableau de bord               | —                        |

[filebeat/filebeat.yml](filebeat/filebeat.yml) découpe les logs HTTP du backend
(format morgan) en champs ECS : `http.request.method`, `url.original`,
`http.response.status_code`, `source.address`.

Le tableau de bord **Surveillance de l'application**
([kibana/dashboard.ndjson](kibana/dashboard.ndjson)) affiche le nombre de
requêtes, les erreurs 4xx/5xx, les requêtes par code retour dans le temps, le
volume de logs par service et les dernières erreurs du backend.

> Sécurité Elasticsearch désactivée et ports liés à `127.0.0.1` : configuration
> de laboratoire uniquement.

## Alerting — Grafana 13

| Service          | Rôle                                                        | Accès                                                  |
|------------------|-------------------------------------------------------------|--------------------------------------------------------|
| `grafana`        | Tableau de bord avec seuil et règle d'alerte                | http://localhost:3001 (admin / `GRAFANA_ADMIN_PASSWORD`) |
| `alert-receiver` | Récepteur webhook qui journalise les notifications          | `docker compose logs alert-receiver`                   |

Tout est provisionné par fichiers ([grafana/](grafana/)), sans configuration manuelle :

- **Source de données** : Elasticsearch, index `filebeat-*`.
- **Tableau de bord « Alerting application »** : erreurs HTTP 5xx par minute
  avec un seuil à 5 (ligne pointillée, barres rouges au-delà), compteur sur la
  fenêtre d'alerte, état de l'alerte, requêtes par code retour.
- **Règle « Erreurs 5xx backend »** : évaluée toutes les 30 s ; elle se
  déclenche quand le backend renvoie plus de 5 erreurs 5xx en 2 minutes,
  pendant au moins 30 s.
- **Notification** : point de contact webhook vers `alert-receiver`, qui simule
  un outil de messagerie (Slack, Teams, mail…). Il reçoit le déclenchement puis
  la résolution.

Pour tester : `docker compose stop db` pendant 2 à 3 minutes sous trafic, puis
`docker compose start db`.

## Démarrage

```bash
cp .env.example .env   # puis changer les mots de passe
docker compose up -d --build
```

Puis ouvrir http://localhost:3000 (application), http://localhost:8080 (Zabbix),
http://localhost:5601 (Kibana) et http://localhost:3001 (Grafana).

## Compte-rendu

Démarche, tests et captures : [docs/Compte-rendu.pdf](docs/Compte-rendu.pdf)
(source : [docs/compte-rendu.md](docs/compte-rendu.md)).

## Organisation git

- `main` : branche stable, on n'y committe pas directement après l'import initial.
- Une branche `feat/<sujet>` par évolution, fusionnée par pull request puis supprimée.
- Messages de commit au format [Conventional Commits](https://www.conventionalcommits.org/fr/).
