package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/airsss993/ocr-history/internal/config"
	"github.com/airsss993/ocr-history/internal/domain"
	"github.com/airsss993/ocr-history/internal/middleware"
	"github.com/airsss993/ocr-history/internal/repository"
	"github.com/airsss993/ocr-history/internal/services"
	"github.com/airsss993/ocr-history/internal/storage"
	"github.com/airsss993/ocr-history/pkg/logger"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	cfg            *config.Config
	historyStorage *storage.HistoryStorage
}

func NewHandler(cfg *config.Config, historyStorage *storage.HistoryStorage) *Handler {
	return &Handler{
		cfg:            cfg,
		historyStorage: historyStorage,
	}
}

func (h *Handler) Init() *gin.Engine {
	router := gin.New()

	router.Use(
		gin.Recovery(),
		gin.Logger(),
		middleware.CORS(),
	)

	router.GET("/health", h.healthCheck)
	router.GET("/ready", h.readinessCheck)

	rateLimiter := middleware.NewRateLimiter(h.cfg.RateLimit.MaxConcurrentUsers)
	api := router.Group("/api/v1")
	api.Use(rateLimiter.Limit())
	{
		api.POST("/ocr/gemini", h.handleGeminiOCR)
		api.POST("/ocr/yandex", h.handleYandexOCR)

		api.GET("/history", h.handleGetHistory)
		api.POST("/history", h.handleAddHistory)
		api.DELETE("/history/:id", h.handleDeleteHistoryEntry)
		api.DELETE("/history", h.handleClearHistory)
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
	authKey := c.GetHeader("X-Gemini-API-Key")
	if authKey == "" || authKey != h.cfg.OCR.GeminiAuthKey {
		c.JSON(http.StatusUnauthorized, domain.ErrorResponse{
			Error:   "authentication_error",
			Message: "Invalid or missing authentication key",
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

	geminiRepo := repository.NewGeminiRepository(h.cfg.OCR.GeminiAPIKey, h.cfg.OCR.GeminiModel)
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

func (h *Handler) getClientID(c *gin.Context) string {
	return c.GetHeader("X-Client-ID")
}

func (h *Handler) handleGetHistory(c *gin.Context) {
	clientID := h.getClientID(c)
	if clientID == "" {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "X-Client-ID header is required",
		})
		return
	}

	entries := h.historyStorage.Get(clientID)
	c.JSON(http.StatusOK, gin.H{
		"entries": entries,
	})
}

type AddHistoryRequest struct {
	ImageBase64 string          `json:"imageBase64"`
	OcrResult   json.RawMessage `json:"ocrResult"`
}

func (h *Handler) handleAddHistory(c *gin.Context) {
	clientID := h.getClientID(c)
	if clientID == "" {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "X-Client-ID header is required",
		})
		return
	}

	var req AddHistoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "invalid request body",
		})
		return
	}

	entry := storage.HistoryEntry{
		ID:          strconv.FormatInt(time.Now().UnixNano(), 10),
		ImageBase64: req.ImageBase64,
		OcrResult:   req.OcrResult,
		CreatedAt:   time.Now(),
	}

	h.historyStorage.Add(clientID, entry)

	c.JSON(http.StatusOK, gin.H{
		"entry": entry,
	})
}

func (h *Handler) handleDeleteHistoryEntry(c *gin.Context) {
	clientID := h.getClientID(c)
	if clientID == "" {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "X-Client-ID header is required",
		})
		return
	}

	entryID := c.Param("id")
	deleted := h.historyStorage.Delete(clientID, entryID)

	c.JSON(http.StatusOK, gin.H{
		"deleted": deleted,
	})
}

func (h *Handler) handleClearHistory(c *gin.Context) {
	clientID := h.getClientID(c)
	if clientID == "" {
		c.JSON(http.StatusBadRequest, domain.ErrorResponse{
			Error:   "validation_error",
			Message: "X-Client-ID header is required",
		})
		return
	}

	h.historyStorage.Clear(clientID)

	c.JSON(http.StatusOK, gin.H{
		"cleared": true,
	})
}
