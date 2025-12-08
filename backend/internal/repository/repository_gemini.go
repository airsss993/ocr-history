package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
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
		model = "gemini-3-pro-preview"
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

	if r.apiKey == "" {
		err := fmt.Errorf("gemini API key is empty")
		logger.Error(err)
		return "", err
	}

	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: r.apiKey,
	})
	if err != nil {
		err := fmt.Errorf("failed to create Gemini client: %w", err)
		logger.Error(err)
		return "", err
	}

	mimeType := "image/jpeg"
	if len(data) > 4 {
		if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
			mimeType = "image/png"
		}
		if len(data) > 12 && data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
			data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50 {
			mimeType = "image/webp"
		}
	}

	contents := []*genai.Content{
		{
			Role: "user",
			Parts: []*genai.Part{
				{
					InlineData: &genai.Blob{
						MIMEType: mimeType,
						Data:     data,
					},
				},
			},
		},
	}

	config := &genai.GenerateContentConfig{
		Temperature: genai.Ptr[float32](0.3),
		TopP:        genai.Ptr[float32](1),
		ThinkingConfig: &genai.ThinkingConfig{
			ThinkingBudget: genai.Ptr[int32](16000),
		},
		MediaResolution:  genai.MediaResolutionHigh,
		ResponseMIMEType: "application/json",
		ResponseSchema: func() *genai.Schema {
			schemaJSON := `{
				"type": "object",
				"properties": {
					"summary": {
						"type": "string",
						"description": "Короткое саммари документа (2–4 предложения). Без выдумок: только по факту распознанного."
					},
					"language": {
						"type": "string",
						"description": "Язык распознанного документа. Для этой задачи всегда 'ru'.",
						"enum": ["ru"]
					},
					"document_title": {
						"type": "string",
						"description": "Заголовок документа, если есть. Если нет — пустая строка."
					},
					"text_markdown": {
						"type": "string",
						"description": "Полный распознанный текст всего документа в Markdown (включая таблицы в Markdown)."
					},
					"notes": {
						"type": "string",
						"description": "Заметки о сомнительных местах. Если нет — пустая строка."
					},
					"warnings": {
						"type": "array",
						"description": "Общие предупреждения (например, плохое качество, часть текста неразборчива).",
						"items": {
							"type": "string"
						}
					}
				},
				"required": ["summary", "language", "document_title", "text_markdown", "notes", "warnings"],
				"propertyOrdering": ["summary", "language", "document_title", "text_markdown", "notes", "warnings"]
			}`
			var schema genai.Schema
			if err := json.Unmarshal([]byte(schemaJSON), &schema); err != nil {
				log.Fatal(err)
			}
			return &schema
		}(),
		SystemInstruction: &genai.Content{
			Parts: []*genai.Part{
				genai.NewPartFromText(`Ты — специалист по оцифровке старинных документов (архивные бумаги, рукописи, дореформенная орфография, бледные чернила, пятна, разрывы). Твоя задача — извлечь весь видимый текст с фотографии и вернуть его строго в JSON, соответствующий указанной схеме.

Правила распознавания
	1.	Не выдумывай отсутствующий текст. Если символ/слово не читается — помечай это в notes и/или warnings.
	2.	Сохраняй орфографию оригинала (включая дореформенные буквы/написания), как на документе.
	•	Если уверен — пиши как есть.
	•	Если сомневаешься — используй маркеры:
	•	⟦неразборчиво⟧
	•	⟦возможн.: ...⟧ (1–3 варианта)
	3.	Сохраняй структуру: переносы строк, абзацы, заголовки, нумерацию, списки.
	4.	Таблицы: если видна таблица — оформляй в Markdown-таблицу. Если границы колонок сомнительны — всё равно делай таблицу и добавляй предупреждение.
	5.	Отмечай специальные элементы:
	•	подпись: помечай строкой *[Подпись]*: ... (если читается) или *[Подпись]*: ⟦неразборчиво⟧
	•	печать/штамп: *[Печать]*: ... или *[Печать]*: ⟦текст неразборчиво⟧
	6.	Если на фото несколько фрагментов/страниц — распознавай всё подряд, разделяя в text_markdown заметными разделителями ---.

Формат ответа
	•	Верни только валидный JSON
	•	Поля заполняй в таком смысле:
	•	summary: 2–4 предложения по факту того, что реально видно в тексте (тип документа, даты/место/лица, если читается).
	•	document_title: заголовок/шапка, если есть, иначе пустая строка.
	•	text_markdown: полный текст документа в Markdown.
	•	notes: сомнения/варианты чтения, где именно проблемы (например: "строка 3 сверху, правый край обрезан").
	•	warnings: список коротких предупреждений (качество, засвет, наклон, обрезано, размыто, курсив/скоропись, дореформенная орфография и т.д.).
`),
			},
		},
	}

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
