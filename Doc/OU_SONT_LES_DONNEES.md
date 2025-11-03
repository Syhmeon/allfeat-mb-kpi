# 📍 Où sont stockées les données MusicBrainz

## 📦 Volumes Docker (persistants)

Les données sont stockées dans des **volumes Docker** qui persistent même si les conteneurs s'arrêtent :

### 1. Volume `musicbrainzkpi_pgdata`
**Contenu :** Base de données PostgreSQL complète (tables, index, données)

**Chemin physique sur Windows (via WSL2) :**
```
\\wsl$\docker-desktop-data\data\docker\volumes\musicbrainzkpi_pgdata\_data
```

**Taille attendue après import complet :** ~80 GB

### 2. Volume `musicbrainzkpi_dbdump`
**Contenu :** Archives téléchargées (mbdump.tar.bz2, etc.) + fichier `.for-non-commercial-use`

**Chemin physique sur Windows (via WSL2) :**
```
\\wsl$\docker-desktop-data\data\docker\volumes\musicbrainzkpi_dbdump\_data
```

**Taille attendue :** ~6-10 GB (archives compressées)

---

## 🔍 Comment accéder aux données

### Option 1 : Via PostgreSQL (RECOMMANDÉ)

Une fois Docker Desktop redémarré et les conteneurs lancés :

```powershell
# Se connecter à PostgreSQL
docker exec -it musicbrainz-db psql -U musicbrainz -d musicbrainz

# Voir les tables
\dt musicbrainz.*

# Compter les enregistrements
SELECT COUNT(*) FROM musicbrainz.recording;
SELECT COUNT(*) FROM musicbrainz.artist;
SELECT COUNT(*) FROM musicbrainz.work;
```

### Option 2 : Via Windows Explorer (accès direct aux fichiers)

1. Ouvrir l'Explorateur Windows
2. Dans la barre d'adresse, taper :
   ```
   \\wsl$\docker-desktop-data\data\docker\volumes\
   ```
3. Naviguer vers :
   - `musicbrainzkpi_pgdata\_data` pour la base PostgreSQL
   - `musicbrainzkpi_dbdump\_data` pour les archives

⚠️ **Attention :** Ne modifiez PAS ces fichiers directement !

### Option 3 : Via ODBC/Excel

Une fois l'import terminé et les vues KPI créées :

```
DSN: MB_ODBC
Host: localhost
Port: 5432
Database: musicbrainz
User: musicbrainz
Password: musicbrainz
Schema: allfeat_kpi
```

---

## 📊 Vérifier la taille des données

### Taille de la base PostgreSQL

```powershell
docker exec musicbrainz-db psql -U musicbrainz -d musicbrainz -c "
SELECT pg_size_pretty(pg_database_size('musicbrainz')) as database_size;
"
```

### Taille des volumes Docker

```powershell
docker system df -v
```

---

## ⚠️ Important

1. **Les volumes persistent** : Même si vous arrêtez Docker Desktop ou supprimez les conteneurs, les données restent dans les volumes.

2. **Pour supprimer les données** (ATTENTION !) :
   ```powershell
   docker compose down -v  # Supprime conteneurs ET volumes
   ```

3. **Les données sont dans WSL2**, pas directement sur E:\ (sauf si vous avez configuré un volume nommé externe, ce qui n'est pas le cas actuellement).

4. **Pour changer l'emplacement** : Il faudrait modifier `docker-compose.yml` pour utiliser un bind mount au lieu d'un volume nommé.

---

## 🎯 Après redémarrage de Docker Desktop

Une fois Docker Desktop redémarré :

```powershell
# Vérifier que les volumes existent toujours
docker volume ls | grep musicbrainzkpi

# Redémarrer les services
cd "C:\Dev\ALLFEAT\MusicBrainz KPI"
docker compose up -d db redis

# Vérifier l'état de l'import
docker compose ps
docker compose logs musicbrainz --tail 50
```

Les données seront toujours là ! ✅

