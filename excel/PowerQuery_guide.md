# Guide Power Query - Allfeat MusicBrainz KPI

## Configuration de base

### 1. Installation du pilote ODBC PostgreSQL

1. **Télécharger le pilote** :
   - Aller sur https://www.postgresql.org/ftp/odbc/versions/msi/
   - Télécharger la version appropriée pour votre Windows

2. **Installer le pilote** :
   - Exécuter le fichier `.msi` téléchargé
   - Suivre les instructions d'installation

### 2. Configuration de la source de données ODBC

1. **Ouvrir l'Administrateur ODBC** :
   - Windows : Rechercher "Sources de données ODBC"
   - Sélectionner "Administrateur ODBC"

2. **Créer une nouvelle source** :
   - Onglet "Sources de données utilisateur"
   - Bouton "Ajouter"
   - Sélectionner "PostgreSQL Unicode"
   - Cliquer "Terminer"

3. **Configurer la connexion** :
   ```
   Nom de la source de données : MB_ODBC
   Serveur : 127.0.0.1
   Port : 5432
   Base de données : musicbrainz
   Nom d'utilisateur : musicbrainz
   Mot de passe : musicbrainz
   ```

4. **Tester la connexion** :
   - Bouton "Test"
   - Vérifier que "Connexion réussie" s'affiche

### 3. Configuration Excel

1. **Ouvrir Excel**
2. **Créer une nouvelle connexion Power Query** :
   - Onglet "Données"
   - "Obtenir des données" → "À partir d'autres sources" → "À partir d'ODBC"
   - Sélectionner "MB_ODBC"
   - Entrer une requête SQL de test :
     ```sql
     SELECT COUNT(*) as total_artists FROM musicbrainz.artist WHERE type = 1;
     ```

3. **Importer les données** :
   - Cliquer "Charger"
   - Vérifier que les données s'affichent

## Requêtes Power Query (Validées contre les vues SQL réelles)

### 1. KPI Overview (Tableau de bord principal)

```sql
SELECT 
    'ISRC Coverage' as kpi_name,
    isrc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_recordings,
    recordings_with_isrc
FROM allfeat_kpi.kpi_isrc_coverage

UNION ALL

SELECT 
    'ISWC Coverage' as kpi_name,
    iswc_coverage_pct as coverage_percentage,
    duplicate_rate_pct as duplicate_percentage,
    total_works,
    works_with_iswc
FROM allfeat_kpi.kpi_iswc_coverage

UNION ALL

SELECT 
    'Artist ID Completeness' as kpi_name,
    overall_id_completeness_pct as coverage_percentage,
    0 as duplicate_percentage,
    total_artists,
    artists_with_ipi + artists_with_isni
FROM allfeat_kpi.party_missing_ids_artist;
```

### 2. ISRC Duplicates (Top 20 par risque)

```sql
SELECT 
    isrc,
    duplicate_count,
    duplicate_risk_score,
    risk_level,
    name_similarity,
    artist_similarity,
    length_similarity
FROM allfeat_kpi.dup_isrc_candidates
ORDER BY duplicate_risk_score DESC
LIMIT 20;
```

### 3. Missing Artist IDs (Top 50)

```sql
SELECT 
    artist_name,
    artist_gid,
    ipi_status,
    isni_status,
    id_completeness_score
FROM allfeat_kpi.party_missing_ids_artist_samples
ORDER BY id_completeness_score ASC
LIMIT 50;
```

### 4. Confidence Levels (Résumé par entité)

```sql
SELECT 
    'Artist' as entity_type,
    phase1_high_pct,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_artist

UNION ALL

SELECT 
    'Work' as entity_type,
    phase1_high_pct,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_work

UNION ALL

SELECT 
    'Recording' as entity_type,
    phase1_high_pct,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_recording

UNION ALL

SELECT 
    'Release' as entity_type,
    phase1_high_pct,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_release;
```

### 5. Work-Recording Inconsistencies

```sql
SELECT 
    inconsistency_type,
    count,
    percentage_of_inconsistencies
FROM allfeat_kpi.work_recording_inconsistencies
ORDER BY count DESC;
```

### 6. Samples - Recordings without ISRC

```sql
SELECT 
    recording_name,
    artist_name,
    recording_gid
FROM allfeat_kpi.kpi_isrc_coverage_samples
WHERE sample_type = 'Recordings without ISRC'
LIMIT 20;
```

### 7. Samples - Works without ISWC

```sql
SELECT 
    work_name,
    work_type,
    language_code,
    work_gid
FROM allfeat_kpi.kpi_iswc_coverage_samples
WHERE sample_type = 'Works without ISWC'
LIMIT 20;
```

### 8. Samples - Low Confidence Artists

```sql
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'Low'
ORDER BY phase2_confidence_score ASC
LIMIT 20;
```

### 9. Samples - High Confidence Artists

```sql
SELECT 
    artist_name,
    artist_gid,
    phase2_confidence_score,
    phase2_confidence_level
FROM allfeat_kpi.confidence_artist_samples
WHERE phase2_confidence_level = 'High'
ORDER BY phase2_confidence_score DESC
LIMIT 20;
```

## Feuilles Excel recommandées

