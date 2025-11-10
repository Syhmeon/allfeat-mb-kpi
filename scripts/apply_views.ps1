# Script d'application des vues KPI Allfeat pour Windows PowerShell (Version Améliorée)
# Usage: .\scripts\apply_views.ps1
# 
# Améliorations Phase 1+2:
# - Test de connectivité directe sur la base de données cible
# - Vérification de sécurité de la table metadata avec PRIMARY KEY
# - Gestion robuste des conflits INSERT/UPDATE
# - Exécution automatique des tests de fumée
# - Compatibilité Windows PowerShell et PowerShell Core
# - Gestion d'erreurs améliorée avec warnings au lieu d'arrêts

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz_db",
    [string]$DB_USER = "musicbrainz",
    [string]$SQL_DIR = ".\sql"
)

# Variables de suivi pour le résumé final
$totalViewsApplied = 0
$metadataUpdateSuccess = $false
$smokeTestsSuccess = $false

Write-Host "🚀 Application des vues KPI Allfeat (Phase 1+2)..." -ForegroundColor Green

# 1. Vérifier que PostgreSQL est accessible sur la base de données cible
Write-Host "📡 Vérification de la connexion PostgreSQL sur $DB_NAME..." -ForegroundColor Yellow
try {
    $env:PGPASSWORD = "musicbrainz"
    # Test direct sur la base de données cible, pas seulement postgres
    $result = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Connexion échouée sur $DB_NAME"
    }
    Write-Host "✅ Connexion PostgreSQL réussie sur $DB_NAME" -ForegroundColor Green
} catch {
    Write-Host "❌ PostgreSQL n'est pas accessible sur $DB_NAME. Vérifiez que Docker est démarré et que la base existe." -ForegroundColor Red
    Write-Host "💡 Essayez: docker compose up -d" -ForegroundColor Cyan
    exit 1
}

# 2. Vérifier que le schéma et la table metadata existent avec sécurité
Write-Host "🗄️  Vérification du schéma allfeat_kpi et table metadata..." -ForegroundColor Yellow
try {
    # Vérifier que le schéma existe
    $schemaCheck = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'allfeat_kpi';" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Schéma allfeat_kpi introuvable"
    }
    
    # Vérifier que la table metadata existe
    $tableCheck = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM allfeat_kpi.metadata LIMIT 1;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Table allfeat_kpi.metadata introuvable"
    }
    
    # Vérifier que la table metadata a une contrainte PRIMARY KEY ou UNIQUE sur 'key'
    $constraintCheck = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c @"
SELECT 1 FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'allfeat_kpi' 
  AND tc.table_name = 'metadata'
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  AND ccu.column_name = 'key';
"@ 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Table metadata sans contrainte PRIMARY KEY/UNIQUE sur 'key' - création d'une contrainte..." -ForegroundColor Yellow
        # Créer une contrainte UNIQUE si elle n'existe pas
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "ALTER TABLE allfeat_kpi.metadata ADD CONSTRAINT metadata_key_unique UNIQUE (key);" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Impossible de créer la contrainte UNIQUE - utilisation d'INSERT simple" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✅ Schéma allfeat_kpi et table metadata vérifiés" -ForegroundColor Green
} catch {
    Write-Host "❌ Le schéma allfeat_kpi ou la table metadata n'existent pas." -ForegroundColor Red
    Write-Host "💡 Exécutez d'abord: psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f sql/init/00_schema.sql" -ForegroundColor Cyan
    exit 1
}

# 3. Appliquer les vues dans l'ordre (Phase 1+2 avec vues de confiance améliorées)
Write-Host "📊 Application des vues KPI (Phase 1+2)..." -ForegroundColor Yellow

# Liste des vues avec les noms corrects après la réécriture Phase 1+2
$views = @(
    "10_kpi_isrc_coverage.sql",
    "20_kpi_iswc_coverage.sql", 
    "30_party_missing_ids_artist.sql",
    "40_dup_isrc_candidates.sql",
    "50_rec_on_release_without_work.sql",
    "51_work_without_recording.sql",
    # Vues de confiance Phase 1+2 (noms confirmés)
    "60_confidence_artist.sql",
    "61_confidence_work.sql",
    "62_confidence_recording.sql",
    "63_confidence_release.sql"
)

