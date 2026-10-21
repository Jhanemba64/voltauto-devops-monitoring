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

## Démarrage

```bash
cp .env.example .env   # puis changer les mots de passe
docker compose up -d --build
```

Puis ouvrir http://localhost:3000 (application), http://localhost:8080 (Zabbix)
et http://localhost:5601 (Kibana).

## Organisation git

- `main` : branche stable, on n'y committe pas directement après l'import initial.
- Une branche `feat/<sujet>` par évolution, fusionnée par pull request puis supprimée.
- Messages de commit au format [Conventional Commits](https://www.conventionalcommits.org/fr/).
