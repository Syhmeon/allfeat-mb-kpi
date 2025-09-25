-- KPI 5a: Enregistrements sur release sans œuvre associée
-- Identifie les incohérences dans la hiérarchie Release > Recording > Work
-- Usage: SELECT * FROM allfeat_kpi.rec_on_release_without_work;

CREATE OR REPLACE VIEW allfeat_kpi.rec_on_release_without_work AS
WITH recording_work_stats AS (
    SELECT 
        COUNT(DISTINCT r.id) as total_recordings_on_releases,
        COUNT(DISTINCT r.id) FILTER (WHERE rw.recording IS NOT NULL) as recordings_with_works,
        COUNT(DISTINCT r.id) FILTER (WHERE rw.recording IS NULL) as recordings_without_works
    FROM musicbrainz.recording r
    INNER JOIN musicbrainz.track t ON r.id = t.recording
    INNER JOIN musicbrainz.medium m ON t.medium = m.id
    INNER JOIN musicbrainz.release rel ON m.release = rel.id
    LEFT JOIN musicbrainz.recording_work rw ON r.id = rw.recording
    WHERE r.edits_pending = 0
      AND rel.edits_pending = 0
),
recording_work_samples AS (
    SELECT 
        r.id as recording_id,
        r.name as recording_name,
        r.gid as recording_gid,
        ac.name as artist_credit,
        r.length,
        r.comment,
        rel.id as release_id,
        rel.name as release_name,
        rel.gid as release_gid,
        rg.name as release_group_name,
        rg.type as release_group_type,
        -- Informations sur les œuvres manquantes
        CASE 
            WHEN rw.recording IS NULL THEN 'No Work Link'
            ELSE 'Has Work Link'
        END as work_status,
        -- Nombre d'œuvres associées
        COUNT(rw.work) as work_count
    FROM musicbrainz.recording r
    INNER JOIN musicbrainz.track t ON r.id = t.recording
    INNER JOIN musicbrainz.medium m ON t.medium = m.id
    INNER JOIN musicbrainz.release rel ON m.release = rel.id
    LEFT JOIN musicbrainz.recording_work rw ON r.id = rw.recording
    LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
    LEFT JOIN musicbrainz.release_group rg ON rel.release_group = rg.id
    WHERE r.edits_pending = 0
      AND rel.edits_pending = 0
    GROUP BY r.id, r.name, r.gid, ac.name, r.length, r.comment, 
             rel.id, rel.name, rel.gid, rg.name, rg.type, rw.recording
)
SELECT 
    -- Statistiques générales
    s.total_recordings_on_releases,
    s.recordings_with_works,
    s.recordings_without_works,
    
    -- Pourcentages
    allfeat_kpi.format_percentage(s.recordings_with_works, s.total_recordings_on_releases) as recordings_with_works_pct,
    allfeat_kpi.format_percentage(s.recordings_without_works, s.total_recordings_on_releases) as recordings_without_works_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM recording_work_stats s

UNION ALL

-- Échantillons pour analyse détaillée
SELECT 
    NULL as total_recordings_on_releases,
    NULL as recordings_with_works,
    NULL as recordings_without_works,
    NULL as recordings_with_works_pct,
    NULL as recordings_without_works_pct,
    NULL as calculated_at,
    'SAMPLE_DATA' as scope_note;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.rec_on_release_without_work_samples AS
SELECT 
    r.id as recording_id,
    r.name as recording_name,
    r.gid as recording_gid,
    ac.name as artist_credit,
    r.length,
    r.comment,
    rel.id as release_id,
    rel.name as release_name,
    rel.gid as release_gid,
    rg.name as release_group_name,
    rg.type as release_group_type,
    -- Informations sur les œuvres manquantes
    CASE 
        WHEN rw.recording IS NULL THEN 'No Work Link'
        ELSE 'Has Work Link'
    END as work_status,
    -- Nombre d'œuvres associées
    COUNT(rw.work) as work_count,
    -- Liste des œuvres associées (limitées)
    ARRAY_AGG(w.name ORDER BY w.name) FILTER (WHERE w.name IS NOT NULL) as associated_works
FROM musicbrainz.recording r
INNER JOIN musicbrainz.track t ON r.id = t.recording
INNER JOIN musicbrainz.medium m ON t.medium = m.id
INNER JOIN musicbrainz.release rel ON m.release = rel.id
LEFT JOIN musicbrainz.recording_work rw ON r.id = rw.recording
LEFT JOIN musicbrainz.work w ON rw.work = w.id
LEFT JOIN musicbrainz.artist_credit ac ON r.artist_credit = ac.id
LEFT JOIN musicbrainz.release_group rg ON rel.release_group = rg.id
WHERE r.edits_pending = 0
  AND rel.edits_pending = 0
GROUP BY r.id, r.name, r.gid, ac.name, r.length, r.comment, 
         rel.id, rel.name, rel.gid, rg.name, rg.type, rw.recording
ORDER BY work_count ASC, RANDOM()
LIMIT 50;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.rec_on_release_without_work IS 'KPI principal: Enregistrements sur releases sans œuvres associées';
COMMENT ON VIEW allfeat_kpi.rec_on_release_without_work_samples IS 'Échantillons d''enregistrements avec statut des œuvres associées';
