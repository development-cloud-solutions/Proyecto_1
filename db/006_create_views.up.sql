-- Vista materializada para rankings (mejor rendimiento)
CREATE MATERIALIZED VIEW IF NOT EXISTS video_rankings AS
SELECT 
    v.id,
    v.title,
    v.processed_url,
    v.votes_count,
    v.uploaded_at,
    u.first_name || ' ' || u.last_name as username,
    u.city,
    u.country,
    ROW_NUMBER() OVER (ORDER BY v.votes_count DESC, v.uploaded_at ASC) as global_position,
    ROW_NUMBER() OVER (PARTITION BY u.city ORDER BY v.votes_count DESC, v.uploaded_at ASC) as city_position
FROM videos v
JOIN users u ON v.user_id = u.id
WHERE v.is_public = true AND v.status = 'processed'
ORDER BY v.votes_count DESC, v.uploaded_at ASC;

-- Índice único para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_video_rankings_id ON video_rankings(id);
CREATE INDEX IF NOT EXISTS idx_video_rankings_city ON video_rankings(city);
CREATE INDEX IF NOT EXISTS idx_video_rankings_votes ON video_rankings(votes_count);