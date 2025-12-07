package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/airsss993/ocr-history/internal/config"
	"github.com/airsss993/ocr-history/internal/handlers"
	"github.com/airsss993/ocr-history/internal/repository"
	"github.com/airsss993/ocr-history/internal/server"
	"github.com/airsss993/ocr-history/internal/services"
	"github.com/airsss993/ocr-history/pkg/logger"
)

func Run() {
	cfg, err := config.Init()
	if err != nil {
		logger.Fatal(err)
	}

	// Выбираем OCR провайдер на основе конфигурации
	var ocrRepo repository.OCRRepository
	switch cfg.OCR.Provider {
	case "yandex":
		logger.Info(fmt.Sprintf("Using Yandex OCR provider (model: %s)", cfg.OCR.YandexModel))
		ocrRepo = repository.NewYandexOCRRepository(
			cfg.OCR.YandexAPIKey,
			cfg.OCR.YandexFolderID,
			cfg.OCR.YandexModel,
		)
	case "google":
		logger.Info("Using Google Vision OCR provider")
		ocrRepo = repository.NewGoogleVisionRepository(cfg.OCR.GoogleCredentialsPath)
	case "gemini":
		logger.Info(fmt.Sprintf("Using Gemini LLM OCR provider (model: %s)", cfg.OCR.GeminiModel))
		ocrRepo = repository.NewGeminiRepository(cfg.OCR.GeminiAPIKey, cfg.OCR.GeminiModel)
	case "tesseract":
		fallthrough
	default:
		logger.Info("Using Tesseract OCR provider")
		ocrRepo = repository.NewTesseractRepository(cfg.OCR.Languages...)
	}

	ocrService := services.NewOCRService(ocrRepo, cfg.Workers.MaxWorkers)

	handler := handlers.NewHandler(cfg, ocrService)

	router := handler.Init()

	srv := server.NewServer(cfg, router)

	go func() {
		if err := srv.Run(); err != nil {
			logger.Fatal(err)
		}
	}()

	logger.Info(fmt.Sprintf("ocr-backend started on port %s", cfg.Server.Port))

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Stop(ctx); err != nil {
		logger.Error(fmt.Errorf("server forced to shutdown: %w", err))
	}

	logger.Info("server exited")
}
