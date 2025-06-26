package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/urlshortener/internal/metrics"
)

// MockURLService is a mock implementation of URLService
type MockURLService struct {
	mock.Mock
}

func (m *MockURLService) ShortenURL(originalURL string) (string, string, error) {
	args := m.Called(originalURL)
	return args.String(0), args.String(1), args.Error(2)
}

func (m *MockURLService) GetOriginalURL(code string) (string, error) {
	args := m.Called(code)
	return args.String(0), args.Error(1)
}

func TestShortenURL(t *testing.T) {
	mockService := new(MockURLService)
	handler := NewURLHandler(mockService, metrics.NewMetrics())

	t.Run("successful URL shortening", func(t *testing.T) {
		mockService.On("ShortenURL", "http://example.com").Return("abc123", "http://localhost:8081/abc123", nil).Once()

		reqBody := ShortenURLRequest{URL: "http://example.com"}
		jsonBody, _ := json.Marshal(reqBody)

		req := httptest.NewRequest("POST", "/shorten", bytes.NewBuffer(jsonBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		handler.ShortenURL(w, req)

		assert.Equal(t, http.StatusOK, w.Code)

		var response ShortenURLResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "abc123", response.Code)
		assert.Contains(t, response.ShortURL, "abc123")

		mockService.AssertExpectations(t)
	})

	t.Run("invalid JSON request", func(t *testing.T) {
		req := httptest.NewRequest("POST", "/shorten", bytes.NewBufferString("invalid json"))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		handler.ShortenURL(w, req)

		assert.Equal(t, http.StatusBadRequest, w.Code)

		var response ErrorResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "Invalid request body", response.Error)
	})

	t.Run("empty URL", func(t *testing.T) {
		reqBody := ShortenURLRequest{URL: ""}
		jsonBody, _ := json.Marshal(reqBody)

		req := httptest.NewRequest("POST", "/shorten", bytes.NewBuffer(jsonBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()

		handler.ShortenURL(w, req)

		assert.Equal(t, http.StatusBadRequest, w.Code)

		var response ErrorResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "URL is required", response.Error)
	})

	t.Run("service error", func(t *testing.T) {
		mockService.On("ShortenURL", "example.com").Return("", "", errors.New("service error")).Once()

		req, _ := http.NewRequest("POST", "/shorten", strings.NewReader(`{"url":"example.com"}`))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()

		handler.ShortenURL(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
		var response map[string]string
		json.Unmarshal(rr.Body.Bytes(), &response)
		assert.Equal(t, "service error", response["error"])

		mockService.AssertExpectations(t)
	})
}

func TestRedirectURL(t *testing.T) {
	mockService := new(MockURLService)
	handler := NewURLHandler(mockService, metrics.NewMetrics())

	t.Run("successful redirect", func(t *testing.T) {
		mockService.On("GetOriginalURL", "abc123").Return("http://example.com", nil).Once()

		req := httptest.NewRequest("GET", "/abc123", nil)
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("code", "abc123")
		req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
		w := httptest.NewRecorder()

		handler.RedirectURL(w, req)

		assert.Equal(t, http.StatusMovedPermanently, w.Code)
		assert.Equal(t, "http://example.com", w.Header().Get("Location"))

		mockService.AssertExpectations(t)
	})

	t.Run("URL not found", func(t *testing.T) {
		mockService.On("GetOriginalURL", "notfound").Return("", errors.New("not found")).Once()

		req := httptest.NewRequest("GET", "/notfound", nil)
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("code", "notfound")
		req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
		w := httptest.NewRecorder()

		handler.RedirectURL(w, req)

		assert.Equal(t, http.StatusNotFound, w.Code)

		var response ErrorResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "URL not found", response.Error)

		mockService.AssertExpectations(t)
	})

	t.Run("empty code", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/", nil)
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("code", "")
		req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
		w := httptest.NewRecorder()

		handler.RedirectURL(w, req)

		assert.Equal(t, http.StatusBadRequest, w.Code)

		var response ErrorResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "Code is required", response.Error)
	})
}

func TestRespondWithJSON(t *testing.T) {
	t.Run("successful JSON response", func(t *testing.T) {
		w := httptest.NewRecorder()
		data := map[string]string{"message": "success"}

		respondWithJSON(w, http.StatusOK, data)

		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

		var response map[string]string
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "success", response["message"])
	})
}

func TestRespondWithError(t *testing.T) {
	t.Run("error response", func(t *testing.T) {
		w := httptest.NewRecorder()

		respondWithError(w, http.StatusBadRequest, "Bad request")

		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

		var response ErrorResponse
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(t, err)
		assert.Equal(t, "Bad request", response.Error)
	})
}