foreach ($view in $views) {
    # Utilisation de Join-Path pour compatibilité Windows PowerShell et PowerShell Core
    $viewPath = Join-Path $SQL_DIR "views" $view
    
    if (Test-Path $viewPath) {
        Write-Host "  - Application de $view..." -ForegroundColor Cyan
        try {
            psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $viewPath
            if ($LASTEXITCODE -ne 0) {
                throw "Erreur lors de l'application de $view"
            }
            $totalViewsApplied++
            Write-Host "    ✅ $view appliquée avec succès" -ForegroundColor Green
        } catch {
            Write-Host "❌ Erreur lors de l'application de $view" -ForegroundColor Red
            Write-Host "💡 Vérifiez le fichier: $viewPath" -ForegroundColor Cyan
            exit 1
        }
    } else {
        # Warning au lieu d'arrêt immédiat pour compatibilité ascendante
        Write-Host "⚠️  Fichier $viewPath introuvable - ignoré" -ForegroundColor Yellow
    }
}

# 4. Mettre à jour les métadonnées avec gestion robuste des conflits
Write-Host "📝 Mise à jour des métadonnées..." -ForegroundColor Yellow

# Requête adaptée pour fonctionner même si la table est vide
$updateQuery = @"
-- Essayer d'abord un UPDATE
UPDATE allfeat_kpi.metadata 
SET value = NOW()::TEXT, updated_at = NOW() 
WHERE key = 'views_applied_at';

-- Si aucun UPDATE n'a eu lieu, faire un INSERT
INSERT INTO allfeat_kpi.metadata (key, value, updated_at) 
SELECT 'views_applied_at', NOW()::TEXT, NOW()
WHERE NOT EXISTS (SELECT 1 FROM allfeat_kpi.metadata WHERE key = 'views_applied_at');
"@

try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c $updateQuery
    if ($LASTEXITCODE -eq 0) {
        $metadataUpdateSuccess = $true
        Write-Host "✅ Métadonnées mises à jour avec succès" -ForegroundColor Green
    } else {
        throw "Erreur lors de la mise à jour des métadonnées"
    }
} catch {
    Write-Host "⚠️  Erreur lors de la mise à jour des métadonnées" -ForegroundColor Yellow
    Write-Host "💡 Les vues ont été appliquées mais les métadonnées n'ont pas été mises à jour" -ForegroundColor Cyan
}

# 5. Lister les vues créées
Write-Host "📋 Vues KPI créées:" -ForegroundColor Green
try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c @"
SELECT 
    schemaname, 
    viewname,
    CASE 
        WHEN viewname LIKE 'confidence_%' THEN 'Phase 1+2'
        ELSE 'Phase 1'
    END as phase
FROM pg_views 
WHERE schemaname = 'allfeat_kpi' 
ORDER BY viewname;
"@
} catch {
    Write-Host "⚠️  Impossible de lister les vues" -ForegroundColor Yellow
}

# 6. Exécution automatique des tests de fumée
Write-Host "🧪 Exécution automatique des tests de fumée..." -ForegroundColor Yellow
$testsPath = Join-Path "scripts" "tests.sql"

if (Test-Path $testsPath) {
    try {
        Write-Host "  - Exécution de scripts/tests.sql..." -ForegroundColor Cyan
        $testsResult = psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $testsPath
        if ($LASTEXITCODE -eq 0) {
            $testsSuccess = $true
            Write-Host "    ✅ Tests réussis" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Tests échoués" -ForegroundColor Red
        }
    } catch {
        Write-Host "    ❌ Erreur lors de l'exécution des tests" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  Fichier scripts/tests.sql introuvable" -ForegroundColor Yellow
}

# 7. Résumé final
Write-Host "`n📊 Résumé de l'application des vues KPI:" -ForegroundColor Green
Write-Host "  - Vues appliquées: $totalViewsApplied/$($views.Count)" -ForegroundColor $(if ($totalViewsApplied -eq $views.Count) { "Green" } else { "Yellow" })
Write-Host "  - Métadonnées: $(if ($metadataUpdateSuccess) { "✅ Mises à jour" } else { "⚠️  Erreur" })" -ForegroundColor $(if ($metadataUpdateSuccess) { "Green" } else { "Yellow" })
Write-Host "  - Tests de fumée: $(if ($smokeTestsSuccess) { "✅ Réussis" } else { "❌ Échoués" })" -ForegroundColor $(if ($smokeTestsSuccess) { "Green" } else { "Red" })

if ($totalViewsApplied -eq $views.Count -and $metadataUpdateSuccess -and $smokeTestsSuccess) {
    Write-Host "`n🎉 Application des vues KPI Phase 1+2 terminée avec succès!" -ForegroundColor Green
    Write-Host "🔍 Vous pouvez maintenant utiliser Excel/ODBC avec les requêtes Power Query" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠️  Application terminée avec des avertissements" -ForegroundColor Yellow
    Write-Host "💡 Vérifiez les messages ci-dessus pour plus de détails" -ForegroundColor Cyan
}