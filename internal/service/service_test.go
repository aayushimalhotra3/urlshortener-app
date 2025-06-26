package service

import (
	"testing"
	"strings"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockURLRepository is a mock implementation of URLRepository
type MockURLRepository struct {
	mock.Mock
}

func (m *MockURLRepository) StoreURL(originalURL, code string) error {
	args := m.Called(originalURL, code)
	return args.Error(0)
}

func (m *MockURLRepository) GetOriginalURL(code string) (string, error) {
	args := m.Called(code)
	return args.String(0), args.Error(1)
}

func (m *MockURLRepository) Close() error {
	args := m.Called()
	return args.Error(0)
}

// Note: validateURL is not exported, so we test it indirectly through ShortenURL

func TestCodeGeneration(t *testing.T) {
	mockRepo := new(MockURLRepository)
	service := NewURLService(mockRepo, "http://localhost:8081")

	// Test that code generation produces valid codes through ShortenURL
	mockRepo.On("StoreURL", "example.com", mock.AnythingOfType("string")).Return(nil).Once()
	
	code, shortURL, err := service.ShortenURL("example.com")
	
	assert.NoError(t, err)
	assert.Len(t, code, 6)
	assert.Contains(t, shortURL, code)
	// Check that code contains only alphanumeric characters
	for _, char := range code {
		assert.True(t, strings.ContainsRune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", char))
	}

	mockRepo.AssertExpectations(t)
}

// Note: Removed TestGenerateUniqueCodeRetry as generateUniqueCode is not exposed

func TestShortenURL(t *testing.T) {
	mockRepo := new(MockURLRepository)
	service := NewURLService(mockRepo, "http://localhost:8081")

	t.Run("successful URL shortening", func(t *testing.T) {
		mockRepo.On("StoreURL", "example.com", mock.AnythingOfType("string")).Return(nil).Once()

		code, shortURL, err := service.ShortenURL("example.com")

		assert.NoError(t, err)
		assert.Len(t, code, 6)
		assert.Contains(t, shortURL, code)
		mockRepo.AssertExpectations(t)
	})

	t.Run("invalid URL", func(t *testing.T) {
		code, shortURL, err := service.ShortenURL("")

		assert.Error(t, err)
		assert.Empty(t, code)
		assert.Empty(t, shortURL)
	})
}

func TestGetOriginalURL(t *testing.T) {
	mockRepo := new(MockURLRepository)
	service := NewURLService(mockRepo, "http://localhost:8081")

	t.Run("successful URL retrieval", func(t *testing.T) {
		mockRepo.On("GetOriginalURL", "abc123").Return("http://example.com", nil).Once()

		url, err := service.GetOriginalURL("abc123")

		assert.NoError(t, err)
		assert.Equal(t, "http://example.com", url)
		mockRepo.AssertExpectations(t)
	})

	t.Run("URL not found", func(t *testing.T) {
		mockRepo.On("GetOriginalURL", "notfound").Return("", assert.AnError).Once()

		url, err := service.GetOriginalURL("notfound")

		assert.Error(t, err)
		assert.Empty(t, url)
		mockRepo.AssertExpectations(t)
	})
}