# DevOps et monitoring — architecture web supervisée

[![CI](https://github.com/Jhanemba64/voltauto-devops-monitoring/actions/workflows/ci.yml/badge.svg)](https://github.com/Jhanemba64/voltauto-devops-monitoring/actions/workflows/ci.yml)

Architecture web 3 tiers prête à l'emploi sous Docker, complétée par une chaîne
de supervision complète :

- **monitoring** de l'infrastructure avec **Zabbix** ;
- **observabilité** de l'application avec **Elasticsearch + Kibana** (logs collectés par Filebeat) ;
- **alerting** avec **Grafana** : seuil, règle d'alerte, notification par webhook.

Tout est déclaratif et versionné : un seul `docker compose up` démarre les 14
services et applique toute la configuration (hôte Zabbix, tableaux de bord
Kibana et Grafana, règle d'alerte). Aucune manipulation dans les interfaces
n'est nécessaire.

📄 Compte-rendu détaillé (démarche, tests, captures) : [docs/Compte-rendu.pdf](docs/Compte-rendu.pdf)

## Sommaire

- [Architecture](#architecture)
- [Services et accès](#services-et-accès)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Scénarios de test](#scénarios-de-test)
- [Structure du dépôt](#structure-du-dépôt)
- [Arrêt et nettoyage](#arrêt-et-nettoyage)
- [Dépannage](#dépannage)
- [Intégration continue](#intégration-continue)
- [Sécurité et limites](#sécurité-et-limites)
- [Organisation git](#organisation-git)
- [Crédits et licences](#crédits-et-licences)

## Architecture

```
                         ┌──────────── réseau public ────────────┐
  navigateur ──:3000──▶  frontend (React) ──/api──▶ backend (Express) ──:80
                                                     │ réseau private
                                                     ▼
                                                  db (MariaDB)

  ─────────────────────────── réseau monitoring ───────────────────────────
  Zabbix   : zabbix-agent ──▶ zabbix-server ──▶ zabbix-db (MySQL) ◀── zabbix-web :8080
             (socket Docker : état, CPU, mémoire des conteneurs)
  Logs     : filebeat ──(logs frontend/backend/db)──▶ elasticsearch :9200 ◀── kibana :5601
  Alerting : grafana :3001 ──(requêtes ES)──▶ elasticsearch
             grafana ──(webhook)──▶ alert-receiver
  Init     : zabbix-init (API Zabbix), kibana-init (import du tableau de bord)
```

Trois réseaux isolent les flux : `public` (frontend ↔ backend), `private`
(backend ↔ base) et `monitoring` (outils de supervision).

## Services et accès

| Service | Image | Rôle | Accès |
|---|---|---|---|
| `frontend` | build local (Node) | application React (serveur de développement) | http://localhost:3000 |
| `backend` | build local (Node) | API Express, logs HTTP au format *morgan* | http://127.0.0.1:80 |
| `db` | `mariadb:10.6.4-focal` | base de l'application | interne |
| `zabbix-db` | `mysql:8.4` | base de Zabbix | interne |
| `zabbix-server` | `zabbix/zabbix-server-mysql:alpine-7.0.32` | collecte, déclencheurs, problèmes | port 10051 |
| `zabbix-web` | `zabbix/zabbix-web-nginx-mysql:alpine-7.0.32` | interface Zabbix | http://localhost:8080 — `Admin` / `zabbix` |
| `zabbix-agent` | `zabbix/zabbix-agent2:alpine-7.0.32` | agent 2 + plugin Docker (socket en lecture seule) | interne |
| `zabbix-init` | `alpine:3.22` | tâche ponctuelle : configuration par l'API Zabbix | — |
| `elasticsearch` | `elasticsearch:8.19.23` | stockage et recherche des logs (nœud unique) | http://127.0.0.1:9200 |
| `kibana` | `kibana:8.19.23` | exploration des logs, tableaux de bord | http://127.0.0.1:5601 |
| `filebeat` | `filebeat:8.19.23` | collecte des logs `frontend`, `backend`, `db` | interne |
| `kibana-init` | `alpine:3.22` | tâche ponctuelle : import du tableau de bord Kibana | — |
| `grafana` | `grafana/grafana:13.2.4` | tableau de bord avec seuil, règle d'alerte | http://localhost:3001 — `admin` / `GRAFANA_ADMIN_PASSWORD` |
| `alert-receiver` | `mendhak/http-https-echo:41` | récepteur webhook qui simule l'outil de notification | `docker compose logs alert-receiver` |

## Prérequis

- **Docker Engine 24+** avec **Docker Compose v2** (ou Docker Desktop).
- **8 Go de RAM** alloués à Docker : Elasticsearch (heap de 512 Mo), Kibana et
  les deux bases MySQL/MariaDB sont les plus gourmands.
- Environ **6 Go de disque** pour les images.
- Ports libres sur l'hôte : `80`, `3000`, `3001`, `5601`, `8080`, `9200`, `9229`,
  `9230`, `10051`.
- Sous **Linux**, si Elasticsearch redémarre en boucle :
  `sudo sysctl -w vm.max_map_count=262144`.

## Démarrage rapide

```bash
git clone https://github.com/Jhanemba64/voltauto-devops-monitoring.git
cd voltauto-devops-monitoring
cp .env.example .env          # puis remplacer les mots de passe
docker compose up -d --build
```

Au premier lancement, comptez environ **3 minutes** : création du schéma
Zabbix, puis démarrage d'Elasticsearch et de Kibana. Pour vérifier :

```bash
docker compose ps -a
# 12 services « Up », et zabbix-init / kibana-init « Exited (0) »
docker compose logs zabbix-init kibana-init | tail -2
# Host « Zabbix server » (...) : agent zabbix-agent:10050 + template Docker (...)
# Tableau de bord importé : http://localhost:5601/app/dashboards#/view/dashboard-surveillance-app
```

## Configuration

Les variables sont lues depuis `.env`, qui n'est pas versionné ; `.env.example`
sert de modèle. Docker Compose refuse de démarrer si une variable obligatoire
manque.

| Variable | Utilisée par | Rôle |
|---|---|---|
| `ZBX_DB_PASSWORD` | `zabbix-db`, `zabbix-server`, `zabbix-web` | mot de passe de l'utilisateur MySQL `zabbix` |
| `ZBX_DB_ROOT_PASSWORD` | `zabbix-db` | mot de passe root MySQL de Zabbix |
| `GRAFANA_ADMIN_PASSWORD` | `grafana` | mot de passe du compte `admin` |

Le mot de passe de la base applicative vient du projet d'origine
(`db/password.txt`, secret Docker).

Le **nom du projet compose** est fixé à `devops-monitoring` (`name:` dans
`compose.yaml`). Ne le changez pas sans adapter deux filtres qui en dépendent :
la découverte Docker de Zabbix (`zabbix/init.sh`) et la collecte de Filebeat
(`filebeat/filebeat.yml`).

## Utilisation

### Application

http://localhost:3000 affiche la version de la base, lue par le backend
(`GET /api/` → `{"message":"Hello from MySQL ..."}`).

### Zabbix — monitoring de l'infrastructure

`zabbix-init` ([zabbix/init.sh](zabbix/init.sh)) configure le host « Zabbix
server » par l'API, de façon idempotente :

- interface agent → `zabbix-agent:10050` ;
- template **Docker by Zabbix agent 2** ;
- découverte limitée aux conteneurs du projet (macro `{$DOCKER.LLD.FILTER.CONTAINER.MATCHES}`).

Où regarder :

- *Monitoring → Latest data*, filtre `Running` : l'état de chaque conteneur ;
- *Monitoring → Problems* : les incidents.

La découverte des conteneurs s'exécute toutes les 15 minutes. Pour la forcer :
*Data collection → Hosts → Discovery → Containers discovery → Execute now*.

### Kibana — observabilité de l'application

[filebeat/filebeat.yml](filebeat/filebeat.yml) collecte les logs des conteneurs
`frontend`, `backend` et `db`. Il découpe les logs HTTP du backend en champs ECS :
`http.request.method`, `url.original`, `http.response.status_code`,
`source.address`.

Tableau de bord **Surveillance de l'application** :
http://localhost:5601/app/dashboards#/view/dashboard-surveillance-app

On y trouve :

- les requêtes HTTP, les erreurs 4xx et 5xx, les lignes d'erreur du backend ;
- les requêtes par code retour dans le temps, et leur répartition ;
- le volume de logs par service ;
- les dernières erreurs du backend.

Dans *Discover*, la vue de données `Logs application (filebeat-*)` permet de
filtrer, par exemple `http.response.status_code >= 400`.

### Grafana — alerting

Tout est provisionné par fichiers ([grafana/](grafana/)).

| Élément | Détail |
|---|---|
| Source de données | Elasticsearch, index `filebeat-*` |
| Tableau de bord **Alerting application** | erreurs 5xx par minute avec **seuil à 5** (ligne pointillée, barres rouges au-delà), compteur sur la fenêtre d'alerte, état de l'alerte, requêtes par code retour |
| Règle **Erreurs 5xx backend** | somme des réponses 5xx sur 2 min **> 5**, évaluée toutes les 30 s, déclenchée après 30 s de dépassement |
| Notification | point de contact webhook → `alert-receiver` (envoi au déclenchement et à la résolution) |

Pour voir les notifications reçues :

```bash
docker compose logs alert-receiver | grep "POST /grafana"
```

## Scénarios de test

Générer du trafic pendant les tests :

```bash
# Bash (Linux, macOS, Git Bash)
for i in $(seq 1 600); do curl -s -o /dev/null http://localhost:3000/api/; sleep 1; done
```

```powershell
# PowerShell
1..600 | ForEach-Object { Invoke-WebRequest http://localhost:3000/api/ -UseBasicParsing | Out-Null; Start-Sleep 1 }
```

| Scénario | Commandes | Résultat attendu |
|---|---|---|
| Arrêt brutal d'un conteneur | `docker kill devops-monitoring-backend-1` puis `docker compose start backend` | Zabbix : problème *Container has been stopped with error code* en moins d'une minute, résolu au redémarrage |
| Requêtes en erreur 404 | `curl http://127.0.0.1/page-inexistante` | Kibana : compteur 4xx et code 404 dans les graphiques |
| Panne de la base sous trafic | `docker compose stop db`, attendre 2 à 3 min, puis `docker compose start db` | Kibana : erreurs 500 et traces `ECONNREFUSED`. Grafana : alerte *Pending* → *Firing*, notification `FIRING` puis `RESOLVED` dans `alert-receiver` |

## Structure du dépôt

```
.
├── compose.yaml                  # les 14 services, 3 réseaux, volumes
├── .env.example                  # modèle des mots de passe (copier en .env)
├── backend/  frontend/  db/      # application d'origine (awesome-compose)
├── zabbix/init.sh                # configuration Zabbix par l'API (idempotente)
├── filebeat/filebeat.yml         # collecte et découpage des logs
├── kibana/
│   ├── dashboard.ndjson          # vue de données + tableau de bord (export Kibana)
│   └── init.sh                   # import au démarrage (idempotent)
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/          # source Elasticsearch
│   │   ├── dashboards/           # déclaration du dossier de tableaux de bord
│   │   └── alerting/             # règle d'alerte, point de contact, politique
│   └── dashboards/               # tableau de bord « Alerting application »
├── docs/                         # compte-rendu (Markdown, PDF) et captures
├── .github/                      # workflow CI et configuration Dependabot
└── .yamllint.yaml                # règles de lint YAML
```

## Arrêt et nettoyage

```bash
docker compose down        # arrête et supprime les conteneurs, conserve les données
docker compose down -v     # supprime aussi les volumes (bases, index, Grafana)
```

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `localhost:80` affiche une autre page (Windows) | un service WSL écoute sur `::1:80` | utiliser `http://127.0.0.1:80` |
| `variable is not set` au démarrage | `.env` absent | `cp .env.example .env` |
| Aucun log dans Kibana | conteneurs renommés (nom de projet modifié) | garder `name: devops-monitoring` ou adapter `filebeat/filebeat.yml` |
| Tableau de bord Kibana absent | `kibana-init` lancé avant que Kibana soit prêt, ou objets supprimés | `docker compose run --rm kibana-init` |
| Hôte Zabbix « non disponible » | `zabbix-init` non exécuté | `docker compose run --rm zabbix-init` |
| Conteneurs absents de Zabbix | découverte toutes les 15 min | *Execute now* sur la règle *Containers discovery* |
| Modification du tableau de bord Grafana non visible | fichier provisionné non relu (montages Windows) | `docker compose restart grafana` |
| Elasticsearch ou Kibana s'arrête (code 137) | mémoire insuffisante | allouer 8 Go à Docker |

## Intégration continue

Chaque push et chaque pull request passent par le workflow [`ci.yml`](.github/workflows/ci.yml) :

| Contrôle | Outil |
|---|---|
| Syntaxe et style des fichiers YAML (compose, Filebeat, Grafana, workflows) | yamllint |
| Bonnes pratiques des Dockerfiles | Hadolint |
| Scripts d'initialisation Zabbix et Kibana | ShellCheck |
| Validité de `compose.yaml` et construction des images de l'application | Docker Compose |

Les actions GitHub sont épinglées par SHA de commit. Dependabot propose chaque mois les mises à jour des actions, des images de la stack et des images de base.

## Sécurité et limites

Cette configuration est **un laboratoire**, pas une base de production :

- sécurité Elasticsearch désactivée (ports Elasticsearch et Kibana liés à `127.0.0.1`) ;
- compte Zabbix `Admin / zabbix` par défaut, à changer dès la première connexion ;
- pas de TLS ; frontend servi par le serveur de développement React ;
- l'application de démonstration (awesome-compose) n'est pas maintenue : les dépendances npm
  du frontend comportent des vulnérabilités connues, sans incidence sur la chaîne de supervision,
  objet de ce dépôt (les correctifs automatiques Dependabot sont désactivés, les alertes restent suivies) ;
- le webhook simule l'outil de notification : remplacez son URL par celle d'un
  webhook Slack ou Teams, ou configurez un serveur SMTP, dans
  `grafana/provisioning/alerting/alerting.yml`.

## Organisation git

- `main` ne reçoit que des fusions de *pull request*, après l'import initial du projet d'origine.
- Une branche par évolution : `feat/...`, `fix/...`, `docs/...`. Fusion par
  *merge commit*, puis suppression de la branche.
- Messages au format [Conventional Commits](https://www.conventionalcommits.org/fr/).
- Historique des pull requests :

| PR | Branche | Objet |
|---|---|---|
| #1 | `feat/check_infra` | supervision de l'infrastructure avec Zabbix |
| #2 | `feat/check_app` | observabilité avec Elasticsearch et Kibana |
| #3 | `feat/alerting` | alerting avec Grafana |
| #4 | `fix/grafana-echelle-5xx` | seuil d'alerte lisible sans erreur 5xx |
| #5 | `docs/compte-rendu` | compte-rendu de l'exercice |
| #6 | `docs/readme-complet` | README complet pour la publication du dépôt |

## Crédits et licences

- Application : [docker/awesome-compose — react-express-mysql](https://github.com/docker/awesome-compose/tree/master/react-express-mysql),
  sous licence **CC0 1.0** ; le backend est dérivé de
  *node-docker-good-defaults* de Bret Fisher (licence MIT, voir [backend/LICENSE](backend/LICENSE)).
  Les Dockerfiles d'origine ont été allégés (étapes `dev-envs` inutilisées supprimées) et leurs images de base épinglées.
- Zabbix, Elastic Stack, Grafana et les autres images restent soumis à leurs
  licences respectives.
- Supervision, configuration et scripts de ce dépôt : licence **MIT** ([LICENSE](LICENSE)).
