package middleware

import (
	"errors"
	"fmt"

	"github.com/golang-jwt/jwt/v5"
)

// Claims 對應 Node.js 端簽發的 Access Token payload
type Claims struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Email    string `json:"email"`
	jwt.RegisteredClaims
}

// ValidateToken 驗證 URL Query 傳入的 JWT，並解析出 userId
func ValidateToken(tokenString, secret string) (string, error) {
	if tokenString == "" {
		return "", errors.New("缺少 token 參數")
	}

	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// 確認簽章演算法為 HMAC（與 Node.js jsonwebtoken 預設一致）
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("不支援的簽章演算法: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})
	if err != nil {
		return "", fmt.Errorf("Token 驗證失敗: %w", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return "", errors.New("Token 無效或已過期")
	}

	if claims.UserID == "" {
		return "", errors.New("Token 中缺少 userId")
	}

	return claims.UserID, nil
}
