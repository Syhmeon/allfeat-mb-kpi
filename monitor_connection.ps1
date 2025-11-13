# Script pour surveiller les logs Docker pendant une tentative de connexion DBeaver
# Usage: .\monitor_connection.ps1

Write-Host "=== Surveillance des logs PostgreSQL ===" -ForegroundColor Cyan
Write-Host "Ce script va afficher les logs en temps réel." -ForegroundColor Yellow
Write-Host "Essayez de vous connecter avec DBeaver maintenant..." -ForegroundColor Yellow
Write-Host "Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow
Write-Host ""

docker logs -f musicbrainz-db

