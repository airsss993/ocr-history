package handlers

import (
	"github.com/airsss993/ocr-history/internal/config"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	cfg *config.Config
}

func NewHandler(cfg *config.Config) *Handler {
	return &Handler{
		cfg: cfg,
	}
}

func (h *Handler) Init() *gin.Engine {
	router := gin.New()

	router.Use(
		gin.Recovery(),
		gin.Logger(),
	)

	router.GET("/health", h.healthCheck)
	router.GET("/ready", h.readinessCheck)

	return router
}

func (h *Handler) healthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status": "OK",
	})
}

func (h *Handler) readinessCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"ready": true,
	})
}
