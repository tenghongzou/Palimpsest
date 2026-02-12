package repository

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// CacheRepository implements the Cache-Aside pattern with Redis.
// Key pattern: palimpsest:{entity}:{id}:{field}
type CacheRepository struct {
	rdb *redis.Client
}

func NewCacheRepository(rdb *redis.Client) *CacheRepository {
	return &CacheRepository{rdb: rdb}
}

func (r *CacheRepository) Get(ctx context.Context, key string) (string, error) {
	return r.rdb.Get(ctx, key).Result()
}

func (r *CacheRepository) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	return r.rdb.Set(ctx, key, value, ttl).Err()
}

func (r *CacheRepository) Delete(ctx context.Context, key string) error {
	return r.rdb.Del(ctx, key).Err()
}
