package repository

import (
	"fmt"

	"github.com/airsss993/ocr-history/pkg/logger"
	"github.com/otiai10/gosseract/v2"
)

type TesseractRepository struct {
	languages []string
}

func NewTesseractRepository(langs ...string) *TesseractRepository {
	if len(langs) == 0 {
		langs = []string{"rus", "eng"}
	}

	return &TesseractRepository{
		languages: langs,
	}
}

func (r *TesseractRepository) RecognizeFromBytes(data []byte) (string, error) {
	if len(data) == 0 {
		err := fmt.Errorf("empty data")
		logger.Error(err)
		return "", err
	}

	client := gosseract.NewClient()
	defer client.Close()

	// Устанавливаем язык
	client.SetLanguage(r.languages...)

	// PSM (Page Segmentation Mode): 3 = Fully automatic page segmentation, but no OSD (Orientation and Script Detection)
	// Другие полезные режимы:
	// 1 = Automatic page segmentation with OSD
	// 6 = Assume a single uniform block of text
	// 11 = Sparse text. Find as much text as possible in no particular order
	// 12 = Sparse text with OSD
	client.SetPageSegMode(gosseract.PSM_AUTO)

	// Загружаем изображение
	if err := client.SetImageFromBytes(data); err != nil {
		err := fmt.Errorf("failed to load image: %w", err)
		logger.Error(err)
		return "", err
	}

	text, err := client.Text()
	if err != nil {
		err := fmt.Errorf("failed to recognize text: %w", err)
		logger.Error(err)
		return "", err
	}

	return text, nil
}
