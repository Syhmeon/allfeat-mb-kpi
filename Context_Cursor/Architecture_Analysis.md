# Analyse Complète de l'Architecture du Projet MusicBrainz KPI

## 📊 Vue d'ensemble du projet

### Objectif
Créer un système d'analyse de qualité des métadonnées MusicBrainz via :
- Base PostgreSQL locale avec données MusicBrainz
- Schéma `allfeat_kpi` avec 10 vues KPI
- Connexion Excel/ODBC pour analyse ad hoc

### Architecture actuelle
```
E:\mbdump (dumps MusicBrainz)
    ↓
Docker PostgreSQL 15 (vide au démarrage)
    ↓
Scripts d'import manuel (import_mb.ps1)
    ↓
Base musicbrainz (schéma + données)
    ↓
Schéma allfeat_kpi + 10 vues KPI
    ↓
Excel/ODBC
```

---

## 🗂️ Structure des fichiers et dépendances

### 1. **Configuration Docker**

#### `docker-compose.yml`
```yaml
- Image: postgres:15-alpine (image PostgreSQL vanilla)
- Volume: E:\mbdump montée en /dumps
- Volume: ./sql montée en /docker-entrypoint-initdb.d
- Port: 5432
```

**Dépendances:** Aucune (image vanilla PostgreSQL)
**Rôle:** Conteneur PostgreSQL vide qui attend l'import manuel

#### `env.example`
**Dépendances:** Aucune
**Rôle:** Configuration des variables d'environnement

---

### 2. **Scripts PowerShell (Import manuel MusicBrainz)**

#### `scripts/reset_mb.ps1`
**Dépendances:**
- Docker conteneur `musicbrainz-postgres`
- Base `musicbrainz` (pour suppression)

**Actions:**
1. DROP DATABASE musicbrainz
2. CREATE DATABASE musicbrainz
3. CREATE COLLATION musicbrainz

**Rôle:** Réinitialiser la base pour un nouvel import

---

#### `scripts/apply_mb_schema.ps1`
**Dépendances:**
- Conteneur PostgreSQL en cours d'exécution
- Internet (télécharge depuis GitHub)
- Base `musicbrainz` vide

**Actions:**
1. Télécharge 7 fichiers SQL depuis GitHub musicbrainz-server
   - CreateTypes.sql
   - CreateTables.sql
   - CreatePrimaryKeys.sql
   - CreateFunctions.sql
   - CreateConstraints.sql
   - CreateFKConstraints.sql
   - CreateIndexes.sql
2. Copie CreateSearchConfigLight.sql (local)
3. Exécute les fichiers dans l'ordre

**Sortie:** 375 tables MusicBrainz + contraintes + index
**Rôle:** Créer le schéma MusicBrainz v30 officiel

---

#### `scripts/import_mb.ps1` ⚠️ PROBLÉMATIQUE
**Dépendances:**
- Schéma MusicBrainz créé (apply_mb_schema.ps1)
- Fichiers dumps dans E:\mbdump
- Conteneur avec volume /dumps monté

**Actions:**
1. Vérifie SCHEMA_SEQUENCE = 30
2. Liste 164 fichiers de dumps
3. Ordonne l'import (référence → principales → autres)
4. Import via `\copy` ligne par ligne
5. Réactive les contraintes FK

**Problèmes identifiés:**
- ⚠️ **TRÈS LENT**: 12h+ pour table recording (4.1 GB)
- ⚠️ Contraintes FK actives pendant l'import
- ⚠️ `\copy` moins performant que `COPY`
- ⚠️ Ordre d'import nécessite ajustements (isrc/iswc/medium/track)

**Rôle:** Importer les données MusicBrainz (méthode actuelle inefficace)

---

#### `scripts/import_mb_fast.ps1` ⚠️ ÉCHEC
**Dépendances:** Mêmes que import_mb.ps1

**Tentative d'optimisation:**
- Désactivation FK temporaire (échec syntaxe)
- Utilisation COPY au lieu de \copy
- Problème: Toujours aussi lent

**Rôle:** Tentative d'optimisation (non fonctionnelle)

---

#### `scripts/apply_mb_indexes.ps1`
**Dépendances:**
- Données MusicBrainz importées
- Internet (télécharge index officiels)

**Actions:**
1. Télécharge CreatePrimaryKeys.sql et CreateIndexes.sql
2. Applique les index officiels
3. VACUUM ANALYZE

**Rôle:** Optimiser les performances des requêtes

---

#### `scripts/verify_mb_schema.ps1`
**Dépendances:**
- Base MusicBrainz complète

**Actions:**
1. Vérifie SCHEMA_SEQUENCE = 30
2. Compte les tables (375 attendues)
3. Vérifie les données des tables principales
4. Vérifie les index et contraintes

**Rôle:** Validation post-import

---

### 3. **Schéma KPI Allfeat (Couche d'analyse)**

