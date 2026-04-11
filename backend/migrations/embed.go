package migrations

import "embed"

//go:embed app/*.sql
var AppFS embed.FS

//go:embed logs/*.sql
var LogsFS embed.FS
