package handlers

import (
	"fmt"
	"net/http"

	"github.com/airsss993/ocr-history/internal/config"
	"github.com/airsss993/ocr-history/internal/domain"
	"github.com/airsss993/ocr-history/internal/middleware"
	"github.com/airsss993/ocr-history/internal/repository"
	"github.com/airsss993/ocr-history/internal/services"
	"github.com/airsss993/ocr-history/pkg/logger"
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

	rateLimiter := middleware.NewRateLimiter(h.cfg.RateLimit.MaxConcurrentUsers)
	api := router.Group("/api/v1")
	api.Use(rateLimiter.Limit())
	{
		api.POST("/ocr/gemini", h.handleGeminiOCR)
		api.POST("/ocr/yandex", h.handleYandexOCR)
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

func (h *Handler) handleGeminiOCR(c *gin.Context) {
	// Получаем API ключ из header
	apiKey := c.GetHeader("X-Gemini-API-Key")
	if apiKey == "" {
		c.JSON(http.StatusUnauthorized, domain.ErrorResponse{
			Error:   "authentication_error",
			Message: "Gemini API key is required in X-Gemini-API-Key header",
		})
		return
	}

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

	// Создаем Gemini репозиторий с предоставленным API ключом (всегда используем gemini-3-pro-preview)
	geminiRepo := repository.NewGeminiRepository(apiKey, "gemini-3-pro-preview")
	geminiService := services.NewOCRService(geminiRepo, h.cfg.Workers.MaxWorkers)

	// Обрабатываем изображения
	response, err := geminiService.ProcessImages(
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

func (h *Handler) handleYandexOCR(c *gin.Context) {
	// Парсим форму
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

	// Создаем Yandex репозиторий с конфигурацией
	yandexRepo := repository.NewYandexOCRRepository(
		h.cfg.OCR.YandexAPIKey,
		h.cfg.OCR.YandexFolderID,
		h.cfg.OCR.YandexModel,
	)
	yandexService := services.NewOCRService(yandexRepo, h.cfg.Workers.MaxWorkers)

	// Обрабатываем изображения
	response, err := yandexService.ProcessImages(
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
