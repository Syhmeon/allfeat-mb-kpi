---
alwaysApply: false
---

# Environnement & déploiement

## Prérequis (Windows)
- ✅ Docker Desktop (avec Docker Compose v2+)
- ✅ Git Bash (inclus avec Git for Windows)
- ✅ PowerShell 5.1+ (inclus avec Windows 10+)
- ✅ ~100 GB d'espace disque libre (80 GB base MusicBrainz + 20 GB temporaire)
- ✅ 8 GB RAM minimum (16 GB recommandé)

## Infrastructure Docker

### MusicBrainz Docker officiel (v30)
- **Image:** musicbrainz/musicbrainz-server:v30
- **Base de données:** PostgreSQL 15 (conteneur musicbrainz-db)
- **Port:** 5432 (exposé sur localhost)
- **Import:** Automatisé via scripts officiels (2-6h)
- **Configuration:** DB_ONLY=1 (serveur web désactivé)

### Gestion des conteneurs
- **Démarrage:** `docker compose up -d`
- **Arrêt:** `docker compose down`
- **Logs:** `docker compose logs -f musicbrainz-db`
- **Mise à jour:** `docker compose pull && docker compose up -d`

## Scripts PowerShell (Phase 1)
- ✅ `apply_views.ps1` - Application des vues KPI sur base importée
- ✅ `tests.sql` - Tests de validation (smoke, golden, perf)
- ⚠️ `import_mb.ps1` - **OBSOLÈTE** (remplacé par import automatique Docker)
- ⚠️ `import_mb_fast.ps1` - **OBSOLÈTE** (remplacé par import automatique Docker)

## Connexion ODBC
- **Host:** localhost
- **Port:** 5432
- **Database:** musicbrainz_db
- **User:** musicbrainz
- **Password:** musicbrainz
- **Schema KPI:** allfeat_kpi

## CI/CD (optionnel)
- Build + apply_views + tests sur push
- Validation des vues KPI avant merge
- Tests de régression automatisés  

---