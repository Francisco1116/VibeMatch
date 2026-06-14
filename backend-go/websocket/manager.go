package websocket

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	gorillaws "github.com/gorilla/websocket"

	"vibematch-go/redis" // 你的自訂 redis package
)

// Client 代表一個已連線的 WebSocket 客戶端
type Client struct {
	Conn    *gorillaws.Conn
	UserID  string
	writeMu sync.Mutex         // 保護 WebSocket 寫入的併發安全
	cancel  context.CancelFunc // 用於關閉 Redis Pub/Sub 訂閱
}

// Manager 管理 WebSocket 連線的升級與客戶端
type Manager struct {
	Upgrader        gorillaws.Upgrader
	Clients         map[*Client]bool   // 追蹤所有活躍連線
	clientsByUserID map[string]*Client // 依 userID 快速查找連線
	mu              sync.RWMutex       // 保護 Clients 與 clientsByUserID 的併發讀寫
}

// incomingMessage 客戶端傳入的 JSON 訊息格式
type incomingMessage struct {
	Action  string `json:"action"`
	RoomID  string `json:"roomId"`  // 聊天用
	Message string `json:"message"` // 聊天用
}

// matchedMessage 配對成功後回傳給客戶端的 JSON 訊息格式
type matchedMessage struct {
	Action string `json:"action"`
	RoomID string `json:"roomId"`
}

// chatMessage 廣播聊天內容的 JSON 訊息格式
type chatMessage struct {
	Action   string `json:"action"`
	SenderID string `json:"senderId"`
	Message  string `json:"message"`
}

// NewManager 建立 WebSocket 管理器
func NewManager() *Manager {
	return &Manager{
		Upgrader: gorillaws.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // 開發階段允許跨域
			},
		},
		Clients:         make(map[*Client]bool),
		clientsByUserID: make(map[string]*Client),
	}
}

// AddClient 將新連線加入活躍客戶端名單
func (m *Manager) AddClient(client *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Clients[client] = true
	m.clientsByUserID[client.UserID] = client
}

// RemoveClient 從活躍客戶端名單中移除連線
func (m *Manager) RemoveClient(client *Client) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.Clients, client)
	delete(m.clientsByUserID, client.UserID)
}

func (m *Manager) ClientCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.Clients)
}

func (m *Manager) getClientByUserID(userID string) (*Client, bool) {
	client, ok := m.clientsByUserID[userID]
	return client, ok
}

func (m *Manager) Upgrade(w http.ResponseWriter, r *http.Request, userID string) (*Client, error) {
	conn, err := m.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		return nil, err
	}

	return &Client{
		Conn:   conn,
		UserID: userID,
	}, nil
}

// ReadPump 持續讀取客戶端訊息
func (c *Client) ReadPump(m *Manager) {
	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			log.Printf("User [%s] 連線中斷: %v", c.UserID, err)
			return
		}

		var msg incomingMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("User [%s] 傳入無效 JSON: %v", c.UserID, err)
			continue
		}

		switch msg.Action {
		case "find_match":
			m.handleFindMatch(c)
		case "chat":
			m.handleChat(c, msg) // 處理聊天訊息
		default:
			log.Printf("User [%s] 收到未知 action: %s", c.UserID, msg.Action)
		}
	}
}

// handleFindMatch 配對引擎
func (m *Manager) handleFindMatch(client *Client) {
	ctx := context.Background()

	pair, matched, err := redis.EnqueueAndTryMatch(ctx, client.UserID)
	if err != nil {
		log.Printf("User [%s] 配對失敗: %v", client.UserID, err)
		return
	}

	if !matched {
		log.Printf("User [%s] 已加入配對佇列，等待中...", client.UserID)
		return
	}

	roomID := uuid.New().String()
	log.Printf("配對成功: User [%s] ↔ User [%s]，RoomID: %s", pair[0], pair[1], roomID)

	m.NotifyMatched(pair[0], pair[1], roomID)
}

// NotifyMatched 廣播配對結果，並啟動 Redis 訂閱
func (m *Manager) NotifyMatched(userID1, userID2, roomID string) {
	payload, _ := json.Marshal(matchedMessage{
		Action: "matched",
		RoomID: roomID,
	})

	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, userID := range []string{userID1, userID2} {
		client, ok := m.getClientByUserID(userID)
		if !ok {
			continue
		}
		if err := client.sendJSON(payload); err == nil {
			// 配對成功且發送通知後，立刻幫客戶端訂閱該房間的 Redis 頻道
			client.SubscribeToRoom(roomID)
		}
	}
}

// handleChat 將聊天訊息發佈 (Publish) 到 Redis
func (m *Manager) handleChat(client *Client, msg incomingMessage) {
	if msg.RoomID == "" || msg.Message == "" {
		return
	}

	chatPayload, _ := json.Marshal(chatMessage{
		Action:   "chat",
		SenderID: client.UserID,
		Message:  msg.Message,
	})

	// 假設你在 redis package 裡公開的 Client 變數叫做 RDB
	// 如果是其他的名稱 (例如 Client 或 RedisClient)，請在這裡修改
	err := redis.RDB.Publish(context.Background(), "room:"+msg.RoomID, chatPayload).Err()
	if err != nil {
		log.Printf("User [%s] 發佈訊息失敗: %v", client.UserID, err)
	}
}

// SubscribeToRoom 訂閱 (Subscribe) Redis 頻道並轉發給 WebSocket
func (c *Client) SubscribeToRoom(roomID string) {
	ctx, cancel := context.WithCancel(context.Background())
	c.cancel = cancel // 儲存 cancel 函數，斷線時呼叫

	go func() {
		pubsub := redis.RDB.Subscribe(ctx, "room:"+roomID)
		defer pubsub.Close()
		ch := pubsub.Channel()

		for {
			select {
			case <-ctx.Done():
				// 客戶端斷線，結束監聽
				log.Printf("User [%s] 結束房間 %s 的訂閱", c.UserID, roomID)
				return
			case msg := <-ch:
				// 從 Redis 收到訊息，轉發給 WebSocket 客戶端
				c.sendJSON([]byte(msg.Payload))
			}
		}
	}()
}

// sendJSON 安全地向客戶端寫入 JSON 訊息
func (c *Client) sendJSON(payload []byte) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.Conn.WriteMessage(gorillaws.TextMessage, payload)
}

// Close 關閉 WebSocket 連線
func (c *Client) Close() error {
	if c.cancel != nil {
		c.cancel() // 觸發 context 取消，關閉 Redis 訂閱
	}
	if c.Conn != nil {
		return c.Conn.Close()
	}
	return nil
}

// OnDisconnect 使用者斷線時的清理
func (m *Manager) OnDisconnect(client *Client) {
	ctx := context.Background()

	_ = redis.RemoveFromQueue(ctx, client.UserID)
	m.RemoveClient(client)
	_ = client.Close()

	log.Printf("User [%s] disconnected，目前線上人數: %d", client.UserID, m.ClientCount())
}