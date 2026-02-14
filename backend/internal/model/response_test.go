package model

import "testing"

func TestSuccessResponse(t *testing.T) {
	resp := SuccessResponse("hello")
	if resp.Code != 0 {
		t.Errorf("expected code 0, got %d", resp.Code)
	}
	if resp.Message != "success" {
		t.Errorf("expected message 'success', got %s", resp.Message)
	}
	if resp.Data != "hello" {
		t.Errorf("expected data 'hello', got %v", resp.Data)
	}
}

func TestErrorResponse(t *testing.T) {
	resp := ErrorResponse(50001, "server error")
	if resp.Code != 50001 {
		t.Errorf("expected code 50001, got %d", resp.Code)
	}
	if resp.Message != "server error" {
		t.Errorf("expected message 'server error', got %s", resp.Message)
	}
}

func TestValidationErrorResponse(t *testing.T) {
	errors := []FieldError{
		{Field: "email", Message: "required"},
	}
	resp := ValidationErrorResponse(errors)
	if resp.Code != 40001 {
		t.Errorf("expected code 40001, got %d", resp.Code)
	}
	if len(resp.Errors) != 1 {
		t.Fatalf("expected 1 error, got %d", len(resp.Errors))
	}
	if resp.Errors[0].Field != "email" {
		t.Errorf("expected field 'email', got %s", resp.Errors[0].Field)
	}
}
