package domain

import "time"

type OCRResult struct {
	Filename string `json:"filename"`
	Text     string `json:"text"`
	Error    string `json:"error,omitempty"`
}

type OCRResponse struct {
	Results     []OCRResult `json:"results"`
	TotalImages int         `json:"total_images"`
	Successful  int         `json:"successful"`
	Failed      int         `json:"failed"`
	ProcessedAt time.Time   `json:"processed_at"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}
