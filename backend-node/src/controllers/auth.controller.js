const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

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
 * 使用者註冊：bcrypt 加密密碼後存入資料庫
 */
async function register(req, res) {
  try {
    const { username, email, password, currentVibe, interests } = req.body;

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

    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

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
}

/**
 * POST /api/auth/login
 * 使用者登入：驗證帳密，簽發 Token 並將 Refresh Token 寫入資料庫
 */
async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: '請提供 email 與 password',
      });
    }

    const user = await User.findOne({ email: email.toLowerCase() }).select(
      '+passwordHash +refreshToken'
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        message: '電子郵件或密碼錯誤',
      });
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: '電子郵件或密碼錯誤',
      });
    }

    const { accessToken, refreshToken } = generateTokens(user);

    // 將 Refresh Token 持久化至資料庫，供後續驗證與撤銷使用
    user.refreshToken = refreshToken;
    await user.save();

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
}

module.exports = { register, login };
