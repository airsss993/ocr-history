package ratelimiter

import (
	"context"
	"sync"
	"time"
)

type YandexRateLimiter struct {
	tokens     chan struct{}
	refillRate time.Duration
	stopCh     chan struct{}
	stopOnce   sync.Once
	wg         sync.WaitGroup
}

func NewYandexRateLimiter(requestsPerSecond int) *YandexRateLimiter {
	if requestsPerSecond <= 0 {
		requestsPerSecond = 10
	}

	rl := &YandexRateLimiter{
		tokens:     make(chan struct{}, requestsPerSecond),
		refillRate: time.Second / time.Duration(requestsPerSecond),
		stopCh:     make(chan struct{}),
	}

	for i := 0; i < requestsPerSecond; i++ {
		rl.tokens <- struct{}{}
	}

	rl.wg.Add(1)
	go rl.refill()

	return rl
}

func (rl *YandexRateLimiter) refill() {
	defer rl.wg.Done()
	ticker := time.NewTicker(rl.refillRate)
	defer ticker.Stop()

	for {
		select {
		case <-rl.stopCh:
			return
		case <-ticker.C:
			select {
			case rl.tokens <- struct{}{}:
				// Token added
			default:
				// Bucket is full, discard
			}
		}
	}
}

func (rl *YandexRateLimiter) Acquire(ctx context.Context) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-rl.tokens:
		return nil
	}
}

func (rl *YandexRateLimiter) TryAcquire() bool {
	select {
	case <-rl.tokens:
		return true
	default:
		return false
	}
}

func (rl *YandexRateLimiter) Stop() {
	rl.stopOnce.Do(func() {
		close(rl.stopCh)
		rl.wg.Wait()
	})
}
