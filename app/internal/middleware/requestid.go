package middleware

import (
	"net/http"

	"github.com/Faheema125/trading-platform/internal/logging"
	"github.com/google/uuid"
)

// RequestID is middleware that extracts or generates a request ID
// and stores it in the request context.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" {
			id = uuid.New().String()
		}

		ctx := logging.WithRequestID(r.Context(), id)
		w.Header().Set("X-Request-ID", id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
