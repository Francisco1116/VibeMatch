package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"

	"vibematch-go/redis"
)

// Config 存放應用程式所需的環境設定
type Config struct {
	Port      string
	RedisURL  string
	JWTSecret string
}

// AppConfig 全域設定實例
var AppConfig Config

// Load 載入 .env 並初始化 Redis Client
func Load() error {
	// 載入 .env（若檔案不存在則略過，改讀取系統環境變數）
	if err := godotenv.Load(); err != nil {
		log.Println("未找到 .env 檔案，將使用系統環境變數")
	}

	AppConfig = Config{
		Port:      getEnv("PORT", "8080"),
		RedisURL:  getEnv("REDIS_URL", "localhost:6379"),
		JWTSecret: os.Getenv("JWT_SECRET"),
	}

	if AppConfig.JWTSecret == "" {
		return fmt.Errorf("缺少環境變數 JWT_SECRET")
	}

	if err := redis.Init(AppConfig.RedisURL); err != nil {
		return err
	}

	log.Println("Redis 連線成功")
	return nil
}

// getEnv 讀取環境變數，若不存在則回傳預設值
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
