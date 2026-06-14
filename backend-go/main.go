package main

import (
	"fmt"
	"log"
	"net/http"

	"vibematch-go/config"
	"vibematch-go/middleware"
	"vibematch-go/websocket"
)

func main() {
	// 載入環境設定並初始化 Redis
	if err := config.Load(); err != nil {
		log.Fatalf("設定載入失敗: %v", err)
	}

	wsManager := websocket.NewManager()

	// WebSocket 路由：先驗證 JWT，再升級連線
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(w, r, wsManager)
	})

	// 健康檢查端點
	http.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok","service":"VibeMatch WS"}`))
	})

	addr := fmt.Sprintf(":%s", config.AppConfig.Port)
	log.Printf("VibeMatch WebSocket 伺服器運行於 http://localhost%s", addr)
	log.Printf("WebSocket 端點: ws://localhost%s/ws?token=<accessToken>", addr)

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("伺服器啟動失敗: %v", err)
	}
}

// handleWebSocket 處理 WebSocket 連線請求
func handleWebSocket(w http.ResponseWriter, r *http.Request, wsManager *websocket.Manager) {
	token := r.URL.Query().Get("token")

	userID, err := middleware.ValidateToken(token, config.AppConfig.JWTSecret)
	if err != nil {
		log.Printf("WebSocket 驗證失敗: %v", err)
		http.Error(w, "Unauthorized: "+err.Error(), http.StatusUnauthorized)
		return
	}

	client, err := wsManager.Upgrade(w, r, userID)
	if err != nil {
		log.Printf("WebSocket 升級失敗: %v", err)
		return
	}

	wsManager.AddClient(client)
	log.Printf("User [%s] connected，目前線上人數: %d", userID, wsManager.ClientCount())

	defer wsManager.OnDisconnect(client)

	// Read Pump：持續讀取訊息並觸發配對邏輯，直到客戶端斷線
	client.ReadPump(wsManager)
}
