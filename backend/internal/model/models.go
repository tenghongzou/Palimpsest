package model

// All lists every model managed by AutoMigrate, in dependency order.
func All() []interface{} {
	return []interface{}{
		&User{},
		&ReadingSettings{},
		&Category{},
		&Tag{},
		&Novel{},
		&Volume{},
		&Chapter{},
		&BookshelfItem{},
		&ReadingProgress{},
		&ReadingHistory{},
		&Bookmark{},
		&Review{},
		&Comment{},
		&Like{},
		&Report{},
		&Banner{},
	}
}
