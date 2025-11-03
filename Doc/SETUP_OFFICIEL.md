# 🎯 Setup MusicBrainz Officiel - DB-Only Mirror

**Date:** 15 octobre 2025  
**Source:** [github.com/metabrainz/musicbrainz-docker](https://github.com/metabrainz/musicbrainz-docker)  
**Configuration:** DB-only mirror (PostgreSQL + données uniquement)

---

## ✅ État actuel

**Import en cours** - Le `musicbrainzkpi-musicbrainz-run-*` exécute `createdb.sh -fetch` pour télécharger et importer la base MusicBrainz complète.

**Temps estimé:** 2-6 heures selon votre configuration matérielle.

---

## 📋 Ce qui a été configuré

### 1. Docker Compose officiel DB-only
- ✅ `docker-compose.yml` : Configuration DB-only mirror (pas de serveur web)
- ✅ Services: `db` (PostgreSQL 16), `musicbrainz` (import), `redis` (requis)
- ✅ Port 5432 exposé sur l'hôte pour connexions ODBC/Excel
- ✅ Volumes persistants: `pgdata`, `dbdump`

### 2. Images Docker officielles
- ✅ Utilise directement les images MetaBrainz officielles (pas de build local)
- ✅ `metabrainz/musicbrainz-docker-db:16-build0` (PostgreSQL pré-configuré)
- ✅ `metabrainz/musicbrainz-docker-musicbrainz:v-2025-10-13.0-build1` (scripts d'import)
- ✅ Versions configurables via variables d'environnement dans `docker-compose.yml`

### 3. Configuration
- ✅ `docker-compose.yml` : Utilise directement les images (simplifié)
- ✅ Variables d'environnement : `POSTGRES_VERSION`, `DB_BUILD_SEQUENCE`, `MUSICBRAINZ_SERVER_VERSION`, `MUSICBRAINZ_BUILD_SEQUENCE`
- ✅ `default/postgres.env` : Credentials (user=musicbrainz, password=musicbrainz)

---

## 🔍 Monitoring de l'import

### Vérifier l'état du conteneur

```powershell
docker ps --filter "name=musicbrainz"
```

Le conteneur `musicbrainzkpi-musicbrainz-run-*` doit être `Up`.

### Suivre les logs

```powershell
# Logs en temps réel
docker compose logs -f musicbrainz

# Dernières lignes
docker compose logs --tail 100 musicbrainz
```

**Signes que l'import progresse :**
- Messages de téléchargement depuis `data.metabrainz.org`
- Messages `COPY` pour chaque table
- Aucune erreur `FATAL` ou `ERROR`

### Vérifier la progression (une fois PostgreSQL accessible)

```powershell
docker exec musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins as rows_inserted
FROM pg_stat_user_tables 
WHERE schemaname = 'musicbrainz' 
  AND n_tup_ins > 0
ORDER BY n_tup_ins DESC 
LIMIT 10;
"
```

---

## 🎯 Après l'import terminé

### Critères de succès

- ✅ PostgreSQL accessible : `docker exec musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz -c "SELECT 1;"`
- ✅ Table `musicbrainz.recording` : > 50 millions de lignes
- ✅ Table `musicbrainz.artist` : > 2 millions de lignes
- ✅ Table `musicbrainz.work` : > 30 millions de lignes

### Étapes post-import

#### 1. Démarrer les services en mode permanent

```powershell
# Arrêter le conteneur d'import temporaire
docker compose down

# Démarrer les services en mode permanent (DB-only mirror)
docker compose up -d
```

#### 2. Initialiser le schéma Allfeat KPI

```powershell
Get-Content sql\init\00_schema.sql | docker exec -i musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz
```

#### 3. Appliquer les 10 vues KPI

```powershell
$views = Get-ChildItem sql\views\*.sql | Sort-Object Name
foreach ($v in $views) {
    Write-Host "Applique $($v.Name)..."
    Get-Content $v.FullName | docker exec -i musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz
}
```

#### 4. Tester les vues

```powershell
Get-Content scripts\tests.sql | docker exec -i musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz их
```

---

## 🔧 Commandes utiles

### Arrêter/redémarrer

```powershell
docker compose down      # Arrêter tous les services
docker compose up -d     # Redémarrer en mode permanent
docker compose restart   # Redémarrer sans recréer
```

### Accès PostgreSQL

```powershell
# Shell interactif
docker exec -it musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz

# Exécuter une requête
docker exec musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz -c "SELECT COUNT(*) FROM musicbrainz.recording;"

# Exécuter un script SQL
Get-Content script.sql | docker exec -i musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz
```

### Vérifier l'espace disque

```powershell
docker system df
docker exec musicbrainzkpi-db-1 df -h
```

---

## 📊 Connexion Excel/ODBC

### Paramètres DSN

```
Data Source Name: MB_ODBC
Database:         musicbrainz
Server:           localhost (ou 127.0.0.1)
Port:             5432
User Name:        musicbrainz
Password:         musicbrainz
Schema:           allfeat_kpi (pour les vues KPI)
```

Voir `excel/PowerQuery_guide.md` pour les requêtes pré-configurées.

---

## 🚨 Dépannage

### Import semble bloqué

```powershell
# Vérifier les processus actifs
docker exec musicbrainzkpi-db-1 ps aux | grep postgres

# Vérifier les requêtes en cours
docker exec musicbrainzkpi-db-1 psql -U musicbrainz -d musicbrainz -c "
SELECT pid, application_name, state, query_start, LEFT(query, 50) 
FROM pg_stat_activity 
WHERE datname = 'musicbrainz';
"
```

### Erreur "out of memory"

Augmenter la RAM allouée à Docker Desktop : Settings → Resources → Memory → 8GB minimum.

### Erreur "no space left on device"

```powershell
# Vérifier l'espace disque
docker system df
docker volume ls

# Si nécessaire, libérer de l'espace ou changer le volume dans docker-compose.yml
```

---

## 📚 Documentation officielle

- **Repo GitHub :** https://github.com/metabrainz/musicbrainz-docker
- **README officiel :** Contient toutes les instructions détaillées
- **Troubleshooting :** `TROUBLESHOOTING.md` dans le repo officiel

---

## ⚠️ Notes importantes

1. **Cette configuration est DB-only** : Pas de serveur web MusicBrainz, uniquement PostgreSQL + données
2. **Import initial long** : 2-6h pour la première importation complète
3. **Mises à jour** : Pour mettre à jour les données, re-exécuter `createdb.sh -fetch` (ou configurer la réplication)
4. **Windows** : Ce setup fonctionne sur Windows avec Docker Desktop + WSL2

---

**🎯 Statut actuel : Import en cours - Attendre 2-6h avant de continuer**