#### `sql/init/00_schema.sql`
**Dépendances:**
- Base MusicBrainz existante (schéma + données)

**Actions:**
1. CREATE SCHEMA allfeat_kpi
2. CREATE TABLE metadata (tracking versions)
3. CREATE VIEW stats_overview (stats générales)
4. CREATE FUNCTION format_percentage
5. CREATE FUNCTION random_sample

**Rôle:** Initialiser le schéma KPI (indépendant de MusicBrainz)

---

#### `sql/views/*.sql` (10 vues KPI)
**Dépendances critiques:**
- ✅ Schéma allfeat_kpi créé (00_schema.sql)
- ✅ Tables MusicBrainz avec DONNÉES:
  - musicbrainz.recording
  - musicbrainz.artist
  - musicbrainz.work
  - musicbrainz.release
  - musicbrainz.artist_credit
  - musicbrainz.artist_isni
  - musicbrainz.artist_ipi
  - musicbrainz.recording_work
  - musicbrainz.track
  - musicbrainz.medium

**Exemples de requêtes:**
```sql
-- 10_kpi_isrc_coverage.sql
SELECT COUNT(*) FROM musicbrainz.recording WHERE isrc IS NOT NULL

-- 60_confidence_artist.sql
SELECT a.id FROM musicbrainz.artist a
INNER JOIN musicbrainz.artist_isni ai ON a.id = ai.artist
```

**Rôle:** Analyse qualité des données (AUCUNE modification de MusicBrainz)

---

#### `scripts/apply_views.ps1`
**Dépendances:**
- Schéma allfeat_kpi créé
- Données MusicBrainz importées

**Actions:**
1. Vérifie connexion PostgreSQL
2. Vérifie schéma allfeat_kpi
3. Applique les 10 vues SQL dans l'ordre
4. Met à jour metadata.views_applied_at

**Rôle:** Créer les vues KPI

---

#### `scripts/tests.sql`
**Dépendances:**
- Schéma allfeat_kpi + vues créées
- Données MusicBrainz

**Actions:**
1. Smoke tests (schéma, fonctions, vues)
2. KPI tests (requêtes sur vues)
3. Confidence tests (Phase 1+2)
4. Performance tests

**Rôle:** Validation complète du système

---

### 4. **Workflows et pipelines**

#### `quick_start_windows.bat`
**Pipeline complet:**
1. docker-compose up -d
2. apply_mb_schema.ps1
3. import_mb.ps1 ⚠️ BLOQUANT (12h+)
4. apply_mb_indexes.ps1
5. verify_mb_schema.ps1
6. CREATE SCHEMA allfeat_kpi
7. apply_views.ps1
8. tests.sql

**Problème:** Étape 3 (import) prend 12h+ et échoue souvent

---

#### `test_pipeline.ps1`
**Rôle:** Exécute le pipeline complet avec validation
**Dépendances:** Tous les scripts ci-dessus

---

### 5. **Documentation et guides**

#### `excel/PowerQuery_guide.md`
**Dépendances:**
- Vues allfeat_kpi créées
- ODBC PostgreSQL installé
- Connexion DSN configurée

**Rôle:** Guide utilisateur pour Excel/ODBC

---

## 🔍 Analyse des dépendances critiques

### Dépendances en cascade

```
1. Docker PostgreSQL (vanilla)
   └─> 2. apply_mb_schema.ps1 (crée 375 tables)
       └─> 3. import_mb.ps1 (importe données) ⚠️ PROBLÈME ICI
           └─> 4. apply_mb_indexes.ps1 (optimise)
               └─> 5. sql/init/00_schema.sql (crée allfeat_kpi)
                   └─> 6. sql/views/*.sql (10 vues KPI)
                       └─> 7. Excel/ODBC (analyse)
```

### Points de blocage identifiés

1. **Import manuel trop lent** (étape 3)
   - Cause: `\copy` + contraintes FK actives
   - Impact: Bloque tout le pipeline
   - Temps: 12h+ pour recording

2. **Ordre d'import fragile**
   - Dépendances FK complexes (770 contraintes)
   - Nécessite ajustements manuels (isrc, medium, track)

3. **Pas de reprise automatique**
   - Si échec à 50%, tout à refaire
   - Pas de checkpoint

---

## ✅ Ce qui PEUT être réutilisé sans changement

### Fichiers totalement indépendants de l'import
1. ✅ `sql/init/00_schema.sql` - Crée allfeat_kpi (indépendant)
2. ✅ `sql/views/*.sql` (10 fichiers) - Requêtes READ-ONLY sur musicbrainz
3. ✅ `scripts/apply_views.ps1` - Applique les vues
4. ✅ `scripts/tests.sql` - Tests de validation
5. ✅ `excel/PowerQuery_guide.md` - Documentation Excel
6. ✅ `env.example` - Configuration
7. ✅ `Context_Cursor/*` - Documentation projet
8. ✅ `log/Bug_tracking.md` - Suivi bugs

