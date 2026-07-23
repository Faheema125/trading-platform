package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/Faheema125/trading-platform/internal/logging"
	"github.com/nats-io/nats.go"
)

const (
	SubjectOrders = "orders.new"
	StreamName    = "ORDERS"
)

// OrderMessage is the payload sent through NATS.
type OrderMessage struct {
	OrderID   string `json:"order_id"`
	RequestID string `json:"request_id"`
}

// Client wraps a NATS JetStream connection.
type Client struct {
	conn *nats.Conn
	js   nats.JetStreamContext
}

// New connects to NATS and sets up JetStream.
func New(ctx context.Context) (*Client, error) {
	url := os.Getenv("NATS_URL")
	if url == "" {
		url = nats.DefaultURL
	}

	var conn *nats.Conn
	var err error

	// Retry connection with backoff
	for i := 0; i < 5; i++ {
		conn, err = nats.Connect(url)
		if err == nil {
			break
		}
		logging.Info(ctx, fmt.Sprintf("nats connection attempt %d failed, retrying...", i+1))
		time.Sleep(time.Duration(i+1) * time.Second)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	js, err := conn.JetStream()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to get JetStream context: %w", err)
	}

	// Create stream if it doesn't exist
	_, err = js.StreamInfo(StreamName)
	if err != nil {
		_, err = js.AddStream(&nats.StreamConfig{
			Name:     StreamName,
			Subjects: []string{SubjectOrders},
			Storage:  nats.FileStorage,
		})
		if err != nil {
			conn.Close()
			return nil, fmt.Errorf("failed to create stream: %w", err)
		}
	}

	return &Client{conn: conn, js: js}, nil
}

// Publish sends an order message to the NATS stream.
func (c *Client) Publish(ctx context.Context, msg *OrderMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	_, err = c.js.Publish(SubjectOrders, data)
	if err != nil {
		return fmt.Errorf("failed to publish message: %w", err)
	}

	logging.Info(ctx, "message published to NATS", logging.WithOrderID(msg.OrderID))
	return nil
}

// Subscribe creates a durable pull subscription and calls the handler for each message.
func (c *Client) Subscribe(ctx context.Context, handler func(ctx context.Context, msg *OrderMessage) error) error {
	sub, err := c.js.PullSubscribe(SubjectOrders, "worker", nats.AckWait(30*time.Second))
	if err != nil {
		return fmt.Errorf("failed to subscribe: %w", err)
	}

	logging.Info(ctx, "subscribed to NATS subject: "+SubjectOrders)

	for {
		select {
		case <-ctx.Done():
			return nil
		default:
			msgs, err := sub.Fetch(1, nats.MaxWait(5*time.Second))
			if err != nil {
				// Timeout is normal when no messages are available
				continue
			}

			for _, m := range msgs {
				var orderMsg OrderMessage
				if err := json.Unmarshal(m.Data, &orderMsg); err != nil {
					logging.Error(ctx, "failed to unmarshal message", err)
					m.Nak()
					continue
				}

				// Propagate request ID into context
				msgCtx := logging.WithRequestID(ctx, orderMsg.RequestID)

				if err := handler(msgCtx, &orderMsg); err != nil {
					logging.Error(msgCtx, "failed to process message", err, logging.WithOrderID(orderMsg.OrderID))
					m.Nak()
					continue
				}

				m.Ack()
			}
		}
	}
}

// Close closes the NATS connection.
func (c *Client) Close() {
	c.conn.Close()
}
