package handler

import (
	"bytes"
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/pkg/storage"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

const (
	maxAvatarBytes = 2 << 20
	maxImageBytes  = 5 << 20
)

// imageTypes maps accepted upload types, sniffed from the content, to extensions.
var imageTypes = map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "image/gif": ".gif"}

type UserHandler struct {
	userSvc *service.UserService
	store   storage.Store
}

func NewUserHandler(userSvc *service.UserService, store storage.Store) *UserHandler {
	return &UserHandler{userSvc: userSvc, store: store}
}

func (h *UserHandler) Me(c *gin.Context) {
	user, err := h.userSvc.Get(currentUser(c))
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(user))
}

func (h *UserHandler) UpdateMe(c *gin.Context) {
	var req service.ProfileUpdate
	if !bindJSON(c, &req) {
		return
	}
	user, err := h.userSvc.UpdateProfile(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(user))
}

func (h *UserHandler) ChangePassword(c *gin.Context) {
	var req struct {
		CurrentPassword string `json:"current_password" binding:"required"`
		NewPassword     string `json:"new_password" binding:"required,min=8,max=72"`
	}
	if !bindJSON(c, &req) {
		return
	}
	err := h.userSvc.ChangePassword(currentUser(c), req.CurrentPassword, req.NewPassword)
	if errors.Is(err, service.ErrInvalidCredentials) {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40003, "current password is incorrect"))
		return
	}
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

func (h *UserHandler) GetReadingSettings(c *gin.Context) {
	settings, err := h.userSvc.ReadingSettings(currentUser(c))
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(settings))
}

func (h *UserHandler) PutReadingSettings(c *gin.Context) {
	var req model.ReadingSettings
	if !bindJSON(c, &req) {
		return
	}
	settings, err := h.userSvc.SaveReadingSettings(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(settings))
}

func (h *UserHandler) ReadingStats(c *gin.Context) {
	stats, err := h.userSvc.ReadingStats(currentUser(c), c.DefaultQuery("period", "daily"))
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(stats))
}

func (h *UserHandler) UploadAvatar(c *gin.Context) {
	url, ok := uploadImage(c, h.store, "avatar", "avatars", maxAvatarBytes)
	if !ok {
		return
	}
	user, err := h.userSvc.UpdateProfile(currentUser(c), service.ProfileUpdate{AvatarURL: &url})
	if err != nil {
		serviceError(c, err, 40401, "user not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(user))
}

// uploadImage stores the image in multipart field `field` under
// public/<folder>/ and returns its URL. It answers the request itself when
// the upload is rejected.
func uploadImage(c *gin.Context, store storage.Store, field, folder string, maxBytes int64) (string, bool) {
	if store == nil {
		c.JSON(http.StatusServiceUnavailable, model.ErrorResponse(50303, "file storage is not configured"))
		return "", false
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes+1<<20)
	file, header, err := c.Request.FormFile(field)
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "missing file field "+field))
		return "", false
	}
	defer file.Close()
	if header.Size > maxBytes {
		c.JSON(http.StatusRequestEntityTooLarge, model.ErrorResponse(40004, "file too large"))
		return "", false
	}
	data, err := io.ReadAll(io.LimitReader(file, maxBytes+1))
	if err != nil || int64(len(data)) > maxBytes {
		c.JSON(http.StatusRequestEntityTooLarge, model.ErrorResponse(40004, "file too large"))
		return "", false
	}
	// Trust the bytes, not the client's declared type.
	contentType := http.DetectContentType(data)
	ext, ok := imageTypes[contentType]
	if !ok {
		c.JSON(http.StatusUnsupportedMediaType, model.ErrorResponse(40005, "only JPEG, PNG, WebP and GIF images are accepted"))
		return "", false
	}
	key := storage.PublicPrefix + folder + "/" + uuid.NewString() + ext
	url, err := store.Put(c.Request.Context(), key, bytes.NewReader(data), int64(len(data)), contentType)
	if err != nil {
		serviceError(c, err, 40401, "")
		return "", false
	}
	return url, true
}
