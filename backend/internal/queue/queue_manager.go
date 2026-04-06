package queue

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

const (
	channelCapacity  = 64
	maxRecentTasks   = 20
)

// RefreshTask represents a task to be processed by a worker.
type RefreshTask struct {
	TaskType   string // "full" | "targeted"
	TargetFile string // relative_path for targeted refresh
}

// TaskStatus tracks the status of a task.
type TaskStatus struct {
	TaskType   string    `json:"task_type"`
	TargetFile string    `json:"target_file,omitempty"`
	Status     string    `json:"status"` // "running" | "success" | "failed"
	StartedAt  time.Time `json:"started_at"`
	FinishedAt time.Time `json:"finished_at,omitempty"`
	Error      string    `json:"error,omitempty"`
}

// RefreshFunc is the function signature for index refresh operations.
// It is called by the worker to perform the actual indexing.
type RefreshFunc func(ctx context.Context, libraryID string, task RefreshTask) error

// LibraryQueue manages a per-library refresh queue.
type LibraryQueue struct {
	ch             chan RefreshTask
	cancel         context.CancelFunc
	mu             sync.Mutex
	hasPendingFull bool
	currentTask    *TaskStatus
	recentTasks    []TaskStatus
	libraryID      string
}

// QueueManager manages all library queues.
type QueueManager struct {
	queues      sync.Map // key: libraryID (string) → *LibraryQueue
	wg          sync.WaitGroup
	refreshFunc RefreshFunc
	logFunc     func(string) // function to write log entries
}

// NewQueueManager creates a new QueueManager.
func NewQueueManager(refreshFunc RefreshFunc, logFunc func(string)) *QueueManager {
	return &QueueManager{
		refreshFunc: refreshFunc,
		logFunc:     logFunc,
	}
}

// StartQueue creates and starts a queue for a library.
func (qm *QueueManager) StartQueue(libraryID string) {
	ctx, cancel := context.WithCancel(context.Background())
	lq := &LibraryQueue{
		ch:        make(chan RefreshTask, channelCapacity),
		cancel:    cancel,
		libraryID: libraryID,
	}
	qm.queues.Store(libraryID, lq)

	qm.wg.Add(1)
	go func() {
		defer qm.wg.Done()
		qm.runWorker(ctx, lq)
	}()
}

// StopQueue cancels a library's queue (used when deleting a library).
func (qm *QueueManager) StopQueue(libraryID string) {
	if v, ok := qm.queues.Load(libraryID); ok {
		lq := v.(*LibraryQueue)
		lq.cancel()
		qm.queues.Delete(libraryID)
	}
}

// ShutdownAll cancels all queues and waits for workers to finish.
func (qm *QueueManager) ShutdownAll() {
	qm.queues.Range(func(key, value any) bool {
		lq := value.(*LibraryQueue)
		lq.cancel()
		return true
	})
	qm.wg.Wait()
}

// EnqueueFull enqueues a full refresh task. Returns false if a full refresh is already pending/running.
func (qm *QueueManager) EnqueueFull(libraryID string) bool {
	v, ok := qm.queues.Load(libraryID)
	if !ok {
		return false
	}
	lq := v.(*LibraryQueue)

	lq.mu.Lock()
	defer lq.mu.Unlock()

	if lq.hasPendingFull {
		return false
	}

	lq.ch <- RefreshTask{TaskType: "full"}
	lq.hasPendingFull = true
	return true
}

// EnqueueTargeted enqueues a targeted refresh for a specific file.
func (qm *QueueManager) EnqueueTargeted(libraryID, relativePath string) {
	v, ok := qm.queues.Load(libraryID)
	if !ok {
		return
	}
	lq := v.(*LibraryQueue)
	lq.ch <- RefreshTask{TaskType: "targeted", TargetFile: relativePath}
}

// GetStatus returns the current task and recent tasks for a library.
func (qm *QueueManager) GetStatus(libraryID string) (*TaskStatus, []TaskStatus, int) {
	v, ok := qm.queues.Load(libraryID)
	if !ok {
		return nil, nil, 0
	}
	lq := v.(*LibraryQueue)

	lq.mu.Lock()
	defer lq.mu.Unlock()

	var current *TaskStatus
	if lq.currentTask != nil {
		copy := *lq.currentTask
		current = &copy
	}

	recent := make([]TaskStatus, len(lq.recentTasks))
	copy(recent, lq.recentTasks)

	pending := len(lq.ch)

	return current, recent, pending
}

// GetRefreshStatus returns a simple status string for display.
func (qm *QueueManager) GetRefreshStatus(libraryID string) string {
	v, ok := qm.queues.Load(libraryID)
	if !ok {
		return "idle"
	}
	lq := v.(*LibraryQueue)

	lq.mu.Lock()
	defer lq.mu.Unlock()

	if lq.currentTask != nil {
		return "running"
	}
	if len(lq.ch) > 0 {
		return "pending"
	}
	return "idle"
}

// runWorker processes tasks from the queue.
func (qm *QueueManager) runWorker(ctx context.Context, lq *LibraryQueue) {
	for {
		select {
		case <-ctx.Done():
			if qm.logFunc != nil {
				qm.logFunc(fmt.Sprintf("媒体库 %s 队列已停止，剩余任务取消", lq.libraryID))
			}
			return
		case task := <-lq.ch:
			// Set currentTask
			lq.mu.Lock()
			lq.currentTask = &TaskStatus{
				TaskType:   task.TaskType,
				TargetFile: task.TargetFile,
				Status:     "running",
				StartedAt:  time.Now().UTC(),
			}
			lq.mu.Unlock()

			// Execute the refresh
			err := qm.refreshFunc(ctx, lq.libraryID, task)

			// Update status
			lq.mu.Lock()
			if lq.currentTask != nil {
				lq.currentTask.FinishedAt = time.Now().UTC()
				if err != nil {
					lq.currentTask.Status = "failed"
					lq.currentTask.Error = err.Error()
				} else {
					lq.currentTask.Status = "success"
				}

				// Archive to recentTasks
				lq.recentTasks = append(lq.recentTasks, *lq.currentTask)
				if len(lq.recentTasks) > maxRecentTasks {
					lq.recentTasks = lq.recentTasks[len(lq.recentTasks)-maxRecentTasks:]
				}
				lq.currentTask = nil
			}

			if task.TaskType == "full" {
				lq.hasPendingFull = false
			}
			lq.mu.Unlock()

			// Write log
			if qm.logFunc != nil {
				if err != nil {
					qm.logFunc(fmt.Sprintf("媒体库 %s %s刷新失败：%v", lq.libraryID, taskTypeLabel(task), err))
				} else {
					qm.logFunc(fmt.Sprintf("媒体库 %s %s刷新完成", lq.libraryID, taskTypeLabel(task)))
				}
			}

			// Check if context was cancelled during execution
			if ctx.Err() != nil {
				log.Printf("Worker for library %s stopping after task completion (context cancelled)", lq.libraryID)
				return
			}
		}
	}
}

func taskTypeLabel(task RefreshTask) string {
	if task.TaskType == "full" {
		return "全量"
	}
	return fmt.Sprintf("定向(%s)", task.TargetFile)
}
