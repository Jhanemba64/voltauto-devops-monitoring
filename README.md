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

## Démarrage

```bash
docker compose up -d --build
```

Puis ouvrir http://localhost:3000.

## Organisation git

- `main` : branche stable, on n'y committe pas directement après l'import initial.
- Une branche `feat/<sujet>` par évolution, fusionnée par pull request puis supprimée.
- Messages de commit au format [Conventional Commits](https://www.conventionalcommits.org/fr/).
