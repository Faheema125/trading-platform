package models

import "time"

// Order represents a trading order in the system.
type Order struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}
