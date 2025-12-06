package domain

type OCRResult struct {
	Filename string `json:"filename"`
	Text     string `json:"text"`
	Error    string `json:"error,omitempty"`
}
