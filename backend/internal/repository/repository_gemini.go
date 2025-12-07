package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/airsss993/ocr-history/pkg/logger"
	"google.golang.org/genai"
)

type GeminiRepository struct {
	apiKey string
	model  string
}

func NewGeminiRepository(apiKey, model string) *GeminiRepository {
	if model == "" {
		model = "gemini-3-pro-preview" // По умолчанию используем gemini-3-pro-preview
	}
	return &GeminiRepository{
		apiKey: apiKey,
		model:  model,
	}
}

func (r *GeminiRepository) RecognizeFromBytes(data []byte) (string, error) {
	if len(data) == 0 {
		err := fmt.Errorf("empty data")
		logger.Error(err)
		return "", err
	}

	ctx := context.Background()

	// Проверяем наличие API ключа
	if r.apiKey == "" {
		err := fmt.Errorf("Gemini API key is empty")
		logger.Error(err)
		return "", err
	}

	// Создаем клиент Gemini с API ключом
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: r.apiKey,
	})
	if err != nil {
		err := fmt.Errorf("failed to create Gemini client: %w", err)
		logger.Error(err)
		return "", err
	}

	// Определяем MIME тип изображения
	mimeType := "image/jpeg"
	if len(data) > 4 {
		// PNG signature: 89 50 4E 47
		if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
			mimeType = "image/png"
		}
		// WEBP signature: RIFF....WEBP
		if len(data) > 12 && data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
			data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50 {
			mimeType = "image/webp"
		}
	}

	// Формируем промпт с изображением (строго по примеру)
	contents := []*genai.Content{
		{
			Role: "user",
			Parts: []*genai.Part{
				{
					InlineData: &genai.Blob{
						MIMEType: mimeType,
						Data:     data, // Передаем сырые байты, не base64
					},
				},
			},
		},
	}

	// Конфигурация генерации
	config := &genai.GenerateContentConfig{
		Temperature: genai.Ptr[float32](0),
		TopP:        genai.Ptr[float32](1),
		SystemInstruction: &genai.Content{
			Parts: []*genai.Part{
				genai.NewPartFromText("Ты - специалист по оцифровке документов.\n\nЗАДАЧА: Верни весь текст документа.\n\nФОРМАТ ОТВЕТА:\nВыведи весь распознанный текст в формате Markdown.\n\nВАЖНО:\n- Документ может содержать рукописный текст.\n- Документ на русском языке.\n- Внимательно оформляй таблицы, чтобы они были в формате Markdown. Сохраняй исходную структуру таблиц."),
			},
		},
	}

	// Используем streaming для получения результата (строго по примеру)
	var resultText strings.Builder

	for result, err := range client.Models.GenerateContentStream(ctx, r.model, contents, config) {
		if err != nil {
			err := fmt.Errorf("failed to generate content: %w", err)
			logger.Error(err)
			return "", err
		}

		if len(result.Candidates) == 0 || result.Candidates[0].Content == nil || len(result.Candidates[0].Content.Parts) == 0 {
			continue
		}

		parts := result.Candidates[0].Content.Parts
		for _, part := range parts {
			fmt.Print(part.Text)
			if part.Text != "" {
				resultText.WriteString(part.Text)
			}
		}
	}

	text := resultText.String()
	if text == "" {
		logger.Warn("empty result from Gemini API")
		return "", nil
	}

	return text, nil
}
