document.addEventListener('DOMContentLoaded', function() {
    const urlForm = document.getElementById('url-form');
    const urlInput = document.getElementById('url-input');
    const shortenBtn = document.getElementById('shorten-btn');
    const resultContainer = document.getElementById('result-container');
    const shortUrlInput = document.getElementById('short-url');
    const copyBtn = document.getElementById('copy-btn');
    const errorContainer = document.getElementById('error-container');
    const errorMessage = document.getElementById('error-message');
    const historyList = document.getElementById('history-list');
    const historyContainer = document.getElementById('history-container');
    const loadingOverlay = document.getElementById('loading-overlay');
    const toastContainer = document.getElementById('toast-container');
    const analyticsContainer = document.getElementById('analytics-container');
    const totalUrlsElement = document.getElementById('total-urls');
    const sessionUrlsElement = document.getElementById('session-urls');
    const successRateElement = document.getElementById('success-rate');
    
    // Analytics tracking
    let sessionStats = {
        totalAttempts: 0,
        successfulAttempts: 0,
        sessionUrls: 0
    };

    // Load history from localStorage
    loadHistory();
    
    // Initialize analytics
    updateAnalytics();
    
    // Analytics functions
    function updateAnalytics() {
        const history = JSON.parse(localStorage.getItem('urlHistory') || '[]');
        const totalUrls = history.length;
        
        // Update display
        totalUrlsElement.textContent = totalUrls;
        sessionUrlsElement.textContent = sessionStats.sessionUrls;
        
        const successRate = sessionStats.totalAttempts > 0 
            ? Math.round((sessionStats.successfulAttempts / sessionStats.totalAttempts) * 100)
            : 100;
        successRateElement.textContent = successRate + '%';
        
        // Show analytics if there's data
        if (totalUrls > 0 || sessionStats.sessionUrls > 0) {
            analyticsContainer.style.display = 'block';
        }
    }
    
    function trackUrlShortening(success = true) {
        sessionStats.totalAttempts++;
        if (success) {
            sessionStats.successfulAttempts++;
            sessionStats.sessionUrls++;
        }
        updateAnalytics();
    }

    // Toast notification function
    function showToast(message, type = 'success') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        toastContainer.appendChild(toast);
        
        // Trigger animation
        setTimeout(() => toast.classList.add('show'), 100);
        
        // Remove toast after 3 seconds
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
            }, 300);
        }, 3000);
    }

    // Loading state functions
    function showLoading() {
        loadingOverlay.style.display = 'flex';
        shortenBtn.disabled = true;
        shortenBtn.classList.add('loading');
    }

    function hideLoading() {
        loadingOverlay.style.display = 'none';
        shortenBtn.disabled = false;
        shortenBtn.classList.remove('loading');
    }

    // Enhanced URL validation
    function isValidUrl(string) {
        try {
            const url = new URL(string);
            return url.protocol === 'http:' || url.protocol === 'https:';
        } catch (_) {
            return false;
        }
    }

    // Handle form submission
    urlForm.addEventListener('submit', async function(e) {
        e.preventDefault();
        
        // Hide previous results and errors
        resultContainer.style.display = 'none';
        errorContainer.style.display = 'none';
        
        const url = urlInput.value.trim();
        
        // Enhanced validation
        if (!url) {
            showError('Please enter a URL');
            showToast('URL is required', 'error');
            trackUrlShortening(false);
            return;
        }
        
        if (!isValidUrl(url)) {
            showError('Please enter a valid URL (must start with http:// or https://)');
            showToast('Invalid URL format', 'error');
            trackUrlShortening(false);
            return;
        }
        
        // Show loading state
        showLoading();
        
        try {
            const response = await fetch('/shorten', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ url: url })
            });
            
            if (!response.ok) {
                // Try to parse JSON error response
                try {
                    const errorData = await response.json();
                    const errorMsg = errorData.error || 'Failed to shorten URL';
                    showError(errorMsg);
                    showToast(errorMsg, 'error');
                    trackUrlShortening(false);
                } catch {
                    // If JSON parsing fails, show generic error
                    const errorMsg = 'Failed to shorten URL';
                    showError(errorMsg);
                    showToast(errorMsg, 'error');
                    trackUrlShortening(false);
                }
                return;
            }
            
            const data = await response.json();
            
            // Show result
            shortUrlInput.value = data.short_url;
            resultContainer.style.display = 'block';
            
            // Add to history
            addToHistory({
                original: url,
                shortened: data.short_url
            });
            
            // Track successful shortening
            trackUrlShortening(true);
            
            // Show success message
            showToast('URL shortened successfully! 🎉');
            
            // Clear input
            urlInput.value = '';
            
        } catch (error) {
            const errorMsg = 'Network error. Please check your connection and try again.';
            showError(errorMsg);
            showToast(errorMsg, 'error');
            trackUrlShortening(false);
            console.error('Error:', error);
        } finally {
            // Always hide loading state
            hideLoading();
        }
    });
    
    // Handle copy button with modern clipboard API
    copyBtn.addEventListener('click', async function() {
        try {
            await navigator.clipboard.writeText(shortUrlInput.value);
            
            // Show feedback
            const originalText = copyBtn.textContent;
            copyBtn.textContent = 'Copied!';
            copyBtn.style.backgroundColor = '#27ae60';
            
            // Show toast notification
            showToast('URL copied to clipboard! 📋');
            
            setTimeout(() => {
                copyBtn.textContent = originalText;
                copyBtn.style.backgroundColor = '';
            }, 2000);
        } catch (err) {
            // Fallback for older browsers
            try {
                shortUrlInput.select();
                document.execCommand('copy');
                
                const originalText = copyBtn.textContent;
                copyBtn.textContent = 'Copied!';
                copyBtn.style.backgroundColor = '#27ae60';
                
                showToast('URL copied to clipboard! 📋');
                
                setTimeout(() => {
                    copyBtn.textContent = originalText;
                    copyBtn.style.backgroundColor = '';
                }, 2000);
            } catch (fallbackErr) {
                showToast('Failed to copy URL. Please copy manually.', 'error');
                console.error('Copy failed:', fallbackErr);
            }
        }
    });
    
    // Function to show error
    function showError(message) {
        errorMessage.textContent = message;
        errorContainer.style.display = 'block';
    }
    
    // Function to add URL to history
    function addToHistory(item) {
        // Get existing history
        let history = JSON.parse(localStorage.getItem('urlHistory') || '[]');
        
        // Add new item at the beginning
        history.unshift(item);
        
        // Keep only the last 5 items
        history = history.slice(0, 5);
        
        // Save to localStorage
        localStorage.setItem('urlHistory', JSON.stringify(history));
        
        // Update UI
        loadHistory();
    }
    
    // Function to load history from localStorage
    function loadHistory() {
        const history = JSON.parse(localStorage.getItem('urlHistory') || '[]');
        
        // Clear list
        historyList.innerHTML = '';
        
        // Show/hide container based on history
        if (history.length === 0) {
            historyContainer.style.display = 'none';
            return;
        }
        
        historyContainer.style.display = 'block';
        
        // Add items to list
        history.forEach(item => {
            const li = document.createElement('li');
            
            const urlSpan = document.createElement('span');
            urlSpan.className = 'history-item-url';
            urlSpan.textContent = item.shortened;
            
            const copyButton = document.createElement('button');
            copyButton.className = 'history-item-copy';
            copyButton.textContent = 'Copy';
            copyButton.addEventListener('click', async function() {
                try {
                    await navigator.clipboard.writeText(item.shortened);
                    
                    // Show feedback
                    copyButton.textContent = 'Copied!';
                    copyButton.style.backgroundColor = '#27ae60';
                    
                    // Show toast notification
                    showToast('URL copied to clipboard! 📋');
                    
                    setTimeout(() => {
                        copyButton.textContent = 'Copy';
                        copyButton.style.backgroundColor = '';
                    }, 2000);
                } catch (err) {
                    // Fallback for older browsers
                    try {
                        // Create temporary input to select and copy
                        const tempInput = document.createElement('input');
                        tempInput.value = item.shortened;
                        document.body.appendChild(tempInput);
                        tempInput.select();
                        document.execCommand('copy');
                        document.body.removeChild(tempInput);
                        
                        copyButton.textContent = 'Copied!';
                        copyButton.style.backgroundColor = '#27ae60';
                        
                        showToast('URL copied to clipboard! 📋');
                        
                        setTimeout(() => {
                            copyButton.textContent = 'Copy';
                            copyButton.style.backgroundColor = '';
                        }, 2000);
                    } catch (fallbackErr) {
                        showToast('Failed to copy URL. Please copy manually.', 'error');
                        console.error('Copy failed:', fallbackErr);
                    }
                }
            });
            
            li.appendChild(urlSpan);
            li.appendChild(copyButton);
            historyList.appendChild(li);
        });
    }
});