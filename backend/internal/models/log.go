package models

import "time"

type Log struct {
	ID        string    `db:"id" json:"id"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	Message   string    `db:"message" json:"message"`
}
