// Configuration state
let config = {
    provider: 'ollama',
    endpoint: 'http://10.10.21.6:11434',
    apiKey: '',
    model: ''
};

// Chat history
let messages = [];

// DOM Elements
const providerSelect = document.getElementById('provider');
const endpointInput = document.getElementById('endpoint');
const apiKeyInput = document.getElementById('apiKey');
const apiKeyGroup = document.getElementById('api-key-group');
const modelSelect = document.getElementById('model');
const refreshModelsBtn = document.getElementById('refreshModels');
const chatMessages = document.getElementById('chatMessages');
const chatInput = document.getElementById('chatInput');
const sendButton = document.getElementById('sendButton');
const statusDiv = document.getElementById('status');

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
    setupEventListeners();
    updateProviderUI();
    loadModels();
}

// Load config from localStorage
function loadConfig() {
    const saved = localStorage.getItem('chat-hub-config');
    if (saved) {
        config = { ...config, ...JSON.parse(saved) };
        providerSelect.value = config.provider;
        endpointInput.value = config.endpoint;
        apiKeyInput.value = config.apiKey;
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
        saveConfig();
        loadModels();
    });

    endpointInput.addEventListener('change', () => {
        config.endpoint = endpointInput.value;
        saveConfig();
    });

    apiKeyInput.addEventListener('change', () => {
        config.apiKey = apiKeyInput.value;
        saveConfig();
    });

    modelSelect.addEventListener('change', () => {
        config.model = modelSelect.value;
        saveConfig();
    });

    refreshModelsBtn.addEventListener('click', loadModels);

    sendButton.addEventListener('click', sendMessage);

    chatInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });
}

// Update UI based on provider
function updateProviderUI() {
    apiKeyGroup.style.display = providers[config.provider].requiresApiKey ? 'block' : 'none';
}

// Load available models
async function loadModels() {
    setStatus('Loading models...', 'loading');
    modelSelect.innerHTML = '<option value="">Loading...</option>';
    modelSelect.disabled = true;

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

        if (data.models.length === 0) {
            modelSelect.innerHTML = '<option value="">No models available</option>';
            setStatus('No models found', 'error');
        } else {
            data.models.forEach(model => {
                const option = document.createElement('option');
                option.value = model;
                option.textContent = model;
                modelSelect.appendChild(option);
            });

            if (config.model && data.models.includes(config.model)) {
                modelSelect.value = config.model;
            } else {
                config.model = data.models[0];
                modelSelect.value = config.model;
            }

            modelSelect.disabled = false;
            setStatus('Ready', 'success');
        }
    } catch (error) {
        console.error('Error loading models:', error);
        modelSelect.innerHTML = '<option value="">Error loading models</option>';
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

    try {
        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                provider: config.provider,
                endpoint: config.endpoint,
                apiKey: config.apiKey,
                model: config.model,
                messages: messages
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Request failed');
        }

        const data = await response.json();
        messages.push({ role: 'assistant', content: data.message });
        appendMessage('assistant', data.message, data.model);
        setStatus('Ready', 'success');
    } catch (error) {
        console.error('Error sending message:', error);
        appendMessage('error', 'Error: ' + error.message);
        setStatus('Error: ' + error.message, 'error');
    } finally {
        chatInput.disabled = false;
        sendButton.disabled = false;
        sendButton.textContent = 'Send';
        chatInput.focus();
    }
}

// Append message to chat
function appendMessage(type, content, model = null) {
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

    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Set status
function setStatus(text, type = 'info') {
    statusDiv.textContent = text;
    statusDiv.style.color = type === 'error' ? 'var(--error)' : type === 'success' ? 'var(--success)' : 'var(--text-secondary)';
}

// Start the app
init();
