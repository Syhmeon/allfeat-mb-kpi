# Allfeat – MusicBrainz KPI Profiling

## 🎯 Vue d’ensemble

Allfeat KPI Profiling configure un environnement PostgreSQL local basé sur **MusicBrainz Docker officiel** pour mesurer la **qualité et la complétude des métadonnées musicales**.

Le schéma `allfeat_kpi` regroupe 10+ vues de référence (ISRC, ISWC, identifiants manquants, doublons, cohérence Work-Recording, niveaux de confiance Phase 1+2).

---

## ⚙️ Architecture

```
MusicBrainz Docker (v30)
     ↓  import auto (2–6 h)
PostgreSQL 15 (musicbrainz_db)
     ↓
Schéma allfeat_kpi  →  Excel/ODBC (Power Query)
```

---

## 🚀 Installation rapide (Windows + Docker)

### Prérequis
- **Docker Desktop** (Compose v2+)
- **PowerShell 5.1+**
- **8 GB RAM**, **80 GB disque** minimum

### Démarrage automatique (recommandé)
```powershell
.\quick_start_docker.ps1
```

Le script :
1. vérifie Docker et l’espace disque,  
2. importe la base MusicBrainz (2–6 h),  
3. crée le schéma `allfeat_kpi`,  
4. applique les 10 vues KPI,  
5. exécute les tests de validation.

---

## 🧭 Workflow de référence

1. **Import automatique** du dump via `musicbrainz/musicbrainz-server:v30`
2. **Vérification** du volume de données (`recording > 50 M`)
3. **Création du schéma KPI** : `sql/init/00_schema.sql`
4. **Application des vues** : `scripts/apply_views.ps1`
5. **Tests unifiés** : `scripts/tests.sql`
6. **Connexion Excel/ODBC** pour analyse Power Query

---

## 📊 KPI implémentés

| Catégorie | Vues principales | Objectif |
|------------|-----------------|-----------|
| **ISRC Coverage** | `kpi_isrc_coverage`, `…_samples` | Taux d’enregistrements avec ISRC |
| **ISWC Coverage** | `kpi_iswc_coverage`, `…_samples` | Taux d’œuvres avec ISWC |
| **IDs manquants** | `party_missing_ids_artist`, `…_samples` | Artistes sans IPI/ISNI |
| **Doublons ISRC** | `dup_isrc_candidates`, `…_samples` | Détection de doublons |
| **Incohérences** | `work_recording_inconsistencies` | Liens manquants Work–Recording |
| **Niveaux de confiance** | `confidence_*` | Score Phase 1 (cat.) + Phase 2 (num.) |

---

## 🧰 Utilisation

### Requêtes principales
```sql
SELECT * FROM allfeat_kpi.stats_overview;
SELECT * FROM allfeat_kpi.kpi_isrc_coverage;
SELECT * FROM allfeat_kpi.confidence_artist;
```

### Connexion Excel / ODBC
- Host : `127.0.0.1`, Port : `5432`  
- Database : `musicbrainz_db`  
- User : `musicbrainz`, Password : `musicbrainz`  
➡ Voir `excel/PowerQuery_guide.md` pour configuration complète.

---

## 🛠️ Maintenance & mise à jour

| Action | Commande |
|---------|-----------|
| Mettre à jour MusicBrainz | `docker compose pull && docker compose up -d` |
| Vérifier l’état | `. .\scripts\docker_helpers.ps1; Get-MBStatus` |
| Sauvegarder le schéma KPI | `pg_dump -n allfeat_kpi musicbrainz_db > kpi_backup.sql` |
| Rafraîchir statistiques | `ANALYZE;` |

---

## 🔍 Dépannage rapide

| Problème | Solution |
|-----------|-----------|
| Connexion PostgreSQL échoue | Vérifier `docker compose ps` et les ports |
| Import bloqué | Vérifier l’espace disque (`docker system df`) |
| Excel ne trouve pas la source ODBC | Recréer la source `MB_ODBC` |

---

## 📚 Documentation et support

- `excel/PowerQuery_guide.md` – Connexion Excel/ODBC  
- `docs/ODBC_Windows_guide.md` – Configuration ODBC  
- `scripts/tests.sql` – Tests unifiés  
- `Cursor-Rules/00–02.mdc` – Contexte minimal Cursor  
- `docs/CHANGELOG.md` – Historique des versions  

**Contact :** via issues GitHub du projet Allfeat.

---

**✅ Projet Allfeat – MusicBrainz KPI Phase 1 prêt à l’emploi.**
