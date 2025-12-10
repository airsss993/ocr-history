package repository

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/airsss993/ocr-history/internal/ratelimiter"
	"github.com/airsss993/ocr-history/pkg/logger"
)

const (
	yandexSyncOCREndpoint = "https://ocr.api.cloud.yandex.net/ocr/v1/recognizeText"
)

type YandexOCRRepository struct {
	apiKey      string
	folderID    string
	model       string
	rateLimiter *ratelimiter.YandexRateLimiter
	client      *http.Client
}

func NewYandexOCRRepository(
	apiKey, folderID, model string,
	rateLimiter *ratelimiter.YandexRateLimiter,
) *YandexOCRRepository {
	if model == "" {
		model = "page"
	}
	return &YandexOCRRepository{
		apiKey:      apiKey,
		folderID:    folderID,
		model:       model,
		rateLimiter: rateLimiter,
		client:      &http.Client{Timeout: 240 * time.Second},
	}
}

// Yandex OCR API Request
type yandexOCRRequest struct {
	MimeType      string   `json:"mimeType"`
	LanguageCodes []string `json:"languageCodes"`
	Model         string   `json:"model"`
	Content       string   `json:"content"`
}

// Yandex OCR API Response
type yandexOCRResponse struct {
	Result *yandexResult `json:"result,omitempty"`
}

type yandexResult struct {
	TextAnnotation *yandexTextAnnotation `json:"textAnnotation,omitempty"`
}

type yandexTextAnnotation struct {
	Width    string         `json:"width"`
	Height   string         `json:"height"`
	Blocks   []yandexBlock  `json:"blocks"`
	Entities []yandexEntity `json:"entities,omitempty"`
}

type yandexBlock struct {
	BoundingBox yandexPolygon `json:"boundingBox"`
	Lines       []yandexLine  `json:"lines"`
}

type yandexLine struct {
	BoundingBox yandexPolygon `json:"boundingBox"`
	Text        string        `json:"text"`
	Words       []yandexWord  `json:"words"`
	Confidence  float64       `json:"confidence"`
}

type yandexWord struct {
	BoundingBox  yandexPolygon       `json:"boundingBox"`
	Text         string              `json:"text"`
	Confidence   float64             `json:"confidence"`
	EntityIndex  string              `json:"entityIndex,omitempty"`
	TextSegments []yandexTextSegment `json:"textSegments,omitempty"`
}

type yandexPolygon struct {
	Vertices []yandexVertex `json:"vertices"`
}

type yandexVertex struct {
	X string `json:"x"`
	Y string `json:"y"`
}

type yandexTextSegment struct {
	StartIndex string `json:"startIndex"`
	Length     string `json:"length"`
}

type yandexEntity struct {
	Name string `json:"name"`
	Text string `json:"text"`
}

type yandexError struct {
	Code    int           `json:"code"`
	Message string        `json:"message"`
	Details []interface{} `json:"details,omitempty"`
}

func (r *YandexOCRRepository) RecognizeFromBytes(data []byte) (string, error) {
	if len(data) == 0 {
		err := fmt.Errorf("empty data")
		logger.Error(err)
		return "", err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	if err := r.rateLimiter.Acquire(ctx); err != nil {
		err := fmt.Errorf("rate limiter timeout: %w", err)
		logger.Error(err)
		return "", err
	}

	encodedImage := base64.StdEncoding.EncodeToString(data)

	mimeType := "JPEG"
	if len(data) > 4 {
		if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
			mimeType = "PNG"
		}
	}

	reqBody := yandexOCRRequest{
		MimeType:      mimeType,
		LanguageCodes: []string{"ru", "en"},
		Model:         r.model,
		Content:       encodedImage,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		err := fmt.Errorf("failed to marshal request: %w", err)
		logger.Error(err)
		return "", err
	}

	req, err := http.NewRequest(
		"POST",
		yandexSyncOCREndpoint,
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		err := fmt.Errorf("failed to create request: %w", err)
		logger.Error(err)
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", r.apiKey))
	req.Header.Set("x-folder-id", r.folderID)
	req.Header.Set("x-data-logging-enabled", "false")

	resp, err := r.client.Do(req)
	if err != nil {
		err := fmt.Errorf("failed to send request: %w", err)
		logger.Error(err)
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		err := fmt.Errorf("failed to read response: %w", err)
		logger.Error(err)
		return "", err
	}

	if resp.StatusCode != http.StatusOK {
		var apiError yandexError
		if json.Unmarshal(body, &apiError) == nil && apiError.Message != "" {
			err := fmt.Errorf("yandex API error (status %d): %s", resp.StatusCode, apiError.Message)
			logger.Error(err)
			return "", err
		}
		err := fmt.Errorf("yandex API returned status %d: %s", resp.StatusCode, string(body))
		logger.Error(err)
		return "", err
	}

	var ocrResp yandexOCRResponse
	if err := json.Unmarshal(body, &ocrResp); err != nil {
		err := fmt.Errorf("failed to unmarshal response: %w", err)
		logger.Error(err)
		return "", err
	}

	if ocrResp.Result == nil || ocrResp.Result.TextAnnotation == nil {
		logger.Warn("empty result from Yandex OCR API")
		return "", nil
	}

	return string(body), nil
}
