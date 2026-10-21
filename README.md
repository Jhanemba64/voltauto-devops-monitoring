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

## Démarrage

```bash
cp .env.example .env   # puis changer les mots de passe
docker compose up -d --build
```

Puis ouvrir http://localhost:3000 (application) et http://localhost:8080 (Zabbix).

## Organisation git

- `main` : branche stable, on n'y committe pas directement après l'import initial.
- Une branche `feat/<sujet>` par évolution, fusionnée par pull request puis supprimée.
- Messages de commit au format [Conventional Commits](https://www.conventionalcommits.org/fr/).
