# --- 第一階段：編譯器 (Builder) ---
FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# 將 Go 程式碼編譯成名為 main 的執行檔
RUN go build -o main .

# --- 第二階段：輕量級運行環境 ---
FROM alpine:latest
WORKDIR /app
# 只從 builder 階段把編譯好的執行檔複製過來
COPY --from=builder /app/main .
# 複製環境變數檔 (如果有其他設定檔也可以放這裡)
COPY .env .

EXPOSE 8080
CMD ["./main"]