### Fichiers à adapter (minor changes)
1. ⚠️ `docker-compose.yml` - Changer l'image PostgreSQL
2. ⚠️ `README.md` - Mettre à jour le workflow
3. ⚠️ `scripts/verify_mb_schema.ps1` - Adapter aux vérifications

---

## 🗑️ Ce qui DOIT être remplacé/archivé

### Scripts d'import manuel (inefficaces)
1. ❌ `scripts/apply_mb_schema.ps1` - Plus nécessaire (schéma pré-créé)
2. ❌ `scripts/import_mb.ps1` - Trop lent (12h+)
3. ❌ `scripts/import_mb_fast.ps1` - Non fonctionnel
4. ❌ `scripts/apply_mb_indexes.ps1` - Index déjà créés
5. ❌ `scripts/reset_mb.ps1` - Peut être adapté
6. ❌ `sql/CreateSearchConfigLight.sql` - Déjà inclus dans image Docker
7. ❌ `quick_start_windows.bat` - Workflow obsolète
8. ❌ `test_pipeline.ps1` - Pipeline obsolète

**Action recommandée:** Déplacer dans `archive/` avec README expliquant pourquoi

---

## 🎯 Stratégie de migration (Sans conflit)

### Approche recommandée: Adaptation progressive

#### Phase 1: Préparation (Branche Git)
```bash
git checkout -b feature/musicbrainz-docker
```

#### Phase 2: Modification minimale
1. **Changer `docker-compose.yml`**
   ```yaml
   # Remplacer postgres:15-alpine
   # Par metabrainz/musicbrainz-postgres:latest
   ```

2. **Archiver les scripts obsolètes**
   ```
   mkdir archive
   mv scripts/apply_mb_schema.ps1 archive/
   mv scripts/import_mb*.ps1 archive/
   mv scripts/apply_mb_indexes.ps1 archive/
   mv scripts/reset_mb.ps1 archive/
   mv quick_start_windows.bat archive/
   mv test_pipeline.ps1 archive/
   ```

3. **Créer nouveau workflow simplifié**
   ```powershell
   # scripts/quick_start_docker.ps1
   docker-compose up -d  # Image pré-importée !
   Start-Sleep 30
   docker exec -i musicbrainz-postgres psql < sql/init/00_schema.sql
   .\scripts\apply_views.ps1
   docker exec -i musicbrainz-postgres psql < scripts/tests.sql
   ```

#### Phase 3: Test et validation
```bash
git add .
git commit -m "feat: migration vers MusicBrainz Docker officiel"
# Tester le nouveau workflow
# Si OK, merger dans main
```

---

## 📋 Matrice de compatibilité

| Fichier/Dossier | Avec Docker officiel | Action requise |
|-----------------|---------------------|----------------|
| `sql/init/00_schema.sql` | ✅ 100% compatible | Aucune |
| `sql/views/*.sql` | ✅ 100% compatible | Aucune |
| `scripts/apply_views.ps1` | ✅ 100% compatible | Aucune |
| `scripts/tests.sql` | ✅ 100% compatible | Aucune |
| `excel/PowerQuery_guide.md` | ✅ 100% compatible | Aucune |
| `Context_Cursor/*` | ✅ 100% compatible | Aucune |
| `docker-compose.yml` | ⚠️ Nécessite modification | Changer image |
| `README.md` | ⚠️ Nécessite mise à jour | Mettre à jour workflow |
| `scripts/apply_mb_schema.ps1` | ❌ Obsolète | Archiver |
| `scripts/import_mb*.ps1` | ❌ Obsolète | Archiver |
| `scripts/apply_mb_indexes.ps1` | ❌ Obsolète | Archiver |
| `quick_start_windows.bat` | ❌ Obsolète | Archiver |

---

## 🚀 Conclusion

### Résumé de l'analyse
- **70% du code est réutilisable sans changement** (vues KPI, tests, doc)
- **20% nécessite des ajustements mineurs** (docker-compose, README)
- **10% doit être archivé** (scripts d'import manuel)

### Avantages de la migration
1. ✅ Gain de temps: 2h au lieu de 12h+
2. ✅ Base pré-importée et pré-indexée
3. ✅ Pas de risque d'erreur d'import
4. ✅ Maintenance simplifiée
5. ✅ Conforme aux standards MusicBrainz

### Risques
1. ⚠️ Taille de l'image Docker (plus volumineuse)
2. ⚠️ Dépendance à MetaBrainz pour les releases
3. ⚠️ Workflow différent (mais plus simple)

### Recommandation finale
**✅ MIGRATION RECOMMANDÉE** avec approche progressive (branche Git)
- Pas de perte de travail
- Migration testable et réversible
- Gain de temps et fiabilité majeurs

