// Configuration state
let config = {
    provider: 'ollama',
    endpoint: 'http://10.10.21.6:11434',
    apiKey: '',
    model: '',
    aiGuard: {
        enabled: false,
        apiKey: '',
        region: 'us',
        appName: 'chat-hub'
    }
};

// Chat history
let messages = [];
let scans = [];

// DOM Elements
const providerSelect = document.getElementById('provider');
const endpointInput = document.getElementById('endpoint');
const apiKeyInput = document.getElementById('apiKey');
const apiKeyGroup = document.getElementById('api-key-group');
const modelSelect = document.getElementById('model');
const modelSelectChat = document.getElementById('modelSelectChat');
const refreshModelsBtn = document.getElementById('refreshModels');
const chatMessages = document.getElementById('chatMessages');
const chatInput = document.getElementById('chatInput');
const sendButton = document.getElementById('sendButton');
const chatStatusDiv = document.getElementById('chatStatus');
const metricsDiv = document.getElementById('metrics');
const metricsText = document.getElementById('metricsText');
const themeToggle = document.getElementById('themeToggle');

// AI Guard elements
const aiGuardEnabled = document.getElementById('aiGuardEnabled');
const aiGuardConfig = document.getElementById('aiGuardConfig');
const aiGuardApiKey = document.getElementById('aiGuardApiKey');
const aiGuardRegion = document.getElementById('aiGuardRegion');
const aiGuardAppName = document.getElementById('aiGuardAppName');
const aiGuardStatus = document.getElementById('aiGuardStatus');

// Settings elements
const saveSettingsBtn = document.getElementById('saveSettings');
const saveStatus = document.getElementById('saveStatus');

// Scans elements
const scansList = document.getElementById('scansList');
const clearScansBtn = document.getElementById('clearScans');
const exportScansBtn = document.getElementById('exportScans');

// Badge elements
const currentProvider = document.getElementById('currentProvider');

// Provider configurations
const providers = {
    ollama: {
        endpoint: 'http://10.10.21.6:11434',
        requiresApiKey: false
    },
    openai: {
        endpoint: 'https://api.openai.com/v1/chat/completions',
        requiresApiKey: true
    },
    anthropic: {
        endpoint: 'https://api.anthropic.com/v1/messages',
        requiresApiKey: true
    }
};

// Initialize
function init() {
    loadConfig();
    loadTheme();
    loadScans();
    setupEventListeners();
    setupTabs();
    updateProviderUI();
    updateAIGuardUI();
    updateBadges();
    loadModels();
}

// Load config from localStorage
function loadConfig() {
    const saved = localStorage.getItem('chat-hub-config');
    if (saved) {
        const savedConfig = JSON.parse(saved);
        config = {
            ...config,
            ...savedConfig,
            aiGuard: { ...config.aiGuard, ...(savedConfig.aiGuard || {}) }
        };
        providerSelect.value = config.provider;
        endpointInput.value = config.endpoint;
        apiKeyInput.value = config.apiKey;

        // Load AI Guard settings
        aiGuardEnabled.checked = config.aiGuard.enabled;
        aiGuardApiKey.value = config.aiGuard.apiKey;
        aiGuardRegion.value = config.aiGuard.region;
        aiGuardAppName.value = config.aiGuard.appName;
    }
}

// Save config to localStorage
function saveConfig() {
    localStorage.setItem('chat-hub-config', JSON.stringify(config));
}

