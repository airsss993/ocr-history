package repository

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/airsss993/ocr-history/pkg/logger"
	"github.com/golang-jwt/jwt/v5"
)

type GoogleVisionRepository struct {
	credentialsPath string // Путь к JSON файлу с credentials
}

func NewGoogleVisionRepository(credentialsPath string) *GoogleVisionRepository {
	return &GoogleVisionRepository{
		credentialsPath: credentialsPath,
	}
}

// Google Vision API Request
type googleVisionRequest struct {
	Requests []googleImageRequest `json:"requests"`
}

type googleImageRequest struct {
	Image    googleImage    `json:"image"`
	Features []googleFeature `json:"features"`
}

type googleImage struct {
	Content string `json:"content"` // base64 encoded image
}

type googleFeature struct {
	Type       string `json:"type"`
	MaxResults int    `json:"maxResults,omitempty"`
}

// Google Vision API Response
type googleVisionResponse struct {
	Responses []googleAnnotateImageResponse `json:"responses"`
}

type googleAnnotateImageResponse struct {
	TextAnnotations []googleTextAnnotation `json:"textAnnotations,omitempty"`
	FullTextAnnotation *googleTextAnnotation `json:"fullTextAnnotation,omitempty"`
	Error          *googleError           `json:"error,omitempty"`
}

type googleTextAnnotation struct {
	Locale      string              `json:"locale,omitempty"`
	Description string              `json:"description"`
	BoundingPoly *googleBoundingPoly `json:"boundingPoly,omitempty"`
	Pages       []googlePage        `json:"pages,omitempty"`
}

type googleBoundingPoly struct {
	Vertices []googleVertex `json:"vertices"`
}

type googleVertex struct {
	X int `json:"x"`
	Y int `json:"y"`
}

type googlePage struct {
	Property     *googleTextProperty `json:"property,omitempty"`
	Width        int                 `json:"width"`
	Height       int                 `json:"height"`
	Blocks       []googleBlock       `json:"blocks"`
	Confidence   float64             `json:"confidence"`
}

type googleBlock struct {
	Property     *googleTextProperty `json:"property,omitempty"`
	BoundingBox  *googleBoundingPoly `json:"boundingBox,omitempty"`
	Paragraphs   []googleParagraph   `json:"paragraphs"`
	BlockType    string              `json:"blockType"`
	Confidence   float64             `json:"confidence"`
}

type googleParagraph struct {
	Property     *googleTextProperty `json:"property,omitempty"`
	BoundingBox  *googleBoundingPoly `json:"boundingBox,omitempty"`
	Words        []googleWord        `json:"words"`
	Confidence   float64             `json:"confidence"`
}

type googleWord struct {
	Property     *googleTextProperty `json:"property,omitempty"`
	BoundingBox  *googleBoundingPoly `json:"boundingBox,omitempty"`
	Symbols      []googleSymbol      `json:"symbols"`
	Confidence   float64             `json:"confidence"`
}

type googleSymbol struct {
	Property     *googleTextProperty `json:"property,omitempty"`
	BoundingBox  *googleBoundingPoly `json:"boundingBox,omitempty"`
	Text         string              `json:"text"`
	Confidence   float64             `json:"confidence"`
}

type googleTextProperty struct {
	DetectedLanguages []googleDetectedLanguage `json:"detectedLanguages,omitempty"`
	DetectedBreak     *googleDetectedBreak     `json:"detectedBreak,omitempty"`
}

type googleDetectedLanguage struct {
	LanguageCode string  `json:"languageCode"`
	Confidence   float64 `json:"confidence"`
}

type googleDetectedBreak struct {
	Type       string `json:"type"`
	IsPrefix   bool   `json:"isPrefix,omitempty"`
}

type googleError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Status  string `json:"status"`
}

// Service Account JSON structure
type serviceAccountKey struct {
	Type                    string `json:"type"`
	ProjectID               string `json:"project_id"`
	PrivateKeyID            string `json:"private_key_id"`
	PrivateKey              string `json:"private_key"`
	ClientEmail             string `json:"client_email"`
	ClientID                string `json:"client_id"`
	AuthURI                 string `json:"auth_uri"`
	TokenURI                string `json:"token_uri"`
	AuthProviderX509CertURL string `json:"auth_provider_x509_cert_url"`
	ClientX509CertURL       string `json:"client_x509_cert_url"`
}

