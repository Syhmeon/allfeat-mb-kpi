# Script pour capturer les logs pendant une tentative de connexion DBeaver
Write-Host "=== Capture des logs de connexion ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "1. Ce script va surveiller les logs Docker" -ForegroundColor White
Write-Host "2. Ouvrez DBeaver et essayez de vous connecter MAINTENANT" -ForegroundColor White
Write-Host "3. Appuyez sur Ctrl+C après avoir essayé de vous connecter" -ForegroundColor White
Write-Host ""
Write-Host "Démarrage de la surveillance dans 3 secondes..." -ForegroundColor Green
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "=== LOGS EN TEMPS RÉEL ===" -ForegroundColor Cyan
Write-Host "Essayez de vous connecter avec DBeaver maintenant!" -ForegroundColor Yellow
Write-Host ""

# Capturer les logs
docker logs --tail=0 -f musicbrainz-db

