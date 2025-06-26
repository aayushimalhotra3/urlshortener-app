document.addEventListener('DOMContentLoaded', function() {
    const urlForm = document.getElementById('url-form');
    const urlInput = document.getElementById('url-input');
    const resultContainer = document.getElementById('result-container');
    const shortUrlInput = document.getElementById('short-url');
    const copyBtn = document.getElementById('copy-btn');
    const errorContainer = document.getElementById('error-container');
    const errorMessage = document.getElementById('error-message');
    const historyList = document.getElementById('history-list');
    const historyContainer = document.getElementById('history-container');

    // Load history from localStorage
    loadHistory();

    // Handle form submission
    urlForm.addEventListener('submit', async function(e) {
        e.preventDefault();
        
        // Hide previous results and errors
        resultContainer.style.display = 'none';
        errorContainer.style.display = 'none';
        
        const url = urlInput.value.trim();
        if (!url) {
            showError('Please enter a URL');
            return;
        }
        
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
                    showError(errorData.error || 'Failed to shorten URL');
                } catch {
                    // If JSON parsing fails, show generic error
                    showError('Failed to shorten URL');
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
            
        } catch (error) {
            showError('Network error. Please try again.');
            console.error('Error:', error);
        }
    });
    
    // Handle copy button
    copyBtn.addEventListener('click', function() {
        shortUrlInput.select();
        document.execCommand('copy');
        
        // Show feedback
        const originalText = copyBtn.textContent;
        copyBtn.textContent = 'Copied!';
        setTimeout(() => {
            copyBtn.textContent = originalText;
        }, 2000);
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
            copyButton.addEventListener('click', function() {
                navigator.clipboard.writeText(item.shortened)
                    .then(() => {
                        const originalText = copyButton.textContent;
                        copyButton.textContent = 'Copied!';
                        setTimeout(() => {
                            copyButton.textContent = originalText;
                        }, 2000);
                    })
                    .catch(err => {
                        console.error('Failed to copy: ', err);
                    });
            });
            
            li.appendChild(urlSpan);
            li.appendChild(copyButton);
            historyList.appendChild(li);
        });
    }
});