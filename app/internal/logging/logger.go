package logging

import (
	"context"
	"encoding/json"
	"os"
	"time"
)

type contextKey string

const requestIDKey contextKey = "request_id"

// WithRequestID stores a request ID in the context.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey, id)
}

// GetRequestID retrieves the request ID from context.
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey).(string); ok {
		return id
	}
	return ""
}

// LogEntry represents a structured log line.
type LogEntry struct {
	Timestamp string `json:"timestamp"`
	Level     string `json:"level"`
	Msg       string `json:"msg"`
	RequestID string `json:"request_id,omitempty"`
	Error     string `json:"error,omitempty"`
	OrderID   string `json:"order_id,omitempty"`
}

// Info logs an info-level structured JSON message.
func Info(ctx context.Context, msg string, fields ...func(*LogEntry)) {
	entry := &LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Level:     "info",
		Msg:       msg,
		RequestID: GetRequestID(ctx),
	}
	for _, f := range fields {
		f(entry)
	}
	writeEntry(entry)
}

// Error logs an error-level structured JSON message.
func Error(ctx context.Context, msg string, err error, fields ...func(*LogEntry)) {
	entry := &LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Level:     "error",
		Msg:       msg,
		RequestID: GetRequestID(ctx),
	}
	if err != nil {
		entry.Error = err.Error()
	}
	for _, f := range fields {
		f(entry)
	}
	writeEntry(entry)
}

// WithOrderID is a field setter for order ID.
func WithOrderID(id string) func(*LogEntry) {
	return func(e *LogEntry) {
		e.OrderID = id
	}
}

func writeEntry(entry *LogEntry) {
	json.NewEncoder(os.Stdout).Encode(entry)
}
