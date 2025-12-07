package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type RateLimiter struct {
	semaphore chan struct{}
}

func NewRateLimiter(maxConcurrent int) *RateLimiter {
	return &RateLimiter{
		semaphore: make(chan struct{}, maxConcurrent),
	}
}

func (rl *RateLimiter) Limit() gin.HandlerFunc {
	return func(c *gin.Context) {
		select {
		case rl.semaphore <- struct{}{}:
			defer func() { <-rl.semaphore }()
			c.Next()
		default:
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":   "too many concurrent requests",
				"message": "server is busy, please try again later",
			})
			c.Abort()
		}
	}
}
