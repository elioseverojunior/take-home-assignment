package models

import (
	"database/sql/driver"
	"encoding/json"
)

type Tags []*string

// Value implements driver.Valuer interface.
func (s Tags) Value() (driver.Value, error) {
	return json.Marshal(s)
}

// Scan implements sql.Scanner interface.
func (s *Tags) Scan(src interface{}) error {
	var data []byte
	switch v := src.(type) {
	case string:
		data = []byte(v)
	case []byte:
		data = v
	default:
		return nil
	}
	return json.Unmarshal(data, s)
}