1. **Dashboard** : Vue d'ensemble avec graphiques
2. **KPI Overview** : Tableau de bord principal
3. **ISRC Analysis** : Analyse des codes ISRC
4. **Artist IDs** : Analyse des identifiants artistes
5. **Confidence Levels** : Niveaux de confiance par entité
6. **Inconsistencies** : Incohérences Work-Recording
7. **Samples** : Échantillons pour analyse détaillée

## PivotTables recommandées

### 1. Analyse des doublons ISRC
- **Lignes** : `risk_level`, `name_similarity`
- **Colonnes** : `artist_similarity`
- **Valeurs** : `COUNT(duplicate_count)`, `AVG(duplicate_risk_score)`

### 2. Couverture des identifiants artistes
- **Lignes** : `ipi_status`, `isni_status`
- **Valeurs** : `COUNT(artist_name)`, `AVG(id_completeness_score)`

### 3. Niveaux de confiance par entité
- **Lignes** : `entity_type`, `phase2_confidence_level`
- **Valeurs** : `AVG(phase2_confidence_score)`, `AVG(phase1_high_pct)`

## Graphiques recommandés

1. **Graphique en barres** : Couverture ISRC/ISWC par entité
2. **Graphique en secteurs** : Répartition des niveaux de confiance
3. **Graphique en aires** : Évolution des doublons ISRC par risque
4. **Graphique en colonnes** : Comparaison des identifiants manquants

## Instructions d'utilisation dans Excel

### Configuration Power Query

1. **Ouvrir Excel**
2. **Onglet "Données"** → **"Obtenir des données"** → **"À partir d'autres sources"** → **"À partir d'ODBC"**
3. **Sélectionner "MB_ODBC"**
4. **Coller une des requêtes ci-dessus**
5. **Cliquer "OK"**
6. **"Charger"** ou **"Transformer les données"**

### Optimisations recommandées

1. **Limiter les résultats** : Toujours utiliser `LIMIT` dans les requêtes
2. **Actualisation automatique** : Configurer l'actualisation à l'ouverture du fichier
3. **Cache des données** : Activer le cache Power Query
4. **Filtres** : Utiliser des filtres dans Power Query plutôt que dans SQL

### Automatisation

Pour automatiser le rafraîchissement :
1. Aller dans "Données" → "Propriétés de la requête"
2. Cocher "Actualiser les données lors de l'ouverture du fichier"
3. Définir un intervalle de rafraîchissement automatique

## Dépannage

### Problèmes courants

#### 1. Erreur de connexion ODBC
**Problème** : `[Microsoft][ODBC Driver Manager] Data source name not found`

**Solutions** :
- Vérifier que PostgreSQL est démarré (`docker compose up -d`)
- Tester la connexion avec `psql -h 127.0.0.1 -U musicbrainz -d musicbrainz`
- Vérifier que le pilote ODBC PostgreSQL est installé
- Recréer la source de données ODBC

#### 2. Requêtes lentes
**Problème** : `Query took too long to execute`

**Solutions** :
- Vérifier que les vues KPI sont créées (`psql -f scripts/smoke_tests.sql`)
- Optimiser les requêtes en ajoutant des filtres LIMIT
- Ajouter des filtres LIMIT aux requêtes
- Vérifier que les index existent : `\di` dans psql

#### 3. Données manquantes
**Problème** : Aucune donnée affichée

**Solutions** :
- Vérifier que le dump MusicBrainz est importé
- Exécuter `psql -f scripts/apply_views.sh`
- Vérifier que les vues KPI sont créées

### Commandes de test

```bash
# Test de connexion
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT version();"

# Test des vues KPI
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -c "SELECT COUNT(*) FROM allfeat_kpi.kpi_isrc_coverage;"

# Tests complets
psql -h 127.0.0.1 -U musicbrainz -d musicbrainz -f scripts/smoke_tests.sql
```

## Logique de confiance Phase 1 + Phase 2

### Phase 1 : Logique catégorielle
- **High** : Présence d'IDs normatifs + cohérence des liens
- **Medium** : Présence partielle d'IDs + liens de base
- **Low** : Absence d'IDs ou incohérences majeures

### Phase 2 : Score numérique pondéré
- **Artistes** : 0.3 × ISNI + 0.3 × ISWC + 0.2 × ISRC + 0.2 × Release
- **Œuvres** : 0.4 × ISWC + 0.3 × ISNI/IPI + 0.2 × ISRC + 0.1 × Release
- **Enregistrements** : 0.3 × ISRC + 0.3 × ISWC + 0.3 × ISNI/IPI + 0.1 × Release
- **Releases** : 0.3 × Date + 0.3 × ISRC + 0.2 × ISWC + 0.2 × ISNI/IPI

### Seuils Phase 2
- **High** : Score ≥ 0.8
- **Medium** : Score 0.4 - 0.79
- **Low** : Score < 0.4

### Choix entre Phase 1 et Phase 2
- **Phase 1** : Pour une évaluation rapide et catégorielle
- **Phase 2** : Pour une analyse fine avec scores numériques
- **Recommandation** : Utiliser Phase 2 pour les analyses détaillées

## Support

Pour toute question :
- Consulter `docs/ODBC_Windows_guide.md`
- Vérifier les logs PostgreSQL
- Tester les requêtes directement avec `psql`
- Utiliser `scripts/smoke_tests.sql` pour diagnostiquer
