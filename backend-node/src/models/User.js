const mongoose = require('mongoose');

/**
 * 使用者 Schema
 * 儲存帳號資訊、密碼雜湊、當前 vibe 狀態與興趣標籤
 */
const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: [true, '使用者名稱為必填'],
      unique: true,
      trim: true,
      minlength: [3, '使用者名稱至少 3 個字元'],
      maxlength: [30, '使用者名稱最多 30 個字元'],
    },
    email: {
      type: String,
      required: [true, '電子郵件為必填'],
      unique: true,
      trim: true,
      lowercase: true,
      match: [/^\S+@\S+\.\S+$/, '請提供有效的電子郵件格式'],
    },
    passwordHash: {
      type: String,
      required: [true, '密碼雜湊為必填'],
      select: false, // 預設查詢不返回密碼雜湊
    },
    refreshToken: {
      type: String,
      default: null,
      select: false, // 預設查詢不返回 Refresh Token
    },
    currentVibe: {
      type: String,
      default: '',
      trim: true,
    },
    interests: {
      type: [String],
      default: [],
    },
  },
  {
    timestamps: true, // 自動加入 createdAt 與 updatedAt
  }
);

const User = mongoose.model('User', userSchema);

module.exports = User;
