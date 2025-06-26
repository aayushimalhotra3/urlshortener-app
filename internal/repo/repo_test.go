package repo

import (
	"database/sql"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	_ "github.com/mattn/go-sqlite3"
	"github.com/urlshortener/internal/metrics"
)

func setupTestRepo(t *testing.T) *SQLiteRepository {
	db, err := sql.Open("sqlite3", ":memory:")
	assert.NoError(t, err)

	// Create the urls table
	createTableSQL := `CREATE TABLE IF NOT EXISTS urls (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		original_url TEXT NOT NULL,
		code TEXT NOT NULL UNIQUE,
		created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
		clicks INTEGER NOT NULL DEFAULT 0,
		last_clicked_at TIMESTAMP
	);`
	_, err = db.Exec(createTableSQL)
	assert.NoError(t, err)

	repo := &SQLiteRepository{
		db:      db,
		metrics: metrics.NewMetrics(),
	}
	return repo
}

func TestStoreURL(t *testing.T) {
	repo := setupTestRepo(t)
	defer repo.Close()

	t.Run("successful store", func(t *testing.T) {
		err := repo.StoreURL("http://example.com", "abc123")
		assert.NoError(t, err)

		// Verify the URL was stored by retrieving it
		url, err := repo.GetOriginalURL("abc123")
		assert.NoError(t, err)
		assert.Equal(t, "http://example.com", url)
	})

	t.Run("duplicate code error", func(t *testing.T) {
		// First store should succeed
		err := repo.StoreURL("http://example1.com", "duplicate")
		assert.NoError(t, err)

		// Second store with same code should fail
		err = repo.StoreURL("http://example2.com", "duplicate")
		assert.Error(t, err)
	})
}

func TestGetOriginalURL(t *testing.T) {
	repo := setupTestRepo(t)
	defer repo.Close()

	t.Run("successful retrieval", func(t *testing.T) {
		// Store test data first
		err := repo.StoreURL("http://example.com", "test123")
		require.NoError(t, err)

		url, err := repo.GetOriginalURL("test123")
		assert.NoError(t, err)
		assert.Equal(t, "http://example.com", url)
	})

	t.Run("URL not found", func(t *testing.T) {
		url, err := repo.GetOriginalURL("notfound")
		assert.Error(t, err)
		assert.Empty(t, url)
	})
}

// Note: IncrementClickCount is not part of the current URLRepository interface

// Note: CodeExists is not part of the current URLRepository interface



// Integration test that combines multiple operations
func TestSQLiteRepositoryIntegration(t *testing.T) {
	repo := setupTestRepo(t)
	defer repo.Close()

	// Test the full workflow
	code := "integration123"
	originalURL := "http://integration-test.com"

	// 1. Store URL
	err := repo.StoreURL(originalURL, code)
	assert.NoError(t, err)

	// 2. Retrieve URL
	retrievedURL, err := repo.GetOriginalURL(code)
	assert.NoError(t, err)
	assert.Equal(t, originalURL, retrievedURL)

	// 3. Try to store duplicate code (should fail)
	err = repo.StoreURL("http://another-url.com", code)
	assert.Error(t, err)

	// 4. Verify original URL is still there
	retrievedURL, err = repo.GetOriginalURL(code)
	assert.NoError(t, err)
	assert.Equal(t, originalURL, retrievedURL)
}