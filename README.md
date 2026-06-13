# VibeMatch 🚀

A real-time, time-limited social matching and chat platform built with a microservices architecture. Designed to scale and optimize user engagement.

## 🌟 Core Features
- **Real-Time Matching:** Users are matched instantly based on their current "vibe" or interests.
- **Time-Limited Chat:** A thrilling 5-minute ephemeral chat window (WebSocket-powered).
- **Vibe Coding AI Collaboration:** Built with AI assistance (Claude/Cursor) to accelerate UI generation, write Go unit tests, and provision infrastructure.

## 🏗️ Architecture & Tech Stack
- **Mobile App (Client):** Flutter
- **Admin Dashboard:** React + Vite + Tailwind CSS
- **Core API Service:** Node.js (Express) - Handles users, auth (JWT), and profiles.
- **Real-Time Engine:** Go (Golang) + WebSocket - Handles high-concurrency matchmaking and chat sessions.
- **Message Broker & Cache:** Redis - Manages match queues and active sessions.
- **Database:** MongoDB (or PostgreSQL)
- **Infrastructure:** Docker, AWS/GCP, GitHub Actions

## 📂 Project Structure
- `/backend-node` - User Management & Auth API
- `/backend-go` - High-Concurrency Matchmaking Engine
- `/mobile-flutter` - Cross-platform Mobile Application
- `/frontend-admin` - Web-based Admin Dashboard
- `/infra` - Docker Compose and deployment configurations