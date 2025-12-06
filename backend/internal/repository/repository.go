package repository

type OCRRepository interface {
	RecognizeFromBytes(data []byte) (string, error)
}
