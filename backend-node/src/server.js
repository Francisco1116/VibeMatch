require('dotenv').config();

const express = require('express');
const cors = require('cors');

const { connectDatabase } = require('./database');
const authRoutes = require('./routes/auth.routes');

const app = express();

// 全域中介軟體
app.use(cors());
app.use(express.json());

// 路由註冊
app.use('/api/auth', authRoutes);

/**
 * GET /health
 * 健康檢查端點
 */
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'VibeMatch Auth' });
});

/**
 * 啟動伺服器
 */
async function startServer() {
  try {
    if (!process.env.JWT_SECRET || !process.env.JWT_REFRESH_SECRET) {
      throw new Error('缺少 JWT_SECRET 或 JWT_REFRESH_SECRET 環境變數');
    }

    await connectDatabase();

    const port = process.env.PORT || 3000;

    app.listen(port, () => {
      console.log(`VibeMatch 後端伺服器運行於 http://localhost:${port}`);
    });
  } catch (error) {
    console.error('伺服器啟動失敗:', error.message);
    process.exit(1);
  }
}

startServer();
