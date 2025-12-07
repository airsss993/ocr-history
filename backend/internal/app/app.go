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
	"github.com/airsss993/ocr-history/internal/server"
	"github.com/airsss993/ocr-history/pkg/logger"
)

func Run() {
	cfg, err := config.Init()
	if err != nil {
		logger.Fatal(err)
	}

	logger.Info("Starting OCR backend with multi-provider support")
	logger.Info("Available endpoints: /api/v1/ocr/gemini, /api/v1/ocr/yandex")

	// Логируем конфигурацию Yandex (без полных ключей для безопасности)
	if cfg.OCR.YandexAPIKey != "" {
		logger.Info(fmt.Sprintf("Yandex API Key: configured (length: %d)", len(cfg.OCR.YandexAPIKey)))
	} else {
		logger.Warn("Yandex API Key: not configured")
	}

	if cfg.OCR.YandexFolderID != "" {
		logger.Info(fmt.Sprintf("Yandex Folder ID: %s", cfg.OCR.YandexFolderID))
	} else {
		logger.Warn("Yandex Folder ID: not configured")
	}

	logger.Info(fmt.Sprintf("Yandex Model: %s", cfg.OCR.YandexModel))

	handler := handlers.NewHandler(cfg)

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
