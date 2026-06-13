const express = require('express');
const { register, login } = require('../controllers/auth.controller');
const { validateRegister } = require('../middlewares/validate');

const router = express.Router();

// 註冊：先通過 validateRegister 驗證，再進入 controller
router.post('/register', validateRegister, register);

// 登入
router.post('/login', login);

module.exports = router;
