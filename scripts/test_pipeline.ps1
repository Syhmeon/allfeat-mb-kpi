# Script de test du pipeline complet MusicBrainz v30 (Windows PowerShell)
# Usage: .\scripts\test_pipeline.ps1

param(
    [string]$DB_HOST = "127.0.0.1",
    [int]$DB_PORT = 5432,
    [string]$DB_NAME = "musicbrainz",
    [string]$DB_USER = "musicbrainz",
    [string]$CONTAINER_NAME = "musicbrainz-postgres"
)

Write-Host "🚀 Test du pipeline complet MusicBrainz v30..." -ForegroundColor Green
Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   🐳 Conteneur: $CONTAINER_NAME" -ForegroundColor DarkGray
Write-Host "   🗄️ Base: $DB_NAME" -ForegroundColor DarkGray
Write-Host "   👤 Utilisateur: $DB_USER" -ForegroundColor DarkGray
Write-Host ""

# Fonction pour exécuter une étape du pipeline
function Invoke-PipelineStep {
    param(
        [string]$StepName,
        [string]$ScriptPath,
        [string]$Description
    )
    
    Write-Host "🔄 Étape: $StepName" -ForegroundColor Yellow
    Write-Host "   📝 $Description" -ForegroundColor DarkGray
    
    try {
        $result = & $ScriptPath 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "   ✅ $StepName terminé avec succès" -ForegroundColor Green
            return $true
        } else {
            Write-Host "   ❌ $StepName échoué (code: $exitCode)" -ForegroundColor Red
            Write-Host "   📝 Sortie: $result" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "   ❌ Exception lors de $StepName : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Fonction pour vérifier le résultat final
function Test-FinalResult {
    Write-Host "🔍 Vérification du résultat final..." -ForegroundColor Yellow
    
    try {
        # Vérifier SCHEMA_SEQUENCE
        $schemaResult = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -t -c "SELECT current_schema_sequence FROM musicbrainz.replication_control;" 2>&1
        $currentSchemaSequence = $schemaResult.Trim()
        
        if ($LASTEXITCODE -eq 0 -and $currentSchemaSequence -eq "30") {
            Write-Host "   ✅ SCHEMA_SEQUENCE = ${currentSchemaSequence} (attendu: 30)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ SCHEMA_SEQUENCE = ${currentSchemaSequence} (attendu: 30)" -ForegroundColor Red
            return $false
        }
        
        # Vérifier quelques tables clés
        $tablesToCheck = @("artist", "recording", "release", "work")
        foreach ($table in $tablesToCheck) {
            $countResult = docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM musicbrainz.$table;" 2>&1
            $count = $countResult.Trim()
            
            if ($LASTEXITCODE -eq 0 -and $count -as [int] -gt 0) {
                Write-Host "   ✅ Table musicbrainz.$table`: $count lignes" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Table musicbrainz.$table`: $count lignes (attendu > 0)" -ForegroundColor Red
                return $false
            }
        }
        
        return $true
    } catch {
        Write-Host "   ❌ Exception lors de la vérification finale: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Pipeline complet
$pipelineSteps = @(
    @{
        Name = "Reset Database"
        Script = ".\scripts\reset_mb.ps1"
        Description = "Réinitialisation de la base de données musicbrainz"
    },
    @{
        Name = "Apply Schema"
        Script = ".\scripts\apply_mb_schema.ps1"
        Description = "Application du schéma officiel MusicBrainz v30"
    },
    @{
        Name = "Import Data"
        Script = ".\scripts\import_mb.ps1"
        Description = "Import des données MusicBrainz via \copy"
    },
    @{
        Name = "Apply Indexes"
        Script = ".\scripts\apply_mb_indexes.ps1"
        Description = "Application des index et contraintes officiels"
    },
    @{
        Name = "Verify Schema"
        Script = ".\scripts\verify_mb_schema.ps1"
        Description = "Vérification du schéma et des données"
    }
)

# Exécution du pipeline
$successCount = 0
$totalSteps = $pipelineSteps.Count

foreach ($step in $pipelineSteps) {
    Write-Host ""
    $success = Invoke-PipelineStep -StepName $step.Name -ScriptPath $step.Script -Description $step.Description
    
    if (-not $success) {
        Write-Host ""
        Write-Host "❌ Pipeline interrompu à l'étape: $($step.Name)" -ForegroundColor Red
        Write-Host "💡 Vérifiez les logs ci-dessus pour identifier le problème" -ForegroundColor Cyan
        Write-Host "🔄 Relancez le pipeline après correction" -ForegroundColor Cyan
        exit 1
    }
    
    $successCount++
    Write-Host "   📊 Progression: $successCount/$totalSteps étapes terminées" -ForegroundColor Cyan
}

# Vérification finale
Write-Host ""
Write-Host "🔍 Vérification finale du pipeline..." -ForegroundColor Yellow
$finalSuccess = Test-FinalResult

if ($finalSuccess) {
    Write-Host ""
    Write-Host "🎉 Pipeline complet MusicBrainz v30 terminé avec succès!" -ForegroundColor Green
    Write-Host "✅ Toutes les étapes ont été exécutées correctement" -ForegroundColor Green
    Write-Host "✅ SCHEMA_SEQUENCE = 30 confirmé" -ForegroundColor Green
    Write-Host "✅ Données importées et index appliqués" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔍 Prochaines étapes:" -ForegroundColor Cyan
    Write-Host "   📊 Appliquer les vues KPI: .\scripts\apply_views.ps1" -ForegroundColor DarkGray
    Write-Host "   🧪 Lancer les tests: docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME < scripts/tests.sql" -ForegroundColor DarkGray
    Write-Host "   📈 Configurer Excel/ODBC: voir excel/PowerQuery_guide.md" -ForegroundColor DarkGray
} else {
    Write-Host ""
    Write-Host "❌ Vérification finale échouée" -ForegroundColor Red
    Write-Host "💡 Le pipeline s'est terminé mais la vérification finale a échoué" -ForegroundColor Cyan
    Write-Host "🔍 Vérifiez manuellement l'état de la base de données" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "📊 Résumé du pipeline:" -ForegroundColor Cyan
Write-Host "   ✅ Étapes réussies: $successCount/$totalSteps" -ForegroundColor Green
Write-Host "   ✅ SCHEMA_SEQUENCE: 30" -ForegroundColor Green
Write-Host "   ✅ Base de données: $DB_NAME" -ForegroundColor Green
Write-Host "   ✅ Conteneur: $CONTAINER_NAME" -ForegroundColor Green
