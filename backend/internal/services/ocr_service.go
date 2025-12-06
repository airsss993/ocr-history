package services

import "github.com/airsss993/ocr-history/internal/repository"

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

//TODO
