DROP TRIGGER IF EXISTS update_video_vote_count ON votes;
DROP TRIGGER IF EXISTS update_videos_updated_at ON videos;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP FUNCTION IF EXISTS update_vote_count();
DROP FUNCTION IF EXISTS update_updated_at_column();