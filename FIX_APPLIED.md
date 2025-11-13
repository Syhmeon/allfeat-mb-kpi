# ✅ PROBLÈME RÉSOLU - Authentification PostgreSQL

## 🔍 Problème Identifié

**Cause racine :** Conflit de port entre PostgreSQL Windows local et le conteneur Docker.

- PostgreSQL Windows (PID 6344) écoutait sur le port **5432**
- Le conteneur Docker essayait aussi d'utiliser le port **5432**
- Les connexions depuis Windows (DBeaver, psql.exe) allaient vers PostgreSQL Windows au lieu du conteneur Docker

## ✅ Solution Appliquée

**Port Docker changé de 5432 → 5433**

1. ✅ `docker-compose.yml` modifié : port mapping `5433:5432`
2. ✅ Conteneur redémarré avec le nouveau port
3. ✅ Configuration vérifiée :
   - `pg_hba.conf` : MD5 (compatible)
   - Mot de passe : MD5 hash valide
   - Connexion Docker : ✅ Fonctionne

## 📝 Configuration DBeaver

**Nouveaux paramètres de connexion :**

```
Host:         127.0.0.1
Port:         5433          ← CHANGÉ (était 5432)
Database:     musicbrainz_db
Username:     musicbrainz
Password:     musicbrainz
```

## 🧪 Test de Connexion

Pour tester depuis Windows :

```powershell
$env:PGPASSWORD="musicbrainz"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -p 5433 -U musicbrainz -d musicbrainz_db -c "SELECT 'Connection OK!' as status;"
```

## 📊 État Actuel

- ✅ Conteneur Docker : Port **5433** (accessible depuis Windows)
- ✅ PostgreSQL Windows : Port **5432** (non affecté)
- ✅ Authentification : MD5 (compatible)
- ✅ Mot de passe : `musicbrainz` (hash MD5 valide)

## 🔄 Rollback (si nécessaire)

Pour revenir au port 5432 :

1. Arrêter PostgreSQL Windows
2. Modifier `docker-compose.yml` : `"5432:5432"`
3. Redémarrer : `docker compose up -d db`

---

**Date de correction :** 2025-11-13
**Status :** ✅ RÉSOLU

