-- KPI 5b: Œuvres sans enregistrements associés
-- Identifie les œuvres orphelines (sans enregistrements)
-- Usage: SELECT * FROM allfeat_kpi.work_without_recording;

CREATE OR REPLACE VIEW allfeat_kpi.work_without_recording AS
WITH work_recording_stats AS (
    SELECT 
        COUNT(*) as total_works,
        COUNT(DISTINCT w.id) FILTER (WHERE rw.work IS NOT NULL) as works_with_recordings,
        COUNT(DISTINCT w.id) FILTER (WHERE rw.work IS NULL) as works_without_recordings
    FROM musicbrainz.work w
    LEFT JOIN musicbrainz.recording_work rw ON w.id = rw.work
    WHERE w.edits_pending = 0
),
work_recording_samples AS (
    SELECT 
        w.id as work_id,
        w.name as work_name,
        w.gid as work_gid,
        w.type as work_type,
        w.language_code,
        w.comment,
        -- Informations sur les enregistrements associés
        CASE 
            WHEN rw.work IS NULL THEN 'No Recording Link'
            ELSE 'Has Recording Link'
        END as recording_status,
        -- Nombre d'enregistrements associés
        COUNT(rw.recording) as recording_count
    FROM musicbrainz.work w
    LEFT JOIN musicbrainz.recording_work rw ON w.id = rw.work
    WHERE w.edits_pending = 0
    GROUP BY w.id, w.name, w.gid, w.type, w.language_code, w.comment, rw.work
)
SELECT 
    -- Statistiques générales
    s.total_works,
    s.works_with_recordings,
    s.works_without_recordings,
    
    -- Pourcentages
    allfeat_kpi.format_percentage(s.works_with_recordings, s.total_works) as works_with_recordings_pct,
    allfeat_kpi.format_percentage(s.works_without_recordings, s.total_works) as works_without_recordings_pct,
    
    -- Métadonnées
    NOW() as calculated_at,
    'Phase 1: Focus Artistes' as scope_note
FROM work_recording_stats s;

-- Vue détaillée pour les échantillons
CREATE OR REPLACE VIEW allfeat_kpi.work_without_recording_samples AS
SELECT 
    w.id as work_id,
    w.name as work_name,
    w.gid as work_gid,
    w.type as work_type,
    w.language_code,
    w.comment,
    w.iswc,
    -- Informations sur les enregistrements associés
    CASE 
        WHEN rw.work IS NULL THEN 'No Recording Link'
        ELSE 'Has Recording Link'
    END as recording_status,
    -- Nombre d'enregistrements associés
    COUNT(rw.recording) as recording_count,
    -- Liste des enregistrements associés (limités)
    ARRAY_AGG(r.name ORDER BY r.name) FILTER (WHERE r.name IS NOT NULL) as associated_recordings
FROM musicbrainz.work w
LEFT JOIN musicbrainz.recording_work rw ON w.id = rw.work
LEFT JOIN musicbrainz.recording r ON rw.recording = r.id
WHERE w.edits_pending = 0
GROUP BY w.id, w.name, w.gid, w.type, w.language_code, w.comment, w.iswc, rw.work
ORDER BY recording_count ASC, RANDOM()
LIMIT 50;

-- Vue combinée des incohérences Release-Recording-Work
CREATE OR REPLACE VIEW allfeat_kpi.work_recording_inconsistencies AS
WITH inconsistency_stats AS (
    SELECT 
        'Recordings without Works' as inconsistency_type,
        COUNT(*) as count
    FROM musicbrainz.recording r
    INNER JOIN musicbrainz.track t ON r.id = t.recording
    INNER JOIN musicbrainz.medium m ON t.medium = m.id
    INNER JOIN musicbrainz.release rel ON m.release = rel.id
    LEFT JOIN musicbrainz.recording_work rw ON r.id = rw.recording
    WHERE r.edits_pending = 0
      AND rel.edits_pending = 0
      AND rw.recording IS NULL
    
    UNION ALL
    
    SELECT 
        'Works without Recordings' as inconsistency_type,
        COUNT(*) as count
    FROM musicbrainz.work w
    LEFT JOIN musicbrainz.recording_work rw ON w.id = rw.work
    WHERE w.edits_pending = 0
      AND rw.work IS NULL
)
SELECT 
    inconsistency_type,
    count,
    allfeat_kpi.format_percentage(count, SUM(count) OVER ()) as percentage_of_inconsistencies,
    NOW() as calculated_at
FROM inconsistency_stats
ORDER BY count DESC;

-- Commentaires
COMMENT ON VIEW allfeat_kpi.work_without_recording IS 'KPI principal: Œuvres sans enregistrements associés';
COMMENT ON VIEW allfeat_kpi.work_without_recording_samples IS 'Échantillons d''œuvres avec statut des enregistrements associés';
COMMENT ON VIEW allfeat_kpi.work_recording_inconsistencies IS 'Vue combinée des incohérences dans la hiérarchie Work-Recording';
