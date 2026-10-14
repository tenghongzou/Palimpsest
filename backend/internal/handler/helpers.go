package handler

import (
	"errors"
	"log"
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

// currentUser returns the authenticated user's id; Auth must run first.
func currentUser(c *gin.Context) uuid.UUID {
	return c.MustGet("userID").(uuid.UUID)
}

// viewer returns the user's id when the request is authenticated
// (Auth or OptionalAuth), or nil for anonymous requests.
func viewer(c *gin.Context) *uuid.UUID {
	if v, ok := c.Get("userID"); ok {
		id := v.(uuid.UUID)
		return &id
	}
	return nil
}

func isAdmin(c *gin.Context) bool {
	role, _ := c.Get("userRole")
	return role == "admin"
}

// pathUUID parses a uuid path parameter, answering 400 when it is malformed.
func pathUUID(c *gin.Context, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid "+name))
		return uuid.Nil, false
	}
	return id, true
}

// bindJSON binds the request body, answering 400 on failure.
func bindJSON(c *gin.Context, dst interface{}) bool {
	if err := c.ShouldBindJSON(dst); err != nil {
		c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, err.Error()))
		return false
	}
	return true
}

// pageParams reads page and page_size, clamping them to sane values.
func pageParams(c *gin.Context, defaultSize, maxSize int) (int, int) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("page_size", strconv.Itoa(defaultSize)))
	if page < 1 {
		page = 1
	}
	if size < 1 || size > maxSize {
		size = defaultSize
	}
	return page, size
}

func paginated(items interface{}, page, pageSize int, total int64) model.PaginatedResponse {
	return model.PaginatedResponse{
		Items: items,
		Pagination: model.Pagination{
			Page: page, PageSize: pageSize, Total: int(total),
			TotalPages: int(math.Ceil(float64(total) / float64(pageSize))),
		},
	}
}

// serviceError answers with the response matching a service error. notFound
// is the 404xx code and message for the resource involved.
func serviceError(c *gin.Context, err error, notFoundCode int, notFoundMsg string) {
	switch {
	case errors.Is(err, service.ErrNotFound):
		c.JSON(http.StatusNotFound, model.ErrorResponse(notFoundCode, notFoundMsg))
	case errors.Is(err, service.ErrForbidden):
		c.JSON(http.StatusForbidden, model.ErrorResponse(40302, "not allowed to modify this resource"))
	case errors.Is(err, service.ErrConflict):
		c.JSON(http.StatusConflict, model.ErrorResponse(40903, "conflicts with existing data"))
	default:
		log.Printf("%s %s: %v", c.Request.Method, c.FullPath(), err)
		c.JSON(http.StatusInternalServerError, model.ErrorResponse(50001, "internal server error"))
	}
}