// Setup event listeners
function setupEventListeners() {
    providerSelect.addEventListener('change', () => {
        config.provider = providerSelect.value;
        config.endpoint = providers[config.provider].endpoint;
        endpointInput.value = config.endpoint;
        updateProviderUI();
    });

    endpointInput.addEventListener('change', () => {
        config.endpoint = endpointInput.value;
    });

    apiKeyInput.addEventListener('change', () => {
        config.apiKey = apiKeyInput.value;
    });

    modelSelect.addEventListener('change', () => {
        config.model = modelSelect.value;
        modelSelectChat.value = modelSelect.value;
        updateBadges();
    });

    modelSelectChat.addEventListener('change', () => {
        config.model = modelSelectChat.value;
        modelSelect.value = modelSelectChat.value;
        saveConfig();
        updateBadges();
    });

    refreshModelsBtn.addEventListener('click', loadModels);

    sendButton.addEventListener('click', sendMessage);

    chatInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    themeToggle.addEventListener('click', toggleTheme);

    // AI Guard event listeners
    aiGuardEnabled.addEventListener('change', () => {
        config.aiGuard.enabled = aiGuardEnabled.checked;
        updateAIGuardUI();
    });

    aiGuardApiKey.addEventListener('change', () => {
        config.aiGuard.apiKey = aiGuardApiKey.value;
    });

    aiGuardRegion.addEventListener('change', () => {
        config.aiGuard.region = aiGuardRegion.value;
    });

    aiGuardAppName.addEventListener('change', () => {
        config.aiGuard.appName = aiGuardAppName.value;
    });

    // Save settings button
    saveSettingsBtn.addEventListener('click', () => {
        saveConfig();
        updateBadges();
        loadModels();
        saveStatus.textContent = 'Settings saved!';
        saveStatus.style.color = 'var(--success)';
        setTimeout(() => {
            saveStatus.textContent = '';
        }, 3000);
    });

    // Scans buttons
    clearScansBtn.addEventListener('click', () => {
        if (confirm('Are you sure you want to clear all scan history?')) {
            scans = [];
            saveScans();
            renderScans();
        }
    });

    exportScansBtn.addEventListener('click', () => {
        const dataStr = JSON.stringify(scans, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `chat-hub-scans-${new Date().toISOString()}.json`;
        link.click();
        URL.revokeObjectURL(url);
    });
}

// Tab management
function setupTabs() {
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');

    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const tabName = button.getAttribute('data-tab');

            // Update active states
            tabButtons.forEach(btn => btn.classList.remove('active'));
            tabContents.forEach(content => content.classList.remove('active'));

            button.classList.add('active');
            document.getElementById(tabName + 'Tab').classList.add('active');
        });
    });
}

// Update AI Guard UI
function updateAIGuardUI() {
    aiGuardConfig.style.display = aiGuardEnabled.checked ? 'block' : 'none';
    aiGuardStatus.style.display = aiGuardEnabled.checked && config.aiGuard.apiKey ? 'inline-block' : 'none';
}

// Update badges in chat header
function updateBadges() {
    const providerNames = {
        'ollama': 'Ollama (Local)',
        'openai': 'OpenAI',
        'anthropic': 'Anthropic'
    };
    currentProvider.textContent = providerNames[config.provider] || config.provider;
    aiGuardStatus.style.display = config.aiGuard.enabled && config.aiGuard.apiKey ? 'inline-block' : 'none';
}

// Theme management
function loadTheme() {
    const savedTheme = localStorage.getItem('chat-hub-theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);
    updateThemeIcon(savedTheme);
}

function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('chat-hub-theme', newTheme);
    updateThemeIcon(newTheme);
}

function updateThemeIcon(theme) {
    const icon = themeToggle.querySelector('.theme-icon');
    icon.textContent = theme === 'dark' ? '☀️' : '🌙';
}

// Update UI based on provider
function updateProviderUI() {
    apiKeyGroup.style.display = providers[config.provider].requiresApiKey ? 'block' : 'none';
}

