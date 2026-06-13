require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const { connectDatabase } = require('./database');
const User = require('./models/User');

const app = express();

// 中介軟體
app.use(cors());
app.use(express.json());

// Token 有效期限常數
const ACCESS_TOKEN_EXPIRES_IN = '15m'; // Access Token：15 分鐘
const REFRESH_TOKEN_EXPIRES_IN = '7d'; // Refresh Token：7 天
const BCRYPT_SALT_ROUNDS = 12;

/**
 * 簽發 Access Token 與 Refresh Token
 * @param {object} user - 使用者文件
 * @returns {{ accessToken: string, refreshToken: string }}
 */
function generateTokens(user) {
  const payload = {
    userId: user._id.toString(),
    username: user.username,
    email: user.email,
  };

  const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: ACCESS_TOKEN_EXPIRES_IN,
  });

  const refreshToken = jwt.sign(
    { userId: user._id.toString() },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRES_IN }
  );

  return { accessToken, refreshToken };
}

/**
 * POST /api/auth/register
 * 使用者註冊：接收 username、email、password，加密後存入資料庫
 */
app.post('/api/auth/register', async (req, res) => {
  try {
    const { username, email, password, currentVibe, interests } = req.body;

    // 基本欄位驗證
    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        message: '請提供 username、email 與 password',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: '密碼長度至少 6 個字元',
      });
    }

    // 檢查 username 或 email 是否已存在
    const existingUser = await User.findOne({
      $or: [{ username }, { email: email.toLowerCase() }],
    });

    if (existingUser) {
      const field = existingUser.username === username ? 'username' : 'email';
      return res.status(409).json({
        success: false,
        message: `此 ${field} 已被註冊`,
      });
    }

    // 使用 bcrypt 加密密碼
    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

    // 建立新使用者
    const user = await User.create({
      username,
      email,
      passwordHash,
      currentVibe: currentVibe || '',
      interests: Array.isArray(interests) ? interests : [],
    });

    return res.status(201).json({
      success: true,
      message: '註冊成功',
      data: {
        id: user._id,
        username: user.username,
        email: user.email,
        currentVibe: user.currentVibe,
        interests: user.interests,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error('註冊失敗:', error);

    // Mongoose 驗證錯誤
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map((e) => e.message);
      return res.status(400).json({
        success: false,
        message: messages.join('；'),
      });
    }

    return res.status(500).json({
      success: false,
      message: '伺服器內部錯誤，註冊失敗',
    });
  }
});

/**
 * POST /api/auth/login
 * 使用者登入：驗證帳密，成功後簽發 Access Token 與 Refresh Token
 */
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: '請提供 email 與 password',
      });
    }

    // 查詢使用者（需明確選取 passwordHash 欄位）
    const user = await User.findOne({ email: email.toLowerCase() }).select(
      '+passwordHash'
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        message: '電子郵件或密碼錯誤',
      });
    }

    // 比對密碼
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: '電子郵件或密碼錯誤',
      });
    }

    // 簽發雙層 JWT Token
    const { accessToken, refreshToken } = generateTokens(user);

    return res.status(200).json({
      success: true,
      message: '登入成功',
      data: {
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
          currentVibe: user.currentVibe,
          interests: user.interests,
        },
        accessToken,
        refreshToken,
        expiresIn: ACCESS_TOKEN_EXPIRES_IN,
      },
    });
  } catch (error) {
    console.error('登入失敗:', error);

    return res.status(500).json({
      success: false,
      message: '伺服器內部錯誤，登入失敗',
    });
  }
});

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
    // 驗證必要的 JWT 環境變數
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
