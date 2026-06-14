# 使用輕量級的 Node.js 20 版本作為基礎環境
FROM node:20-alpine

# 設定貨櫃內的工作目錄
WORKDIR /app

# 先複製 package.json，利用 Docker 快取機制加速 npm install
COPY package*.json ./
RUN npm install

# 複製其餘所有的專案程式碼
COPY . .

# 宣告這台機器會對外開放 3000 埠
EXPOSE 3000

# 機器啟動時的預設指令
CMD ["npm", "run", "dev"]