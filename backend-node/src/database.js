const mongoose = require('mongoose');

/**
 * 連線至 MongoDB 資料庫
 * 從環境變數 MONGO_URI 讀取連線字串
 */
async function connectDatabase() {
  const mongoUri = process.env.MONGO_URI;

  if (!mongoUri) {
    throw new Error('缺少環境變數 MONGO_URI，請在 .env 檔案中設定');
  }

  try {
    await mongoose.connect(mongoUri);
    console.log('MongoDB 連線成功');
  } catch (error) {
    console.error('MongoDB 連線失敗:', error.message);
    throw error;
  }
}

module.exports = { connectDatabase };
