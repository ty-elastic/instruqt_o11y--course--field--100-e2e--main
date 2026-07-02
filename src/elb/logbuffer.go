package main

import "sync"

// accessLogBuffer is a thread-safe append-only buffer of pre-marshaled JSON docs.
// The Drain method swaps out the current slice atomically so the log flusher goroutine
// can drain without blocking request handlers for more than a mutex acquisition.
type accessLogBuffer struct {
	mu   sync.Mutex
	docs [][]byte
}

func newAccessLogBuffer() *accessLogBuffer {
	return &accessLogBuffer{docs: make([][]byte, 0, 64)}
}

// Append adds a pre-marshaled JSON document to the buffer.
func (b *accessLogBuffer) Append(doc []byte) {
	b.mu.Lock()
	b.docs = append(b.docs, doc)
	b.mu.Unlock()
}

// Drain atomically returns and clears the current buffer contents.
func (b *accessLogBuffer) Drain() [][]byte {
	b.mu.Lock()
	old := b.docs
	b.docs = make([][]byte, 0, 64)
	b.mu.Unlock()
	return old
}