// Load available models
async function loadModels() {
    setStatus('Loading models...', 'loading');
    modelSelect.innerHTML = '<option value="">Loading...</option>';
    modelSelectChat.innerHTML = '<option value="">Loading...</option>';
    modelSelect.disabled = true;
    modelSelectChat.disabled = true;

    try {
        const response = await fetch('/api/models', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                provider: config.provider,
                endpoint: config.endpoint,
                apiKey: config.apiKey
            })
        });

        if (!response.ok) throw new Error('Failed to load models');

        const data = await response.json();
        modelSelect.innerHTML = '';
        modelSelectChat.innerHTML = '<option value="">Select model...</option>';

        if (data.models.length === 0) {
            modelSelect.innerHTML = '<option value="">No models available</option>';
            modelSelectChat.innerHTML = '<option value="">No models available</option>';
            setStatus('No models found', 'error');
        } else {
            data.models.forEach(model => {
                const option1 = document.createElement('option');
                option1.value = model;
                option1.textContent = model;
                modelSelect.appendChild(option1);

                const option2 = document.createElement('option');
                option2.value = model;
                option2.textContent = model;
                modelSelectChat.appendChild(option2);
            });

            if (config.model && data.models.includes(config.model)) {
                modelSelect.value = config.model;
                modelSelectChat.value = config.model;
            } else {
                config.model = data.models[0];
                modelSelect.value = config.model;
                modelSelectChat.value = config.model;
            }

            modelSelect.disabled = false;
            modelSelectChat.disabled = false;
            setStatus('Ready', 'success');
        }
    } catch (error) {
        console.error('Error loading models:', error);
        modelSelect.innerHTML = '<option value="">Error loading models</option>';
        modelSelectChat.innerHTML = '<option value="">Error loading models</option>';
        setStatus('Error: ' + error.message, 'error');
    }
}

// Send message
async function sendMessage() {
    const text = chatInput.value.trim();
    if (!text) return;

    if (!config.model) {
        setStatus('Please select a model first', 'error');
        return;
    }

    if (providers[config.provider].requiresApiKey && !config.apiKey) {
        setStatus('API key required for this provider', 'error');
        return;
    }

    // Add user message
    messages.push({ role: 'user', content: text });
    appendMessage('user', text);
    chatInput.value = '';
    chatInput.disabled = true;
    sendButton.disabled = true;
    sendButton.innerHTML = '<span class="loading"></span> Sending...';
    setStatus('Sending...', 'loading');

    // Add thinking indicator
    const thinkingId = addThinkingIndicator();
    const startTime = Date.now();

    try {
        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                provider: config.provider,
                endpoint: config.endpoint,
                apiKey: config.apiKey,
                model: config.model,
                messages: messages,
                aiGuard: config.aiGuard.enabled ? config.aiGuard : null
            })
        });

        if (!response.ok) {
            const error = await response.json();
            if (error.aiGuardBlocked) {
                throw new Error(`🛡️ AI Guard: ${error.error}`);
            }
            throw new Error(error.error || 'Request failed');
        }

        const data = await response.json();
        const endTime = Date.now();
        const responseTime = ((endTime - startTime) / 1000).toFixed(2);

        // Estimate tokens (very rough: ~4 chars per token)
        const estimatedTokens = Math.round(data.message.length / 4);
        const tokensPerSecond = (estimatedTokens / parseFloat(responseTime)).toFixed(1);

        removeThinkingIndicator(thinkingId);

        messages.push({ role: 'assistant', content: data.message });
        appendMessage('assistant', data.message, data.model, {
            responseTime,
            estimatedTokens,
            tokensPerSecond
        });

        // Record scan
        recordScan({
            timestamp: new Date().toISOString(),
            provider: config.provider,
            model: config.model,
            aiGuardEnabled: config.aiGuard.enabled,
            prompt: text,
            response: data.message,
            metrics: {
                responseTime,
                estimatedTokens,
                tokensPerSecond
            }
        });

        setStatus('Ready', 'success');
        showMetrics(`Last: ${responseTime}s • ~${tokensPerSecond} tok/s`);
    } catch (error) {
        console.error('Error sending message:', error);
        removeThinkingIndicator(thinkingId);
        appendMessage('error', 'Error: ' + error.message);
        setStatus('Error: ' + error.message, 'error');
    } finally {
        chatInput.disabled = false;
        sendButton.disabled = false;
        sendButton.textContent = 'Send';
        chatInput.focus();
    }
}

