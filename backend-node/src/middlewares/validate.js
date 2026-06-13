/** 電子郵件格式正則表達式 */
const EMAIL_REGEX = /^\S+@\S+\.\S+$/;

/**
 * 註冊請求驗證中介軟體
 * 在進入 controller 前檢查 email 格式與密碼長度
 */
function validateRegister(req, res, next) {
  const { username, email, password } = req.body;

  if (!username || !email || !password) {
    return res.status(400).json({
      success: false,
      message: '請提供 username、email 與 password',
    });
  }

  if (!EMAIL_REGEX.test(email)) {
    return res.status(400).json({
      success: false,
      message: '請提供有效的電子郵件格式',
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: '密碼長度至少 6 個字元',
    });
  }

  next();
}

module.exports = { validateRegister };
