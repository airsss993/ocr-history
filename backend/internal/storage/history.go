package storage

import (
	"encoding/json"
	"sync"
	"time"
)

type HistoryEntry struct {
	ID          string          `json:"id"`
	ImageBase64 string          `json:"imageBase64"`
	OcrResult   json.RawMessage `json:"ocrResult"`
	CreatedAt   time.Time       `json:"createdAt"`
}

type clientData struct {
	entries    []HistoryEntry
	lastAccess time.Time
}

type HistoryStorage struct {
	data map[string]*clientData
	mu   sync.RWMutex
	ttl  time.Duration
}

func NewHistoryStorage(ttl time.Duration) *HistoryStorage {
	s := &HistoryStorage{
		data: make(map[string]*clientData),
		ttl:  ttl,
	}
	go s.cleanup()
	return s
}

func (s *HistoryStorage) Get(clientID string) []HistoryEntry {
	s.mu.RLock()
	defer s.mu.RUnlock()

	cd, ok := s.data[clientID]
	if !ok {
		return []HistoryEntry{}
	}

	result := make([]HistoryEntry, len(cd.entries))
	copy(result, cd.entries)
	return result
}

func (s *HistoryStorage) Add(clientID string, entry HistoryEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()

	cd, ok := s.data[clientID]
	if !ok {
		cd = &clientData{
			entries: []HistoryEntry{},
		}
		s.data[clientID] = cd
	}

	cd.entries = append([]HistoryEntry{entry}, cd.entries...)
	cd.lastAccess = time.Now()
}

func (s *HistoryStorage) Delete(clientID, entryID string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	cd, ok := s.data[clientID]
	if !ok {
		return false
	}

	for i, entry := range cd.entries {
		if entry.ID == entryID {
			cd.entries = append(cd.entries[:i], cd.entries[i+1:]...)
			cd.lastAccess = time.Now()
			return true
		}
	}
	return false
}

func (s *HistoryStorage) Clear(clientID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.data, clientID)
}

func (s *HistoryStorage) cleanup() {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		s.mu.Lock()
		now := time.Now()
		for clientID, cd := range s.data {
			if now.Sub(cd.lastAccess) > s.ttl {
				delete(s.data, clientID)
			}
		}
		s.mu.Unlock()
	}
}