// Add thinking indicator
function addThinkingIndicator() {
    const thinkingDiv = document.createElement('div');
    thinkingDiv.className = 'thinking-indicator';
    thinkingDiv.id = 'thinking-' + Date.now();
    thinkingDiv.innerHTML = `
        <span>Thinking</span>
        <div class="thinking-dots">
            <div class="thinking-dot"></div>
            <div class="thinking-dot"></div>
            <div class="thinking-dot"></div>
        </div>
    `;
    chatMessages.appendChild(thinkingDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    return thinkingDiv.id;
}

// Remove thinking indicator
function removeThinkingIndicator(id) {
    const indicator = document.getElementById(id);
    if (indicator) indicator.remove();
}

// Show metrics
function showMetrics(text) {
    metricsText.textContent = text;
    metricsDiv.style.display = 'block';
}

// Append message to chat
function appendMessage(type, content, model = null, metrics = null) {
    // Remove welcome message if present
    const welcome = chatMessages.querySelector('.welcome-message');
    if (welcome) welcome.remove();

    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}`;

    if (type !== 'error' && model) {
        const header = document.createElement('div');
        header.className = 'message-header';
        header.textContent = model;
        messageDiv.appendChild(header);
    }

    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.textContent = content;
    messageDiv.appendChild(contentDiv);

    // Add metrics if available
    if (metrics && type === 'assistant') {
        const metricsDiv = document.createElement('div');
        metricsDiv.className = 'message-metrics';
        metricsDiv.textContent = `⏱️ ${metrics.responseTime}s • 📊 ~${metrics.estimatedTokens} tokens • ⚡ ${metrics.tokensPerSecond} tok/s`;
        messageDiv.appendChild(metricsDiv);
    }

    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Set status
function setStatus(text, type = 'info') {
    chatStatusDiv.textContent = text;
    chatStatusDiv.style.color = type === 'error' ? 'var(--error)' : type === 'success' ? 'var(--success)' : 'var(--text-secondary)';
}

// Load scans from localStorage
function loadScans() {
    const saved = localStorage.getItem('chat-hub-scans');
    if (saved) {
        scans = JSON.parse(saved);
        renderScans();
    }
}

// Save scans to localStorage
function saveScans() {
    localStorage.setItem('chat-hub-scans', JSON.stringify(scans));
}

// Record a new scan
function recordScan(scan) {
    scans.unshift(scan); // Add to beginning
    // Keep only last 100 scans
    if (scans.length > 100) {
        scans = scans.slice(0, 100);
    }
    saveScans();
    renderScans();
}

// Render scans list
function renderScans() {
    if (scans.length === 0) {
        scansList.innerHTML = `
            <div class="empty-scans">
                <p>No interactions yet. Start chatting to see your conversation history here.</p>
            </div>
        `;
        return;
    }

    scansList.innerHTML = scans.map((scan, index) => {
        const date = new Date(scan.timestamp);
        const formattedDate = date.toLocaleString();

        const providerNames = {
            'ollama': 'Ollama (Local)',
            'openai': 'OpenAI',
            'anthropic': 'Anthropic'
        };

        return `
            <div class="scan-item">
                <div class="scan-header">
                    <div class="scan-meta">
                        <span class="scan-timestamp">${formattedDate}</span>
                        <span class="scan-badge provider">${providerNames[scan.provider] || scan.provider}</span>
                        <span class="scan-badge model">${scan.model}</span>
                        <span class="scan-badge ${scan.aiGuardEnabled ? 'guard-enabled' : 'guard-disabled'}">
                            ${scan.aiGuardEnabled ? '🛡️ AI Guard ON' : 'AI Guard OFF'}
                        </span>
                    </div>
                </div>
                <div class="scan-content">
                    <div class="scan-section">
                        <div class="scan-section-title">User Prompt</div>
                        <div class="scan-section-content">${escapeHtml(scan.prompt)}</div>
                    </div>
                    <div class="scan-section">
                        <div class="scan-section-title">Model Response</div>
                        <div class="scan-section-content">${escapeHtml(scan.response)}</div>
                    </div>
                    ${scan.metrics ? `
                        <div class="scan-section">
                            <div class="scan-section-title">Metrics</div>
                            <div class="scan-metrics">
                                <div class="scan-metric">
                                    <span>⏱️</span>
                                    <span>${scan.metrics.responseTime}s</span>
                                </div>
                                <div class="scan-metric">
                                    <span>📊</span>
                                    <span>~${scan.metrics.estimatedTokens} tokens</span>
                                </div>
                                <div class="scan-metric">
                                    <span>⚡</span>
                                    <span>${scan.metrics.tokensPerSecond} tok/s</span>
                                </div>
                            </div>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
    }).join('');
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Start the app
init();
