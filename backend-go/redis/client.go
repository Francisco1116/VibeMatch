package redis

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

const (
	// MatchQueueKey Redis List 的 key，存放等待配對的使用者 ID
	MatchQueueKey = "match_queue"
)

// RDB 全域 Redis 連線實例
var RDB *goredis.Client

// matchScript 原子性地將使用者加入佇列，並在佇列 >= 2 時取出兩位配對
var matchScript = goredis.NewScript(`
redis.call('LREM', KEYS[1], 0, ARGV[1])
redis.call('RPUSH', KEYS[1], ARGV[1])
local len = redis.call('LLEN', KEYS[1])
if len >= 2 then
  local u1 = redis.call('LPOP', KEYS[1])
  local u2 = redis.call('LPOP', KEYS[1])
  return {u1, u2}
end
return {}
`)

// Init 連線至 Redis 並驗證連線狀態
func Init(addr string) error {
	RDB = goredis.NewClient(&goredis.Options{
		Addr: addr,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := RDB.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("Redis 連線失敗: %w", err)
	}

	return nil
}

// EnqueueAndTryMatch 將 userID 加入配對佇列，若湊滿兩人則回傳配對結果
func EnqueueAndTryMatch(ctx context.Context, userID string) ([2]string, bool, error) {
	result, err := matchScript.Run(ctx, RDB, []string{MatchQueueKey}, userID).StringSlice()
	if err != nil {
		return [2]string{}, false, fmt.Errorf("配對佇列操作失敗: %w", err)
	}

	if len(result) == 2 {
		return [2]string{result[0], result[1]}, true, nil
	}

	return [2]string{}, false, nil
}

// RemoveFromQueue 使用者斷線時，從配對佇列中移除
func RemoveFromQueue(ctx context.Context, userID string) error {
	if err := RDB.LRem(ctx, MatchQueueKey, 0, userID).Err(); err != nil {
		return fmt.Errorf("從配對佇列移除使用者失敗: %w", err)
	}
	return nil
}
