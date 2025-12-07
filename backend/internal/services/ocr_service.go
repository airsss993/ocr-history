package services

import (
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/airsss993/ocr-history/internal/domain"
	"github.com/airsss993/ocr-history/internal/repository"
)

type OCRService struct {
	repo        repository.OCRRepository
	workerSlots chan struct{}
}

func NewOCRService(repo repository.OCRRepository, maxWorkers int) *OCRService {
	return &OCRService{
		repo:        repo,
		workerSlots: make(chan struct{}, maxWorkers),
	}
}

func (s *OCRService) ProcessImages(files []*multipart.FileHeader, maxSizeMB int, supportedFormats []string) (*domain.OCRResponse, error) {
	var wg sync.WaitGroup
	var mu sync.Mutex
	results := make([]domain.OCRResult, len(files))

	for i, file := range files {
		wg.Add(1)
		go func(idx int, f *multipart.FileHeader) {
			defer wg.Done()

			s.workerSlots <- struct{}{}
			defer func() { <-s.workerSlots }()

			result := s.processImage(f, maxSizeMB, supportedFormats)

			mu.Lock()
			results[idx] = result
			mu.Unlock()
		}(i, file)
	}

	wg.Wait()

	successful, failed := 0, 0
	for _, r := range results {
		if r.Error == "" {
			successful++
		} else {
			failed++
		}
	}

	return &domain.OCRResponse{
		Results:     results,
		TotalImages: len(files),
		Successful:  successful,
		Failed:      failed,
		ProcessedAt: time.Now(),
	}, nil
}

func (s *OCRService) processImage(file *multipart.FileHeader, maxSizeMB int, supportedFormats []string) domain.OCRResult {
	result := domain.OCRResult{Filename: file.Filename}

	if err := validateImageSize(file, maxSizeMB); err != nil {
		result.Error = err.Error()
		return result
	}

	if err := validateImageFormat(file.Filename, supportedFormats); err != nil {
		result.Error = err.Error()
		return result
	}

	f, err := file.Open()
	if err != nil {
		result.Error = fmt.Sprintf("failed to open file: %v", err)
		return result
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		result.Error = fmt.Sprintf("failed to read file: %v", err)
		return result
	}

	text, err := s.repo.RecognizeFromBytes(data)
	if err != nil {
		result.Error = err.Error()
		return result
	}

	var jsonCheck interface{}
	if json.Unmarshal([]byte(text), &jsonCheck) == nil {
		result.Text = json.RawMessage(text)
	} else {
		textJSON, _ := json.Marshal(text)
		result.Text = json.RawMessage(textJSON)
	}

	return result
}

func validateImageSize(file *multipart.FileHeader, maxSizeMB int) error {
	maxBytes := int64(maxSizeMB * 1024 * 1024)
	if file.Size > maxBytes {
		return fmt.Errorf("file size %d bytes exceeds maximum %d MB", file.Size, maxSizeMB)
	}
	return nil
}

func validateImageFormat(filename string, supportedFormats []string) error {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(filename), "."))
	for _, format := range supportedFormats {
		if ext == format {
			return nil
		}
	}
	return fmt.Errorf("unsupported format: %s", ext)
}
