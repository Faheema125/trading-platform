package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/Faheema125/trading-platform/internal/database"
	"github.com/Faheema125/trading-platform/internal/logging"
	"github.com/Faheema125/trading-platform/internal/middleware"
)

var db *database.DB

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize database
	var err error
	db, err = database.New(ctx)
	if err != nil {
		logging.Error(ctx, "failed to connect to database", err)
		os.Exit(1)
	}
	defer db.Close()

	logging.Info(ctx, "database connected")

	// Set up routes
	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/ready", handleReady)
	mux.HandleFunc("/orders", handleOrders)
	mux.HandleFunc("/orders/", handleGetOrder)

	// Wrap with middleware
	handler := middleware.RequestID(mux)

	// Configure server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      handler,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		logging.Info(ctx, "shutting down server")
		shutdownCtx, shutdownCancel := context.WithTimeout(ctx, 10*time.Second)
		defer shutdownCancel()
		srv.Shutdown(shutdownCtx)
	}()

	logging.Info(ctx, "server starting", func(e *logging.LogEntry) {
		e.Msg = "server starting on port " + port
	})

	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		logging.Error(ctx, "server error", err)
		os.Exit(1)
	}
}

func handleOrders(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodPost:
		handleCreateOrder(w, r)
	default:
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func handleReady(w http.ResponseWriter, r *http.Request) {
	if err := db.Ping(r.Context()); err != nil {
		logging.Error(r.Context(), "readiness check failed", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func handleCreateOrder(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	order, err := db.CreateOrder(ctx)
	if err != nil {
		logging.Error(ctx, "failed to create order", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to create order"})
		return
	}

	logging.Info(ctx, "order created", logging.WithOrderID(order.ID))

	// TODO: publish to NATS (will be added in worker commit)

	writeJSON(w, http.StatusCreated, map[string]string{"id": order.ID})
}

func handleGetOrder(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Extract ID from path: /orders/{id}
	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 3 || parts[2] == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "order ID required"})
		return
	}
	id := parts[2]

	order, err := db.GetOrder(ctx, id)
	if err != nil {
		logging.Error(ctx, "failed to get order", err, logging.WithOrderID(id))
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "order not found"})
		return
	}

	writeJSON(w, http.StatusOK, order)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
