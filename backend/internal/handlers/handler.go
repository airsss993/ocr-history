package handlers

import (
	"fmt"
	"net/http"

	"github.com/airsss993/ocr-history/internal/config"
	"github.com/airsss993/ocr-history/internal/domain"
	"github.com/airsss993/ocr-history/internal/middleware"
	"github.com/airsss993/ocr-history/internal/services"
	"github.com/airsss993/ocr-history/pkg/logger"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	cfg        *config.Config
	ocrService *services.OCRService
}

func NewHandler(cfg *config.Config, ocrService *services.OCRService) *Handler {
	return &Handler{
		cfg:        cfg,
		ocrService: ocrService,
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

	rateLimiter := middleware.NewRateLimiter(h.cfg.RateLimit.MaxConcurrentUsers)
	api := router.Group("/api/v1")
	api.Use(rateLimiter.Limit())
	{
		api.POST("/ocr", h.handleOCR)
	}

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

func (h *Handler) handleOCR(c *gin.Context) {
	form, err := c.MultipartForm()
	if err != nil {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "invalid_request",
			Message: "failed to parse multipart form",
		})
		return
	}

	files := form.File["images"]
	if len(files) == 0 {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "no images provided",
		})
		return
	}

	if len(files) > h.cfg.OCR.MaxImagesPerRequest {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: fmt.Sprintf("maximum %d images allowed, got %d", h.cfg.OCR.MaxImagesPerRequest, len(files)),
		})
		return
	}

	response, err := h.ocrService.ProcessImages(
		files,
		h.cfg.OCR.MaxImageSizeMB,
		h.cfg.OCR.SupportedFormats,
	)
	if err != nil {
		logger.Error(err)
		c.JSON(http.StatusInternalServerError, domain.ErrorResponse{
			Error:   "internal_server_error",
			Message: "failed to process images",
		})
		return
	}

	c.JSON(http.StatusOK, response)
}
