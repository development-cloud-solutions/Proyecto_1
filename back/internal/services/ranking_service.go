package services

import (
	"database/sql"

	"back/internal/config"
	"back/internal/database/models"
)

type RankingService struct {
	db     *sql.DB
	config *config.Config
}

func NewRankingService(db *sql.DB, cfg *config.Config) *RankingService {
	return &RankingService{
		db:     db,
		config: cfg,
	}
}

// GetRankings obtiene el ranking de jugadores con paginación
func (s *RankingService) GetRankings(page, limit int, city string) ([]models.RankingEntry, error) {
	offset := (page - 1) * limit

	var query string
	var args []interface{}

	baseQuery := `
		WITH ranked_videos AS (
			SELECT 
				v.id as video_id,
				v.title,
				v.processed_url,
				v.votes_count,
				u.first_name || ' ' || u.last_name as username,
				u.city,
				ROW_NUMBER() OVER (ORDER BY v.votes_count DESC, v.uploaded_at ASC) as position
			FROM videos v
			JOIN users u ON v.user_id = u.id
			WHERE v.is_public = true AND v.status = 'processed' AND v.votes_count > 0`

	if city != "" {
		query = baseQuery + ` AND u.city ILIKE $1
		)
		SELECT video_id, title, processed_url, votes_count, username, city, position
		FROM ranked_videos
		ORDER BY position
		LIMIT $2 OFFSET $3`
		args = []interface{}{"%" + city + "%", limit, offset}
	} else {
		query = baseQuery + `
		)
		SELECT video_id, title, processed_url, votes_count, username, city, position
		FROM ranked_videos
		ORDER BY position
		LIMIT $1 OFFSET $2`
		args = []interface{}{limit, offset}
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rankings []models.RankingEntry
	for rows.Next() {
		var entry models.RankingEntry
		var videoURL sql.NullString

		err := rows.Scan(
			&entry.VideoID,
			&entry.Title,
			&videoURL,
			&entry.Votes,
			&entry.Username,
			&entry.City,
			&entry.Position,
		)
		if err != nil {
			return nil, err
		}

		if videoURL.Valid {
			entry.VideoURL = videoURL.String
		}

		rankings = append(rankings, entry)
	}

	return rankings, nil
}

// GetTopRankings obtiene el top de rankings (más eficiente, con potencial caché)
func (s *RankingService) GetTopRankings(limit int, city string) ([]models.RankingEntry, error) {
	var query string
	var args []interface{}

	baseQuery := `
		SELECT 
			v.id as video_id,
			v.title,
			v.processed_url,
			v.votes_count,
			u.first_name || ' ' || u.last_name as username,
			u.city,
			ROW_NUMBER() OVER (ORDER BY v.votes_count DESC, v.uploaded_at ASC) as position
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true AND v.status = 'processed' AND v.votes_count > 0`

	if city != "" {
		query = baseQuery + ` AND u.city ILIKE $1 ORDER BY v.votes_count DESC, v.uploaded_at ASC LIMIT $2`
		args = []interface{}{"%" + city + "%", limit}
	} else {
		query = baseQuery + ` ORDER BY v.votes_count DESC, v.uploaded_at ASC LIMIT $1`
		args = []interface{}{limit}
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rankings []models.RankingEntry
	position := 1

	for rows.Next() {
		var entry models.RankingEntry
		var videoURL sql.NullString
		var dbPosition int // Para cuando usamos ROW_NUMBER()

		err := rows.Scan(
			&entry.VideoID,
			&entry.Title,
			&videoURL,
			&entry.Votes,
			&entry.Username,
			&entry.City,
			&dbPosition,
		)
		if err != nil {
			return nil, err
		}

		entry.Position = position
		position++

		if videoURL.Valid {
			entry.VideoURL = videoURL.String
		}

		rankings = append(rankings, entry)
	}

	return rankings, nil
}

// GetRankingByUser obtiene la posición de un usuario específico en el ranking
func (s *RankingService) GetRankingByUser(userID int, city string) (*models.RankingEntry, error) {
	var query string
	var args []interface{}

	baseQuery := `
		WITH ranked_videos AS (
			SELECT 
				v.id as video_id,
				v.title,
				v.processed_url,
				v.votes_count,
				v.user_id,
				u.first_name || ' ' || u.last_name as username,
				u.city,
				ROW_NUMBER() OVER (ORDER BY v.votes_count DESC, v.uploaded_at ASC) as position
			FROM videos v
			JOIN users u ON v.user_id = u.id
			WHERE v.is_public = true AND v.status = 'processed'`

	if city != "" {
		query = baseQuery + ` AND u.city ILIKE $1
		)
		SELECT video_id, title, processed_url, votes_count, username, city, position
		FROM ranked_videos
		WHERE user_id = $2
		ORDER BY votes_count DESC
		LIMIT 1`
		args = []interface{}{"%" + city + "%", userID}
	} else {
		query = baseQuery + `
		)
		SELECT video_id, title, processed_url, votes_count, username, city, position
		FROM ranked_videos
		WHERE user_id = $1
		ORDER BY votes_count DESC
		LIMIT 1`
		args = []interface{}{userID}
	}

	var entry models.RankingEntry
	var videoURL sql.NullString

	err := s.db.QueryRow(query, args...).Scan(
		&entry.VideoID,
		&entry.Title,
		&videoURL,
		&entry.Votes,
		&entry.Username,
		&entry.City,
		&entry.Position,
	)

	if err != nil {
		return nil, err
	}

	if videoURL.Valid {
		entry.VideoURL = videoURL.String
	}

	return &entry, nil
}

// GetRankingStats obtiene estadísticas generales del ranking
func (s *RankingService) GetRankingStats(city string) (map[string]interface{}, error) {
	stats := make(map[string]interface{})

	var args []interface{}
	cityFilter := ""

	if city != "" {
		cityFilter = " AND u.city ILIKE $1"
		args = []interface{}{"%" + city + "%"}
	}

	// Total de videos públicos
	query := `
		SELECT COUNT(*)
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true AND v.status = 'processed'` + cityFilter

	var totalVideos int
	err := s.db.QueryRow(query, args...).Scan(&totalVideos)
	if err != nil {
		return nil, err
	}
	stats["total_videos"] = totalVideos

	// Total de votos
	query = `
		SELECT COALESCE(SUM(v.votes_count), 0)
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true AND v.status = 'processed'` + cityFilter

	var totalVotes int
	err = s.db.QueryRow(query, args...).Scan(&totalVotes)
	if err != nil {
		return nil, err
	}
	stats["total_votes"] = totalVotes

	// Total de jugadores participantes
	query = `
		SELECT COUNT(DISTINCT v.user_id)
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true AND v.status = 'processed'` + cityFilter

	var totalPlayers int
	err = s.db.QueryRow(query, args...).Scan(&totalPlayers)
	if err != nil {
		return nil, err
	}
	stats["total_players"] = totalPlayers

	// Promedio de votos por video
	if totalVideos > 0 {
		stats["average_votes_per_video"] = float64(totalVotes) / float64(totalVideos)
	} else {
		stats["average_votes_per_video"] = 0.0
	}

	return stats, nil
}

// GetCityRankings obtiene un resumen de rankings por ciudad
func (s *RankingService) GetCityRankings() ([]map[string]interface{}, error) {
	query := `
		SELECT 
			u.city,
			COUNT(v.id) as video_count,
			COALESCE(SUM(v.votes_count), 0) as total_votes,
			COUNT(DISTINCT v.user_id) as player_count,
			MAX(v.votes_count) as max_votes
		FROM videos v
		JOIN users u ON v.user_id = u.id
		WHERE v.is_public = true AND v.status = 'processed'
		GROUP BY u.city
		HAVING COUNT(v.id) > 0
		ORDER BY total_votes DESC, video_count DESC`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cityRankings []map[string]interface{}

	for rows.Next() {
		var city string
		var videoCount, totalVotes, playerCount, maxVotes int

		err := rows.Scan(&city, &videoCount, &totalVotes, &playerCount, &maxVotes)
		if err != nil {
			return nil, err
		}

		cityData := map[string]interface{}{
			"city":         city,
			"video_count":  videoCount,
			"total_votes":  totalVotes,
			"player_count": playerCount,
			"max_votes":    maxVotes,
		}

		if videoCount > 0 {
			cityData["average_votes_per_video"] = float64(totalVotes) / float64(videoCount)
		} else {
			cityData["average_votes_per_video"] = 0.0
		}

		cityRankings = append(cityRankings, cityData)
	}

	return cityRankings, nil
}
