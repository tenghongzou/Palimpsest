package service

// RankingService manages rankings using Redis Sorted Sets.
type RankingService struct {
	// TODO: inject Redis client
}

func NewRankingService() *RankingService {
	return &RankingService{}
}

// TODO: implement GetRanking (views/favorites/rating/latest/completed × daily/weekly/monthly/all)
