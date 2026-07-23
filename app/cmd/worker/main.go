package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Faheema125/trading-platform/internal/database"
	"github.com/Faheema125/trading-platform/internal/logging"
	"github.com/Faheema125/trading-platform/internal/queue"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize database
	db, err := database.New(ctx)
	if err != nil {
		logging.Error(ctx, "failed to connect to database", err)
		os.Exit(1)
	}
	defer db.Close()
	logging.Info(ctx, "worker database connected")

	// Initialize NATS
	natsClient, err := queue.New(ctx)
	if err != nil {
		logging.Error(ctx, "failed to connect to NATS", err)
		os.Exit(1)
	}
	defer natsClient.Close()
	logging.Info(ctx, "worker connected to NATS")

	// Handle shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		logging.Info(ctx, "worker shutting down")
		cancel()
	}()

	// Process messages
	err = natsClient.Subscribe(ctx, func(msgCtx context.Context, msg *queue.OrderMessage) error {
		logging.Info(msgCtx, "processing order", logging.WithOrderID(msg.OrderID))

		// Simulate processing delay
		time.Sleep(2 * time.Second)

		// Update order status to filled
		if err := db.UpdateOrderStatus(msgCtx, msg.OrderID, "filled"); err != nil {
			return err
		}

		logging.Info(msgCtx, "order filled", logging.WithOrderID(msg.OrderID))
		return nil
	})

	if err != nil {
		logging.Error(ctx, "subscription error", err)
		os.Exit(1)
	}
}
