package model

import "time"

type SearchKeyword struct {
	ID         int       `gorm:"primaryKey;autoIncrement" json:"id"`
	Keyword    string    `gorm:"size:100;uniqueIndex;not null" json:"keyword"`
	SearchCount int64    `gorm:"default:0" json:"search_count"`
	IsHot      bool      `gorm:"default:false" json:"is_hot"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}
