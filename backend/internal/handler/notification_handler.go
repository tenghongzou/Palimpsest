package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type NotificationHandler struct {
	svc *service.NotificationService
}

func NewNotificationHandler(svc *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

func (h *NotificationHandler) List(c *gin.Context) {
	page, size := pageParams(c, 20, 50)
	items, total, err := h.svc.List(currentUser(c), c.Query("unread_only") == "true", page, size)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(items, page, size, total)))
}

func (h *NotificationHandler) UnreadCount(c *gin.Context) {
	n, err := h.svc.UnreadCount(currentUser(c))
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{"count": n}))
}

func (h *NotificationHandler) MarkRead(c *gin.Context) {
	id, ok := pathUUID(c, "notificationId")
	if !ok {
		return
	}
	if err := h.svc.MarkRead(currentUser(c), id); err != nil {
		serviceError(c, err, 40410, "notification not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *NotificationHandler) MarkAllRead(c *gin.Context) {
	n, err := h.svc.MarkAllRead(currentUser(c))
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(gin.H{"updated": n}))
}

func (h *NotificationHandler) Delete(c *gin.Context) {
	id, ok := pathUUID(c, "notificationId")
	if !ok {
		return
	}
	if err := h.svc.Delete(currentUser(c), id); err != nil {
		serviceError(c, err, 40410, "notification not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// Broadcast sends a system notification to every active user (admin only).
func (h *NotificationHandler) Broadcast(c *gin.Context) {
	var req struct {
		Title string `json:"title" binding:"required,max=200"`
		Body  string `json:"body" binding:"max=2000"`
	}
	if !bindJSON(c, &req) {
		return
	}
	n, err := h.svc.Broadcast(req.Title, req.Body)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(gin.H{"recipients": n}))
}

// ------------------------------------------------------------------ devices

func (h *NotificationHandler) ListDevices(c *gin.Context) {
	devices, err := h.svc.ListDevices(currentUser(c))
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(devices))
}

func (h *NotificationHandler) RegisterDevice(c *gin.Context) {
	var req service.DeviceInput
	if !bindJSON(c, &req) {
		return
	}
	device, err := h.svc.RegisterDevice(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40401, "")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(device))
}

func (h *NotificationHandler) RemoveDevice(c *gin.Context) {
	id, ok := pathUUID(c, "deviceId")
	if !ok {
		return
	}
	if err := h.svc.RemoveDevice(currentUser(c), id); err != nil {
		serviceError(c, err, 40411, "device not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}
