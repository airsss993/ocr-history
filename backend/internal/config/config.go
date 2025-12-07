package config

import (
	"fmt"
	"time"

	"github.com/airsss993/ocr-history/pkg/logger"
	"github.com/joho/godotenv"
	"github.com/spf13/viper"
)

type (
	Config struct {
		Server    Server
		Workers   Workers
		OCR       OCR
		RateLimit RateLimit
	}

	Server struct {
		Host           string
		Port           string
		ReadTimeout    time.Duration
		WriteTimeout   time.Duration
		MaxHeaderBytes int
		IdleTimeout    time.Duration
	}

	Workers struct {
		MaxWorkers int
	}

	OCR struct {
		Provider               string   `mapstructure:"provider"` // "tesseract", "yandex" или "google"
		MaxImagesPerRequest    int      `mapstructure:"maxImagesPerRequest"`
		MaxImageSizeMB         int      `mapstructure:"maxImageSizeMB"`
		SupportedFormats       []string `mapstructure:"supportedFormats"`
		Languages              []string `mapstructure:"languages"`
		YandexAPIKey           string   `mapstructure:"yandexApiKey"`
		YandexFolderID         string   `mapstructure:"yandexFolderId"`
		YandexModel            string   `mapstructure:"yandexModel"` // "page" или "handwritten"
		GoogleCredentialsPath  string   `mapstructure:"googleCredentialsPath"`
	}

	RateLimit struct {
		MaxConcurrentUsers int `mapstructure:"maxConcurrentUsers"`
		RequestsPerMinute  int `mapstructure:"requestsPerMinute"`
	}
)

func Init() (*Config, error) {
	err := godotenv.Load()
	if err != nil {
		logger.Warn("No .env file found, using system environment variables")
	}

	if err := parseConfigFile("./configs"); err != nil {
		logger.Error(err)
		return nil, fmt.Errorf("failed to parse configuration file: %w", err)
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		logger.Error(err)
		return nil, fmt.Errorf("failed to unmarshal configuration: %w", err)
	}

	// Переопределяем из переменных окружения если они установлены
	if provider := viper.GetString("OCR_PROVIDER"); provider != "" {
		cfg.OCR.Provider = provider
	}
	if apiKey := viper.GetString("YANDEX_API_KEY"); apiKey != "" {
		cfg.OCR.YandexAPIKey = apiKey
	}
	if folderID := viper.GetString("YANDEX_FOLDER_ID"); folderID != "" {
		cfg.OCR.YandexFolderID = folderID
	}
	if credPath := viper.GetString("GOOGLE_CREDENTIALS_PATH"); credPath != "" {
		cfg.OCR.GoogleCredentialsPath = credPath
	}

	return &cfg, nil
}

func parseConfigFile(folder string) error {
	viper.AddConfigPath(folder)
	viper.SetConfigName("main")
	viper.SetConfigType("yml")

	viper.AutomaticEnv()

	return viper.ReadInConfig()
}
