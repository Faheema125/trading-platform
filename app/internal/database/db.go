package database

import (
	"context"
	"fmt"
	"os"

	"github.com/Faheema125/trading-platform/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DB wraps the Postgres connection pool.
type DB struct {
	Pool *pgxpool.Pool
}

// New creates a new database connection pool from DATABASE_URL env var.
func New(ctx context.Context) (*DB, error) {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return nil, fmt.Errorf("DATABASE_URL environment variable is required")
	}

	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %w", err)
	}

	return &DB{Pool: pool}, nil
}

// Ping checks if the database is reachable.
func (db *DB) Ping(ctx context.Context) error {
	return db.Pool.Ping(ctx)
}

// CreateOrder inserts a new order with status 'pending' and returns it.
func (db *DB) CreateOrder(ctx context.Context) (*models.Order, error) {
	order := &models.Order{}
	err := db.Pool.QueryRow(ctx,
		`INSERT INTO orders (status) VALUES ('pending') RETURNING id, status, created_at`,
	).Scan(&order.ID, &order.Status, &order.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create order: %w", err)
	}
	return order, nil
}

// GetOrder retrieves an order by ID.
func (db *DB) GetOrder(ctx context.Context, id string) (*models.Order, error) {
	order := &models.Order{}
	err := db.Pool.QueryRow(ctx,
		`SELECT id, status, created_at FROM orders WHERE id = $1`, id,
	).Scan(&order.ID, &order.Status, &order.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to get order: %w", err)
	}
	return order, nil
}

// UpdateOrderStatus updates the status of an order.
func (db *DB) UpdateOrderStatus(ctx context.Context, id string, status string) error {
	_, err := db.Pool.Exec(ctx,
		`UPDATE orders SET status = $1 WHERE id = $2`, status, id,
	)
	if err != nil {
		return fmt.Errorf("failed to update order status: %w", err)
	}
	return nil
}

// Close closes the database connection pool.
func (db *DB) Close() {
	db.Pool.Close()
}
