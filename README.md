# 🚀 VibeMatch: High-Concurrency Real-Time Matchmaking & Chat System

VibeMatch is a cross-platform (Flutter Web/Mobile) real-time matchmaking and chat application. This project adopts a **Microservices Architecture**, completely decoupling user authentication from high-concurrency WebSocket communications, and utilizes Docker for one-click deployment.

[點擊這裡查看中文版說明](#-vibematch-高併發即時配對與通訊系統)

## 🏗️ Tech Stack & Architecture

This project leverages the right tools for the right jobs, separating business logic into specialized services:

* **Frontend Client:** `Flutter` (Dart)
  * Abandons traditional WebViews, utilizing the Skia/Impeller engine to render fluid, high-performance, dark-themed UI natively.
* **Auth Service:** `Node.js` + `Express` + `MongoDB`
  * Handles I/O-intensive registration and login logic, securely issuing JWTs (JSON Web Tokens).
* **Real-time WS Engine:** `Go` (Golang) + `gorilla/websocket`
  * Manages all persistent WebSocket connections. Utilizes Go's powerful Goroutines and Mutex locks to ensure memory and thread safety under high concurrency.
* **State & Pub/Sub Center:** `Redis`
  * **Atomic Matchmaking:** Implements custom Lua Scripts for the waiting queue, ensuring atomic operations (O(1) time complexity) to prevent Data Races.
  * **Cross-Service Broadcasting:** Utilizes Redis Pub/Sub. Even if the Go server scales out horizontally in the future, messages are accurately routed to the correct isolated chat rooms.
* **Infrastructure:** `Docker` + `Docker Compose`
  * All services are containerized, implementing Multi-Stage Builds for Go to minimize image size.

## ✨ Core Features

1. **Secure JWT Validation:** Node.js issues the token; Go intercepts and validates it during the WebSocket handshake.
2. **Atomic Radar Matching:** Extremely fast, collision-free user pairing powered by Redis Lua scripts.
3. **Isolated Encrypted Chat Rooms:** Upon successful matching, users automatically subscribe to a dedicated Redis Channel for low-latency, two-way communication.
4. **UI/UX State Synchronization:** Features radar pulse animations, auto-scrolling chat bubbles, and graceful reconnect mechanisms built in Flutter.

## 🚀 Getting Started

Deploy the entire VibeMatch universe on any machine with Docker installed using just two commands.

### 1. Boot up the Backend Infrastructure
Ensure Docker Desktop is running. In the project root directory, run:
    docker-compose up -d --build
*(This will automatically spin up Node.js on port 3000, Go on port 8080, MongoDB, and Redis.)*

### 2. Launch the Frontend Application
Ensure the Flutter SDK is installed. Navigate to the frontend directory and launch the web app:
    cd mobile_flutter
    flutter run -d chrome

## 💡 Architecture Decisions

* **Why not handle WebSockets in Node.js?**
  Node.js's single-threaded event loop can become a CPU bottleneck when handling thousands of concurrent WebSocket connections. Offloading high-frequency real-time I/O to Go maximizes server throughput.
* **Why use Redis Pub/Sub?**
  If we only used Go's in-memory Maps to track chat rooms, scaling to multiple servers would break communication if User A and User B connected to different instances. Redis Pub/Sub acts as a central message bus, perfectly solving future horizontal scaling challenges.

---

# 🚀 VibeMatch: 高併發即時配對與通訊系統

VibeMatch 是一個跨平台（Flutter Web/Mobile）的即時配對與聊天應用程式。本專案採用**微服務架構 (Microservices)**，將「會員授權」與「高併發即時通訊」徹底分離，並透過 Docker 實現一鍵部署。

## 🏗️ 系統架構與技術棧 (Tech Stack)

本專案將不同的業務邏輯交由最適合的語言與工具來處理：

* **前端介面 (Frontend):** `Flutter` (Dart)
  * 捨棄傳統 WebView，利用 Skia 引擎直接渲染出流暢且帶有科技感的高效能 UI。
* **會籍中心 (Auth Service):** `Node.js` + `Express` + `MongoDB`
  * 負責處理 I/O 密集型的註冊與登入邏輯，並安全地簽發 JWT (JSON Web Token)。
* **即時通訊引擎 (WS Service):** `Go` (Golang) + `gorilla/websocket`
  * 接管所有 WebSocket 長連線。利用 Go 語言強大的 Goroutine 與 Mutex 鎖，確保高併發環境下的記憶體與執行緒安全。
* **狀態與配對中心 (State & Pub/Sub):** `Redis`
  * **原子性配對:** 使用自訂的 Lua Script 處理等待佇列，確保配對邏輯的原子性 (Atomic)，杜絕 Data Race。
  * **跨服務廣播:** 實作 Redis Pub/Sub 機制，未來即使 Go 伺服器水平擴展 (Scale-out) 為多台機器，依然能精準將訊息推播至指定房間。
* **基礎設施 (Infrastructure):** `Docker` + `Docker Compose`
  * 所有服務皆容器化，並實作 Go 的多階段建置 (Multi-Stage Build) 以極大化縮減映像檔體積。

## ✨ 核心功能 (Core Features)

1. **JWT 安全驗證:** Node.js 簽發憑證，Go WebSocket 握手時攔截並驗證權限。
2. **原子性雷達配對:** 透過 Redis Lua 腳本，實現 O(1) 時間複雜度的極速雙人配對。
3. **隔離加密聊天室:** 配對成功後，自動訂閱專屬 Redis Channel，實現低延遲雙向通訊。
4. **UI/UX 狀態連動:** Flutter 實作雷達脈衝動畫、自動捲動對話框、以及優雅的斷線重連機制。

## 🚀 快速啟動 (Getting Started)

只需兩行指令，即可在任何安裝了 Docker 的機器上啟動完整的 VibeMatch 宇宙。

### 1. 啟動後端微服務 (Backend Infrastructure)
確保您已安裝 Docker Desktop。在專案根目錄下執行：
    docker-compose up -d --build
*(這將會自動啟動 Node.js 於 Port 3000、Go 於 Port 8080、MongoDB 與 Redis。)*

### 2. 啟動前端應用程式 (Frontend Client)
確保您已安裝 Flutter SDK。進入前端目錄並啟動網頁版應用：
    cd mobile_flutter
    flutter run -d chrome

## 📂 專案目錄結構
    VibeMatch/
    ├── backend-node/        # 會員註冊、登入與 JWT 簽發
    ├── backend-go/          # WebSocket 連線、配對與聊天廣播
    ├── mobile_flutter/      # 跨平台前端 App (暗黑科技風)
    └── docker-compose.yml   # 終極微服務總控圖

## 💡 架構設計決策 (Architecture Decisions)

* **為何不把 WebSocket 寫在 Node.js 裡？**
  Node.js 的單執行緒 (Single-thread) 事件迴圈在處理極大量同時在線的 WS 連線時，容易遇到 CPU 瓶頸。將高頻率的即時訊息收發交給 Go 處理，能最大化伺服器的吞吐量。
* **為何使用 Redis Pub/Sub？**
  若單純使用 Go 記憶體裡的 Map 來記錄房間，當系統擴展到兩台以上的伺服器時，User A 和 User B 若連上不同的機器就會無法通訊。引入 Redis Pub/Sub 作為中央訊息匯流排，完美解決了未來水平擴展的問題。