// getAccessToken получает access token используя service account
func (r *GoogleVisionRepository) getAccessToken() (string, error) {
	// Читаем файл с credentials
	credData, err := os.ReadFile(r.credentialsPath)
	if err != nil {
		return "", fmt.Errorf("failed to read credentials file: %w", err)
	}

	var serviceAccount serviceAccountKey
	if err := json.Unmarshal(credData, &serviceAccount); err != nil {
		return "", fmt.Errorf("failed to parse credentials: %w", err)
	}

	// Парсим приватный ключ
	block, _ := pem.Decode([]byte(serviceAccount.PrivateKey))
	if block == nil {
		return "", fmt.Errorf("failed to decode private key")
	}

	privateKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return "", fmt.Errorf("failed to parse private key: %w", err)
	}

	rsaKey, ok := privateKey.(*rsa.PrivateKey)
	if !ok {
		return "", fmt.Errorf("private key is not RSA key")
	}

	// Создаем JWT
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   serviceAccount.ClientEmail,
		"scope": "https://www.googleapis.com/auth/cloud-vision",
		"aud":   "https://oauth2.googleapis.com/token",
		"exp":   now.Add(time.Hour).Unix(),
		"iat":   now.Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	signedToken, err := token.SignedString(rsaKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT: %w", err)
	}

	// Обмениваем JWT на access token
	data := url.Values{}
	data.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	data.Set("assertion", signedToken)

	resp, err := http.PostForm("https://oauth2.googleapis.com/token", data)
	if err != nil {
		return "", fmt.Errorf("failed to exchange JWT for token: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read token response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("token exchange failed: %s", string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		TokenType   string `json:"token_type"`
	}

	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", fmt.Errorf("failed to parse token response: %w", err)
	}

	return tokenResp.AccessToken, nil
}

func (r *GoogleVisionRepository) RecognizeFromBytes(data []byte) (string, error) {
	if len(data) == 0 {
		err := fmt.Errorf("empty data")
		logger.Error(err)
		return "", err
	}

	// Кодируем изображение в base64
	encodedImage := base64.StdEncoding.EncodeToString(data)

	// Формируем запрос к Google Vision API
	// Используем TEXT_DETECTION для обнаружения текста
	reqBody := googleVisionRequest{
		Requests: []googleImageRequest{
			{
				Image: googleImage{
					Content: encodedImage,
				},
				Features: []googleFeature{
					{
						Type: "TEXT_DETECTION", // или "DOCUMENT_TEXT_DETECTION" для документов
					},
				},
			},
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		err := fmt.Errorf("failed to marshal request: %w", err)
		logger.Error(err)
		return "", err
	}

	// Получаем access token
	accessToken, err := r.getAccessToken()
	if err != nil {
		err := fmt.Errorf("failed to get access token: %w", err)
		logger.Error(err)
		return "", err
	}

	// Создаем HTTP запрос
	apiURL := "https://vision.googleapis.com/v1/images:annotate"
	req, err := http.NewRequest(
		"POST",
		apiURL,
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		err := fmt.Errorf("failed to create request: %w", err)
		logger.Error(err)
		return "", err
	}

	// Устанавливаем заголовки
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", accessToken))

	// Отправляем запрос
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		err := fmt.Errorf("failed to send request: %w", err)
		logger.Error(err)
		return "", err
	}
	defer resp.Body.Close()

	// Читаем ответ
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		err := fmt.Errorf("failed to read response: %w", err)
		logger.Error(err)
		return "", err
	}

	// Проверяем статус код
	if resp.StatusCode != http.StatusOK {
		// Пытаемся распарсить ошибку
		var apiError struct {
			Error googleError `json:"error"`
		}
		if json.Unmarshal(body, &apiError) == nil && apiError.Error.Message != "" {
			err := fmt.Errorf("google vision API error (status %d): %s", resp.StatusCode, apiError.Error.Message)
			logger.Error(err)
			return "", err
		}
		err := fmt.Errorf("google vision API returned status %d: %s", resp.StatusCode, string(body))
		logger.Error(err)
		return "", err
	}

	// Парсим ответ
	var visionResp googleVisionResponse
	if err := json.Unmarshal(body, &visionResp); err != nil {
		err := fmt.Errorf("failed to unmarshal response: %w", err)
		logger.Error(err)
		return "", err
	}

	// Проверяем наличие результата
	if len(visionResp.Responses) == 0 {
		logger.Warn("empty response from Google Vision API")
		return "", nil
	}

	// Проверяем на ошибки в ответе
	if visionResp.Responses[0].Error != nil {
		err := fmt.Errorf("google vision API error: %s", visionResp.Responses[0].Error.Message)
		logger.Error(err)
		return "", err
	}

	// Извлекаем текст
	text := extractTextFromGoogleResponse(&visionResp)
	return text, nil
}

func extractTextFromGoogleResponse(resp *googleVisionResponse) string {
	if len(resp.Responses) == 0 {
		return ""
	}

	response := resp.Responses[0]

	// Используем первую аннотацию которая содержит весь распознанный текст
	// Первый элемент TextAnnotations содержит полный текст изображения
	if len(response.TextAnnotations) > 0 {
		return response.TextAnnotations[0].Description
	}

	// Если первый метод не сработал, собираем текст из блоков
	if response.FullTextAnnotation != nil && len(response.FullTextAnnotation.Pages) > 0 {
		var lines []string
		for _, page := range response.FullTextAnnotation.Pages {
			for _, block := range page.Blocks {
				for _, paragraph := range block.Paragraphs {
					var words []string
					for _, word := range paragraph.Words {
						var symbols []string
						for _, symbol := range word.Symbols {
							symbols = append(symbols, symbol.Text)
						}
						words = append(words, strings.Join(symbols, ""))
					}
					lines = append(lines, strings.Join(words, " "))
				}
			}
		}
		return strings.Join(lines, "\n")
	}

	return ""
}
