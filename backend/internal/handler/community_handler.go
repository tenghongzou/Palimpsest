package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tenghongzou/palimpsest/backend/internal/model"
	"github.com/tenghongzou/palimpsest/backend/internal/service"
)

type CommunityHandler struct {
	communitySvc *service.CommunityService
}

func NewCommunityHandler(communitySvc *service.CommunityService) *CommunityHandler {
	return &CommunityHandler{communitySvc: communitySvc}
}

// ------------------------------------------------------------------ reviews

func (h *CommunityHandler) ListReviews(c *gin.Context) {
	novelID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	page, size := pageParams(c, 20, 50)
	reviews, total, err := h.communitySvc.ListReviews(novelID, viewer(c), c.Query("sort_by"), page, size)
	if err != nil {
		serviceError(c, err, 40401, "novel not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(reviews, page, size, total)))
}

func (h *CommunityHandler) CreateReview(c *gin.Context) {
	novelID, ok := pathUUID(c, "id")
	if !ok {
		return
	}
	var req service.ReviewInput
	if !bindJSON(c, &req) {
		return
	}
	review, err := h.communitySvc.CreateReview(currentUser(c), novelID, req)
	if err != nil {
		serviceError(c, err, 40401, "novel not found")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(review))
}

func (h *CommunityHandler) UpdateReview(c *gin.Context) {
	id, ok := pathUUID(c, "reviewId")
	if !ok {
		return
	}
	var req service.ReviewInput
	if !bindJSON(c, &req) {
		return
	}
	review, err := h.communitySvc.UpdateReview(currentUser(c), id, req)
	if err != nil {
		serviceError(c, err, 40404, "review not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(review))
}

func (h *CommunityHandler) DeleteReview(c *gin.Context) {
	id, ok := pathUUID(c, "reviewId")
	if !ok {
		return
	}
	if err := h.communitySvc.DeleteReview(currentUser(c), isAdmin(c), id); err != nil {
		serviceError(c, err, 40404, "review not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// ----------------------------------------------------------------- comments

// GetThread returns the comment thread containing a comment.
func (h *CommunityHandler) GetThread(c *gin.Context) {
	id, ok := pathUUID(c, "commentId")
	if !ok {
		return
	}
	thread, err := h.communitySvc.GetThread(id, viewer(c))
	if err != nil {
		serviceError(c, err, 40405, "comment not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(thread))
}

// ParagraphCounts returns how many comments each paragraph of a chapter has.
func (h *CommunityHandler) ParagraphCounts(c *gin.Context) {
	chapterID, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	counts, err := h.communitySvc.ParagraphCounts(chapterID)
	if err != nil {
		serviceError(c, err, 40402, "chapter not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(counts))
}

func (h *CommunityHandler) ListComments(c *gin.Context) {
	chapterID, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	var paragraph *int
	if raw := c.Query("paragraph_index"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 0 {
			c.JSON(http.StatusBadRequest, model.ErrorResponse(40001, "invalid paragraph_index"))
			return
		}
		paragraph = &n
	}
	page, size := pageParams(c, 20, 50)
	comments, total, err := h.communitySvc.ListComments(chapterID, viewer(c), c.Query("sort_by"), paragraph, page, size)
	if err != nil {
		serviceError(c, err, 40402, "chapter not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(paginated(comments, page, size, total)))
}

func (h *CommunityHandler) CreateComment(c *gin.Context) {
	chapterID, ok := pathUUID(c, "chapterId")
	if !ok {
		return
	}
	var req service.CommentInput
	if !bindJSON(c, &req) {
		return
	}
	comment, err := h.communitySvc.CreateComment(currentUser(c), chapterID, req)
	if err != nil {
		serviceError(c, err, 40402, "chapter or parent comment not found")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(comment))
}

func (h *CommunityHandler) DeleteComment(c *gin.Context) {
	id, ok := pathUUID(c, "commentId")
	if !ok {
		return
	}
	if err := h.communitySvc.DeleteComment(currentUser(c), isAdmin(c), id); err != nil {
		serviceError(c, err, 40405, "comment not found")
		return
	}
	c.JSON(http.StatusOK, model.SuccessResponse(nil))
}

// -------------------------------------------------------------------- likes

func (h *CommunityHandler) setLike(targetType, param string, like bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, ok := pathUUID(c, param)
		if !ok {
			return
		}
		result, err := h.communitySvc.SetLike(currentUser(c), targetType, id, like)
		if err != nil {
			serviceError(c, err, 40404, targetType+" not found")
			return
		}
		c.JSON(http.StatusOK, model.SuccessResponse(result))
	}
}

func (h *CommunityHandler) LikeReview(c *gin.Context) {
	h.setLike(model.LikeTargetReview, "reviewId", true)(c)
}

func (h *CommunityHandler) UnlikeReview(c *gin.Context) {
	h.setLike(model.LikeTargetReview, "reviewId", false)(c)
}

func (h *CommunityHandler) LikeComment(c *gin.Context) {
	h.setLike(model.LikeTargetComment, "commentId", true)(c)
}

func (h *CommunityHandler) UnlikeComment(c *gin.Context) {
	h.setLike(model.LikeTargetComment, "commentId", false)(c)
}

// ------------------------------------------------------------------ reports

func (h *CommunityHandler) CreateReport(c *gin.Context) {
	var req service.ReportInput
	if !bindJSON(c, &req) {
		return
	}
	report, err := h.communitySvc.CreateReport(currentUser(c), req)
	if err != nil {
		serviceError(c, err, 40406, "reported content not found")
		return
	}
	c.JSON(http.StatusCreated, model.SuccessResponse(report))
}
