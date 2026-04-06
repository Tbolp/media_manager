package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"media-manager/internal/config"
	"media-manager/internal/core"
	"media-manager/internal/database"
	"media-manager/internal/handlers"
	"media-manager/internal/middleware"
	"media-manager/internal/queue"
	"media-manager/internal/services"
)

func main() {
	config.Load()

	// Check system dependencies (ffprobe)
	core.CheckDependencies()

	// Initialize databases
	if err := database.Init(config.C.DataDir); err != nil {
		log.Fatalf("Failed to init database: %v", err)
	}
	defer database.Close()

	// Run migrations
	if err := database.Migrate(database.AppDB.DB, "migrations/app"); err != nil {
		log.Fatalf("Failed to migrate app.db: %v", err)
	}
	if err := database.Migrate(database.LogsDB.DB, "migrations/logs"); err != nil {
		log.Fatalf("Failed to migrate logs.db: %v", err)
	}

	// Initialize queue manager
	qm := queue.NewQueueManager(services.RunRefresh, services.WriteLog)
	handlers.SetQueueManager(qm)

	// Start queues for all non-deleted libraries
	libs, err := services.ListLibraries()
	if err != nil {
		log.Fatalf("Failed to list libraries: %v", err)
	}
	for _, lib := range libs {
		qm.StartQueue(lib.ID)
	}

	// Set up Gin router
	gin.SetMode(config.C.GinMode)
	r := gin.Default()

	setupRoutes(r)
	setupFrontend(r)

	// Create HTTP server
	srv := &http.Server{
		Addr:    config.C.ListenAddr,
		Handler: r,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Starting server on %s", config.C.ListenAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// Graceful shutdown: wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Shutdown HTTP server with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	// Shutdown queue manager (cancel all workers, wait for completion)
	qm.ShutdownAll()

	log.Println("Server exited")
}

func setupRoutes(r *gin.Engine) {
	// Health check
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// ── Public routes ──
	r.GET("/api/init/status", handlers.HandleInitStatus)
	r.POST("/api/init", handlers.HandleInit)
	r.POST("/api/login", handlers.HandleLogin)

	// ── Authenticated routes ──
	auth := r.Group("", middleware.AuthMiddleware())
	{
		auth.POST("/api/logout", handlers.HandleLogout)
		auth.GET("/api/libraries", handlers.HandleListLibraries)
		auth.GET("/api/behavior/history", handlers.HandleGetHistory)
	}

	// ── Admin routes ──
	admin := r.Group("", middleware.AuthMiddleware(), middleware.RequireAdmin())
	{
		// User management
		admin.GET("/api/users", handlers.HandleListUsers)
		admin.POST("/api/users", handlers.HandleCreateUser)
		admin.PATCH("/api/users/:id/disable", handlers.HandleDisableUser)
		admin.PATCH("/api/users/:id/enable", handlers.HandleEnableUser)
		admin.DELETE("/api/users/:id", handlers.HandleDeleteUser)
		admin.PUT("/api/users/:id/password", handlers.HandleResetPassword)
		admin.PUT("/api/users/:id/permissions", handlers.HandleUpdatePermissions)

		// Library management (admin-only operations)
		admin.POST("/api/libraries", handlers.HandleCreateLibrary)
		admin.PATCH("/api/libraries/:id", handlers.HandleRenameLibrary)
		admin.DELETE("/api/libraries/:id", handlers.HandleDeleteLibrary)

		// System admin
		admin.GET("/api/system/dashboard", handlers.HandleDashboard)
		admin.GET("/api/system/tasks", handlers.HandleTasks)
		admin.GET("/api/system/logs", handlers.HandleLogs)
	}

	// ── Library access routes (requires whitelist or admin) ──
	libAccess := r.Group("", middleware.AuthMiddleware(), middleware.RequireLibraryAccess())
	{
		libAccess.GET("/api/libraries/:id/files", handlers.HandleListFiles)
		libAccess.POST("/api/libraries/:id/upload", handlers.HandleUpload)
		libAccess.POST("/api/libraries/:id/refresh", handlers.HandleRefresh)
	}

	// ── File access routes (requires library whitelist via file lookup) ──
	fileAccess := r.Group("", middleware.AuthMiddleware(), middleware.RequireLibraryAccess())
	{
		fileAccess.GET("/api/files/:fid/stream", handlers.HandleStream)
		fileAccess.GET("/api/files/:fid/raw", handlers.HandleRawImage)
		fileAccess.GET("/api/files/:fid/thumbnail", handlers.HandleThumbnail)
		fileAccess.GET("/api/files/:fid/progress", handlers.HandleGetProgress)
		fileAccess.PUT("/api/files/:fid/progress", handlers.HandleReportProgress)
	}
}
