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
    },
    tmas: {
        useSharedKey: false,
        apiKey: '',
        region: 'us-east-1'
    }
};

// Chat history
let messages = [];
let scans = [];
let selectedFiles = [];

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
const fileInput = document.getElementById('fileInput');
const attachButton = document.getElementById('attachButton');
const selectedFilesDiv = document.getElementById('selectedFiles');

// AI Guard elements
const aiGuardEnabled = document.getElementById('aiGuardEnabled');
const aiGuardConfig = document.getElementById('aiGuardConfig');
const aiGuardApiKey = document.getElementById('aiGuardApiKey');
const aiGuardRegion = document.getElementById('aiGuardRegion');
const aiGuardAppName = document.getElementById('aiGuardAppName');
const aiGuardStatus = document.getElementById('aiGuardStatus');

// TMAS elements
const tmasUseSharedKey = document.getElementById('tmasUseSharedKey');
const tmasApiKeyGroup = document.getElementById('tmasApiKeyGroup');
const tmasApiKey = document.getElementById('tmasApiKey');
const tmasRegion = document.getElementById('tmasRegion');
const tmasModelSelect = document.getElementById('tmasModelSelect');
const scanModelButton = document.getElementById('scanModelButton');
const deleteModelButton = document.getElementById('deleteModelButton');
const tmasScanProgress = document.getElementById('tmasScanProgress');
const tmasScanProgressBar = document.getElementById('tmasScanProgressBar');
const tmasScanStatus = document.getElementById('tmasScanStatus');
const refreshTmasResults = document.getElementById('refreshTmasResults');
const tmasResultsList = document.getElementById('tmasResultsList');

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

// ============================================================================
// TMAS (Trend Micro Artifact Scanner) Functions
// ============================================================================

// Load TMAS scan results
async function loadTMASResults() {
    if (!tmasResultsList) return;

    tmasResultsList.innerHTML = '<div class="tmas-empty-results">Loading...</div>';

    try {
        const response = await fetch('/api/tmas/results');
        if (!response.ok) throw new Error('Failed to load results');

        const data = await response.json();

        if (data.scans.length === 0) {
            tmasResultsList.innerHTML = `
                <div class="tmas-empty-results">
                    <p>No scan results yet. Select a model and click "Scan Model" to start.</p>
                </div>
            `;
        } else {
            renderTMASResults(data.scans);
        }
    } catch (error) {
        console.error('Error loading TMAS results:', error);
        tmasResultsList.innerHTML = `
            <div class="tmas-empty-results">
                <p>Error loading results: ${escapeHtml(error.message)}</p>
            </div>
        `;
    }
}

// Render TMAS scan results
function renderTMASResults(scans) {
    tmasResultsList.innerHTML = scans.map(scan => `
        <div class="tmas-result-item" data-id="${scan.id}">
            <div class="tmas-result-header">
                <div class="tmas-result-info">
                    <div class="tmas-model-name">${escapeHtml(scan.modelName)}</div>
                    <div class="tmas-scan-date">${new Date(scan.scanDate).toLocaleString()} • ${scan.scanDuration}</div>
                </div>
                <div class="tmas-result-actions">
                    <span class="tmas-threat-badge ${scan.threatLevel}">${scan.threatLevel.toUpperCase()}</span>
                    <button class="btn-details" onclick="toggleTMASDetails('${scan.id}')">Details</button>
                    <button class="btn-rescan" onclick="rescanModel('${escapeHtml(scan.modelName)}')">Re-scan</button>
                    <button class="btn-delete-scan" onclick="deleteTMASScan('${scan.id}')">Delete</button>
                </div>
            </div>
            <div class="tmas-result-details" id="tmas-details-${scan.id}">
                <div class="tmas-metadata-section">
                    <h4>Scan Metadata</h4>
                    <div class="tmas-metadata-grid">
                        <div class="tmas-metadata-item">
                            <span class="tmas-metadata-label">Model:</span>
                            <span class="tmas-metadata-value">${escapeHtml(scan.fullReport?.details?.application || scan.modelName)}</span>
                        </div>
                        <div class="tmas-metadata-item">
                            <span class="tmas-metadata-label">Endpoint:</span>
                            <span class="tmas-metadata-value">${escapeHtml(scan.fullReport?.details?.endpoint || 'N/A')}</span>
                        </div>
                        <div class="tmas-metadata-item">
                            <span class="tmas-metadata-label">Scan Date:</span>
                            <span class="tmas-metadata-value">${scan.fullReport?.details?.scan_time || new Date(scan.scanDate).toUTCString()}</span>
                        </div>
                        <div class="tmas-metadata-item">
                            <span class="tmas-metadata-label">Duration:</span>
                            <span class="tmas-metadata-value">${scan.fullReport?.details?.scan_duration || scan.scanDuration}</span>
                        </div>
                        <div class="tmas-metadata-item">
                            <span class="tmas-metadata-label">Scan ID:</span>
                            <span class="tmas-metadata-value tmas-scan-id">${scan.fullReport?.details?.scan_id || scan.id}</span>
                        </div>
                    </div>
                </div>
                <div class="tmas-stats">
                    <div class="tmas-stat">
                        <span>Risk Score:</span>
                        <span class="tmas-stat-value">${scan.riskScore}/100</span>
                    </div>
                    <div class="tmas-stat">
                        <span>Vulnerabilities:</span>
                        <span class="tmas-stat-value">${scan.vulnerabilities.length}</span>
                    </div>
                    <div class="tmas-stat">
                        <span>Malware:</span>
                        <span class="tmas-stat-value">${scan.malwareDetected ? 'DETECTED' : 'None'}</span>
                    </div>
                </div>
                <div class="tmas-risk-meter">
                    <div class="tmas-risk-fill ${getRiskClass(scan.riskScore)}"
                         style="width: ${scan.riskScore}%"></div>
                </div>
                ${scan.vulnerabilities.length > 0 ? `
                    <div class="tmas-vuln-list">
                        ${scan.vulnerabilities.map((v, idx) => {
                            console.log('Rendering vulnerability:', v.id, 'attacks:', v.attacks?.length || 0);
                            return `
                            <div class="tmas-vuln-item">
                                <div class="tmas-vuln-header" onclick="toggleVulnDetails('${scan.id}', ${idx}, event)">
                                    <span class="tmas-vuln-id">${escapeHtml(v.id)}</span>
                                    <span class="tmas-vuln-severity ${v.severity}">${v.severity}</span>
                                    <span class="tmas-vuln-description">${escapeHtml(v.description)}</span>
                                    ${v.attacks && v.attacks.length > 0 ? '<span class="tmas-expand-icon">▶</span>' : ''}
                                </div>
                                ${v.attacks && v.attacks.length > 0 ? `
                                    <div class="tmas-vuln-attacks" id="vuln-attacks-${scan.id}-${idx}" style="display: none;">
                                        <h5>Successful Attack Examples:</h5>
                                        ${v.attacks.map((attack, attackIdx) => `
                                            <div class="tmas-attack-example">
                                                <div class="tmas-attack-number">Attack #${attackIdx + 1}</div>
                                                <div class="tmas-attack-prompt">
                                                    <strong>Prompt:</strong>
                                                    <pre>${escapeHtml(attack.prompt)}</pre>
                                                </div>
                                                <div class="tmas-attack-response">
                                                    <strong>Model Response:</strong>
                                                    <pre>${escapeHtml(attack.response.substring(0, 500))}${attack.response.length > 500 ? '...' : ''}</pre>
                                                </div>
                                                ${attack.evaluation ? `
                                                    <div class="tmas-attack-evaluation">
                                                        <strong>Evaluation:</strong>
                                                        <p>${escapeHtml(attack.evaluation)}</p>
                                                    </div>
                                                ` : ''}
                                            </div>
                                        `).join('')}
                                    </div>
                                ` : ''}
                            </div>
                        `;
                        }).join('')}
                    </div>
                ` : ''}
                <div class="tmas-raw-output-section">
                    <button class="btn-view-raw" onclick="toggleRawOutput('${scan.id}')">View Raw Output</button>
                    <pre class="tmas-raw-output" id="tmas-raw-${scan.id}" style="display: none;">${escapeHtml(scan.fullReport.raw || JSON.stringify(scan.fullReport, null, 2))}</pre>
                </div>
            </div>
        </div>
    `).join('');
}

// Get risk class for styling
function getRiskClass(score) {
    if (score < 30) return 'low';
    if (score < 60) return 'medium';
    return 'high';
}

// Toggle TMAS details
function toggleTMASDetails(id) {
    const details = document.getElementById(`tmas-details-${id}`);
    if (details) {
        details.classList.toggle('expanded');
    }
}

// Toggle raw output display
function toggleRawOutput(id) {
    const rawOutput = document.getElementById(`tmas-raw-${id}`);
    if (rawOutput) {
        if (rawOutput.style.display === 'none') {
            rawOutput.style.display = 'block';
        } else {
            rawOutput.style.display = 'none';
        }
    }
}

// Toggle vulnerability attack details
function toggleVulnDetails(scanId, vulnIdx, evt) {
    const attacksDiv = document.getElementById(`vuln-attacks-${scanId}-${vulnIdx}`);
    const icon = evt?.currentTarget?.querySelector('.tmas-expand-icon');

    console.log('toggleVulnDetails called:', {
        scanId,
        vulnIdx,
        attacksDivFound: !!attacksDiv,
        iconFound: !!icon,
        attacksDivId: `vuln-attacks-${scanId}-${vulnIdx}`
    });

    if (attacksDiv) {
        if (attacksDiv.style.display === 'none' || attacksDiv.style.display === '') {
            attacksDiv.style.display = 'block';
            if (icon) icon.textContent = '▼';
            console.log('Expanded vulnerability details');
        } else {
            attacksDiv.style.display = 'none';
            if (icon) icon.textContent = '▶';
            console.log('Collapsed vulnerability details');
        }
    } else {
        console.warn('No attacks div found - vulnerability may not have attack details');
    }
}

// Handle TMAS scan
async function handleTMASScan() {
    const modelName = tmasModelSelect.value;
    if (!modelName) {
        alert('Please select a model to scan');
        return;
    }

    const effectiveApiKey = getEffectiveTMASApiKey();
    if (!effectiveApiKey) {
        alert('Please configure TMAS API key (or enable AI Guard with API key)');
        return;
    }

    // Show progress
    tmasScanProgress.style.display = 'block';
    tmasScanProgressBar.style.width = '0%';
    tmasScanStatus.textContent = 'Initializing LLM endpoint scan...';
    scanModelButton.disabled = true;
    scanModelButton.textContent = 'Scanning...';

    try {
        tmasScanProgressBar.style.width = '20%';
        tmasScanStatus.textContent = 'Testing model for security vulnerabilities...';

        const response = await fetch('/api/tmas/scan', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                modelName: modelName,
                endpoint: config.endpoint,
                apiKey: effectiveApiKey,
                region: config.tmas.region,
                scanType: 'llm'
            })
        });

        tmasScanProgressBar.style.width = '80%';
        tmasScanStatus.textContent = 'Processing results...';

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Scan failed');
        }

        const data = await response.json();

        tmasScanProgressBar.style.width = '100%';
        tmasScanStatus.textContent = `Scan complete! Threat level: ${data.result.threatLevel.toUpperCase()}`;

        // Refresh results
        await loadTMASResults();

        // Hide progress after delay
        setTimeout(() => {
            tmasScanProgress.style.display = 'none';
        }, 3000);

    } catch (error) {
        console.error('TMAS scan error:', error);
        tmasScanStatus.textContent = `Error: ${error.message}`;
        tmasScanProgressBar.style.width = '0%';
        alert(`Scan failed: ${error.message}`);
    } finally {
        scanModelButton.disabled = false;
        scanModelButton.textContent = 'Scan Model';
    }
}

// Handle model deletion
async function handleDeleteModel() {
    const modelName = modelSelect.value;
    if (!modelName) {
        alert('Please select a model to delete');
        return;
    }

    if (!confirm(`Are you sure you want to delete the model "${modelName}"?\n\nThis will permanently remove the model from Ollama.`)) {
        return;
    }

    deleteModelButton.disabled = true;
    deleteModelButton.textContent = 'Deleting...';

    try {
        const response = await fetch('/api/ollama/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                modelName: modelName,
                endpoint: config.endpoint
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Delete failed');
        }

        alert(`Model "${modelName}" deleted successfully`);

        // Reload models list
        await loadModels();

    } catch (error) {
        console.error('Model delete error:', error);
        alert(`Delete failed: ${error.message}`);
    } finally {
        deleteModelButton.disabled = false;
        deleteModelButton.textContent = 'Delete Model';
    }
}

// Re-scan a model
async function rescanModel(modelName) {
    if (tmasModelSelect) {
        tmasModelSelect.value = modelName;
        await handleTMASScan();
    }
}

// Delete TMAS scan result
async function deleteTMASScan(id) {
    if (!confirm('Are you sure you want to delete this scan result?')) return;

    try {
        const response = await fetch(`/api/tmas/result/${id}`, {
            method: 'DELETE'
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Delete failed');
        }

        await loadTMASResults();
    } catch (error) {
        console.error('Error deleting scan:', error);
        alert(`Failed to delete: ${error.message}`);
    }
}

// Update TMAS model select dropdown
function updateTMASModelSelect(models) {
    if (!tmasModelSelect) return;

    tmasModelSelect.innerHTML = '<option value="">Select model to scan...</option>';
    models.forEach(model => {
        const option = document.createElement('option');
        option.value = model;
        option.textContent = model;
        tmasModelSelect.appendChild(option);
    });
}

// Make TMAS functions globally accessible
window.toggleTMASDetails = toggleTMASDetails;
window.rescanModel = rescanModel;
window.deleteTMASScan = deleteTMASScan;

// Initialize
function init() {
    loadConfig();
    loadTheme();
    loadScans();
    setupEventListeners();
    setupTabs();
    updateProviderUI();
    updateAIGuardUI();
    updateTMASUI();
    updateBadges();
    loadModels();
    loadTMASResults();
}

// Load config from localStorage
function loadConfig() {
    const saved = localStorage.getItem('chat-hub-config');
    if (saved) {
        const savedConfig = JSON.parse(saved);
        config = {
            ...config,
            ...savedConfig,
            aiGuard: { ...config.aiGuard, ...(savedConfig.aiGuard || {}) },
            tmas: { ...config.tmas, ...(savedConfig.tmas || {}) }
        };
        providerSelect.value = config.provider;
        endpointInput.value = config.endpoint;
        apiKeyInput.value = config.apiKey;

        // Load AI Guard settings
        aiGuardEnabled.checked = config.aiGuard.enabled;
        aiGuardApiKey.value = config.aiGuard.apiKey;
        aiGuardRegion.value = config.aiGuard.region;
        aiGuardAppName.value = config.aiGuard.appName;

        // Load TMAS settings
        if (tmasUseSharedKey) tmasUseSharedKey.checked = config.tmas.useSharedKey;
        if (tmasApiKey) tmasApiKey.value = config.tmas.apiKey;
        if (tmasRegion) tmasRegion.value = config.tmas.region;
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

    // File upload event listeners
    attachButton.addEventListener('click', () => {
        fileInput.click();
    });

    fileInput.addEventListener('change', handleFileSelect);

    // AI Guard event listeners
    aiGuardEnabled.addEventListener('change', () => {
        config.aiGuard.enabled = aiGuardEnabled.checked;
        updateAIGuardUI();
        saveConfig();
        updateBadges();
    });

    aiGuardApiKey.addEventListener('change', () => {
        config.aiGuard.apiKey = aiGuardApiKey.value;
        saveConfig();
        updateBadges();
    });

    aiGuardRegion.addEventListener('change', () => {
        config.aiGuard.region = aiGuardRegion.value;
        saveConfig();
    });

    aiGuardAppName.addEventListener('change', () => {
        config.aiGuard.appName = aiGuardAppName.value;
        saveConfig();
    });

    // TMAS event listeners
    if (tmasUseSharedKey) {
        tmasUseSharedKey.addEventListener('change', () => {
            config.tmas.useSharedKey = tmasUseSharedKey.checked;
            updateTMASUI();
            saveConfig();
        });
    }

    if (tmasApiKey) {
        tmasApiKey.addEventListener('change', () => {
            config.tmas.apiKey = tmasApiKey.value;
            saveConfig();
        });
    }

    if (tmasRegion) {
        tmasRegion.addEventListener('change', () => {
            config.tmas.region = tmasRegion.value;
            saveConfig();
        });
    }


    if (scanModelButton) {
        scanModelButton.addEventListener('click', handleTMASScan);
    }

    if (deleteModelButton) {
        deleteModelButton.addEventListener('click', handleDeleteModel);
    }

    if (refreshTmasResults) {
        refreshTmasResults.addEventListener('click', loadTMASResults);
    }

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

    // Model management buttons
    const refreshLoadedModelsBtn = document.getElementById('refreshLoadedModels');
    if (refreshLoadedModelsBtn) {
        refreshLoadedModelsBtn.addEventListener('click', loadLoadedModels);
    }

    const loadModelButton = document.getElementById('loadModelButton');
    if (loadModelButton) {
        loadModelButton.addEventListener('click', handleLoadModel);
    }

    const pullModelButton = document.getElementById('pullModelButton');
    if (pullModelButton) {
        pullModelButton.addEventListener('click', handlePullModel);
    }

    const refreshAllModelsBtn = document.getElementById('refreshAllModels');
    if (refreshAllModelsBtn) {
        refreshAllModelsBtn.addEventListener('click', loadAllModelsTable);
    }
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

// Update TMAS UI
function updateTMASUI() {
    if (tmasApiKeyGroup) {
        tmasApiKeyGroup.style.display = config.tmas.useSharedKey ? 'none' : 'block';
    }
}

// Get effective TMAS API key (shared or separate)
function getEffectiveTMASApiKey() {
    if (config.tmas.useSharedKey) {
        return config.aiGuard.apiKey;
    }
    return config.tmas.apiKey;
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

    // Show/hide Ollama model management section
    const ollamaManagementSection = document.getElementById('ollamaManagementSection');
    if (ollamaManagementSection) {
        ollamaManagementSection.style.display = config.provider === 'ollama' ? 'block' : 'none';

        // Load all models table if Ollama is selected
        if (config.provider === 'ollama') {
            loadAllModelsTable();
        }
    }
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

            // Populate modelToLoad dropdown for Ollama
            const modelToLoadSelect = document.getElementById('modelToLoad');
            if (modelToLoadSelect && config.provider === 'ollama') {
                modelToLoadSelect.innerHTML = '<option value="">Select model to load...</option>';
                data.models.forEach(model => {
                    const option = document.createElement('option');
                    option.value = model;
                    option.textContent = model;
                    modelToLoadSelect.appendChild(option);
                });
            }

            // Populate TMAS model select dropdown
            updateTMASModelSelect(data.models);

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

// Handle file selection
function handleFileSelect(event) {
    const files = Array.from(event.target.files);

    files.forEach(file => {
        // Check file size (max 20MB)
        if (file.size > 20 * 1024 * 1024) {
            alert(`File "${file.name}" is too large. Maximum size is 20MB.`);
            return;
        }

        selectedFiles.push(file);
    });

    renderSelectedFiles();
    fileInput.value = ''; // Clear input for next selection
}

// Render selected files
function renderSelectedFiles() {
    if (selectedFiles.length === 0) {
        selectedFilesDiv.innerHTML = '';
        return;
    }

    selectedFilesDiv.innerHTML = selectedFiles.map((file, index) => {
        const icon = getFileIcon(file.type);
        const size = formatFileSize(file.size);

        return `
            <div class="file-chip">
                <span class="file-chip-icon">${icon}</span>
                <span class="file-chip-name" title="${escapeHtml(file.name)}">${escapeHtml(file.name)}</span>
                <span class="file-chip-size">${size}</span>
                <button class="file-chip-remove" onclick="removeFile(${index})" title="Remove file">×</button>
            </div>
        `;
    }).join('');
}

// Remove file from selection
function removeFile(index) {
    selectedFiles.splice(index, 1);
    renderSelectedFiles();
}

// Get file icon based on type
function getFileIcon(type) {
    if (type.startsWith('image/')) return '🖼️';
    if (type === 'application/pdf') return '📄';
    if (type.includes('word') || type.includes('document')) return '📝';
    if (type.includes('text')) return '📃';
    return '📎';
}

// Format file size
function formatFileSize(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Read file as base64
async function readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            resolve({
                name: file.name,
                type: file.type,
                size: file.size,
                data: base64
            });
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

// Send message
async function sendMessage() {
    const text = chatInput.value.trim();
    const hasFiles = selectedFiles.length > 0;

    if (!text && !hasFiles) return;

    if (!config.model) {
        setStatus('Please select a model first', 'error');
        return;
    }

    if (providers[config.provider].requiresApiKey && !config.apiKey) {
        setStatus('API key required for this provider', 'error');
        return;
    }

    // Add thinking indicator
    const thinkingId = addThinkingIndicator();
    const startTime = Date.now();

    // Read files as base64
    let filesData = [];
    if (hasFiles) {
        try {
            setStatus('Reading files...', 'loading');
            updateThinkingStatus(thinkingId, `Reading ${selectedFiles.length} file(s)...`, 'info');
            filesData = await Promise.all(selectedFiles.map(file => readFileAsBase64(file)));
            updateThinkingStatus(thinkingId, `Successfully read ${filesData.length} file(s)`, 'success');
        } catch (error) {
            console.error('Error reading files:', error);
            updateThinkingStatus(thinkingId, 'Error reading files', 'error');
            removeThinkingIndicator(thinkingId);
            setStatus('Error reading files', 'error');
            alert('Error reading files. Please try again.');
            return;
        }
    }

    // Build message content
    let messageContent = text;
    if (hasFiles) {
        const filesList = filesData.map(f => f.name).join(', ');
        messageContent = text ? `${text}\n\n[Attached: ${filesList}]` : `[Attached: ${filesList}]`;
    }

    // Add user message
    messages.push({ role: 'user', content: messageContent });
    appendMessage('user', messageContent);

    // Clear input and files
    chatInput.value = '';
    selectedFiles = [];
    renderSelectedFiles();

    chatInput.disabled = true;
    sendButton.disabled = true;
    attachButton.disabled = true;
    sendButton.innerHTML = '<span class="loading"></span> Sending...';
    setStatus('Sending...', 'loading');

    try {
        // Update status for AI Guard validation
        if (config.aiGuard.enabled && config.aiGuard.apiKey) {
            updateThinkingStatus(thinkingId, 'AI Guard: Validating input...', 'info');
        }

        updateThinkingStatus(thinkingId, `Sending request to ${config.provider} (${config.model})...`, 'info');

        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                provider: config.provider,
                endpoint: config.endpoint,
                apiKey: config.apiKey,
                model: config.model,
                messages: messages,
                files: filesData.length > 0 ? filesData : null,
                aiGuard: config.aiGuard.enabled ? config.aiGuard : null
            })
        });

        updateThinkingStatus(thinkingId, 'Received response from LLM', 'success');

        if (!response.ok) {
            const error = await response.json();
            if (error.aiGuardBlocked) {
                updateThinkingStatus(thinkingId, 'AI Guard blocked this request', 'error');
                // Create an error with AI Guard results attached
                const guardError = new Error(`🛡️ AI Guard: ${error.error}`);
                guardError.aiGuardBlocked = true;
                guardError.aiGuardResults = error.aiGuardResults;
                guardError.reasons = error.reasons;
                throw guardError;
            }
            updateThinkingStatus(thinkingId, `Request failed: ${error.error || 'Unknown error'}`, 'error');
            throw new Error(error.error || 'Request failed');
        }

        const data = await response.json();
        const endTime = Date.now();
        const responseTime = ((endTime - startTime) / 1000).toFixed(2);

        // Estimate tokens (very rough: ~4 chars per token)
        const estimatedTokens = Math.round(data.message.length / 4);
        const tokensPerSecond = (estimatedTokens / parseFloat(responseTime)).toFixed(1);

        // Update status for AI Guard output validation
        if (config.aiGuard.enabled && config.aiGuard.apiKey && data.aiGuardResults?.outputValidation) {
            const outputStatus = data.aiGuardResults.outputValidation.action === 'Allow' ? 'passed' : 'blocked';
            updateThinkingStatus(thinkingId, `AI Guard: Output validation ${outputStatus}`,
                outputStatus === 'passed' ? 'success' : 'error');
        }

        updateThinkingStatus(thinkingId, `Completed in ${responseTime}s (~${tokensPerSecond} tok/s)`, 'success');

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
            aiGuardResults: data.aiGuardResults || null,
            prompt: messageContent,
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
        const endTime = Date.now();
        const responseTime = ((endTime - startTime) / 1000).toFixed(2);

        // Don't prefix AI Guard blocks with "Error:" since they're security protections
        const displayMessage = error.message.startsWith('🛡️ AI Guard:')
            ? error.message
            : 'Error: ' + error.message;
        appendMessage('error', displayMessage);
        setStatus(displayMessage, 'error');

        // Record scan even when AI Guard blocks
        if (error.aiGuardBlocked && error.aiGuardResults) {
            recordScan({
                timestamp: new Date().toISOString(),
                provider: config.provider,
                model: config.model,
                aiGuardEnabled: config.aiGuard.enabled,
                aiGuardResults: error.aiGuardResults,
                prompt: messageContent,
                response: '', // No response since it was blocked
                blocked: true,
                blockReason: error.message,
                metrics: {
                    responseTime,
                    estimatedTokens: 0,
                    tokensPerSecond: 0
                }
            });
        }
    } finally {
        chatInput.disabled = false;
        sendButton.disabled = false;
        attachButton.disabled = false;
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
        <div class="thinking-header" onclick="toggleThinkingDetails('${thinkingDiv.id}')">
            <div class="thinking-main">
                <span>Processing</span>
                <div class="thinking-dots">
                    <div class="thinking-dot"></div>
                    <div class="thinking-dot"></div>
                    <div class="thinking-dot"></div>
                </div>
            </div>
            <span class="thinking-toggle">▼</span>
        </div>
        <div class="thinking-details" id="${thinkingDiv.id}-details">
            <div class="thinking-status-log"></div>
        </div>
    `;
    chatMessages.appendChild(thinkingDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    return thinkingDiv.id;
}

// Toggle thinking details
function toggleThinkingDetails(id) {
    const indicator = document.getElementById(id);
    if (!indicator) return;

    const details = indicator.querySelector('.thinking-details');
    const toggle = indicator.querySelector('.thinking-toggle');

    if (details.style.display === 'none' || !details.style.display) {
        details.style.display = 'block';
        toggle.textContent = '▲';
    } else {
        details.style.display = 'none';
        toggle.textContent = '▼';
    }
}

// Update thinking status
function updateThinkingStatus(id, status, type = 'info') {
    const indicator = document.getElementById(id);
    if (!indicator) return;

    const statusLog = indicator.querySelector('.thinking-status-log');
    if (!statusLog) return;

    const timestamp = new Date().toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
    });

    const statusEntry = document.createElement('div');
    statusEntry.className = `thinking-status-entry ${type}`;

    const icon = type === 'success' ? '✅' : type === 'error' ? '❌' : type === 'warning' ? '⚠️' : '🔄';
    statusEntry.innerHTML = `
        <span class="status-time">${timestamp}</span>
        <span class="status-icon">${icon}</span>
        <span class="status-text">${escapeHtml(status)}</span>
    `;

    statusLog.appendChild(statusEntry);

    // Auto-scroll status log
    statusLog.scrollTop = statusLog.scrollHeight;
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

    // Add timestamp to all messages
    const timestamp = new Date().toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
    });
    const header = document.createElement('div');
    header.className = 'message-header';
    if (type !== 'error' && model) {
        header.textContent = `${model} • ${timestamp}`;
    } else {
        header.textContent = timestamp;
    }
    messageDiv.appendChild(header);

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
                        <div class="scan-section-content">${scan.blocked ? `❌ Blocked - ${escapeHtml(scan.blockReason || 'Content blocked by AI Guard')}` : escapeHtml(scan.response)}</div>
                    </div>
                    ${scan.aiGuardResults ? `
                        <div class="scan-section">
                            <div class="scan-section-title">AI Guard Validation</div>
                            <div class="aiguard-validation">
                                ${scan.aiGuardResults.inputValidation ? `
                                    <div class="validation-item">
                                        <div class="validation-label">Input Validation:</div>
                                        <div class="validation-result ${scan.aiGuardResults.inputValidation.action === 'Allow' ? 'allowed' : 'blocked'}">
                                            ${scan.aiGuardResults.inputValidation.action === 'Allow' ? '✅ Allowed' : '❌ Blocked'}
                                        </div>
                                        ${scan.aiGuardResults.inputValidation.resultId ? `
                                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                                                Result ID: ${scan.aiGuardResults.inputValidation.resultId}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.inputValidation.riskScore !== null && scan.aiGuardResults.inputValidation.riskScore !== undefined ? `
                                            <div style="font-size: 0.8rem; margin-top: 4px;">
                                                Risk Score: <strong>${scan.aiGuardResults.inputValidation.riskScore}</strong>
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.inputValidation.categories && scan.aiGuardResults.inputValidation.categories.length > 0 ? `
                                            <div style="font-size: 0.8rem; margin-top: 4px;">
                                                Categories: ${scan.aiGuardResults.inputValidation.categories.join(', ')}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.inputValidation.reasons && scan.aiGuardResults.inputValidation.reasons.length > 0 ? `
                                            <div class="validation-reasons">
                                                <strong>Reasons:</strong> ${scan.aiGuardResults.inputValidation.reasons.join(', ')}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.inputValidation.warning ? `
                                            <div class="validation-warning">⚠️ ${scan.aiGuardResults.inputValidation.warning}</div>
                                        ` : ''}
                                    </div>
                                ` : '<div class="validation-item">Input: Not validated</div>'}
                                ${scan.aiGuardResults.outputValidation ? `
                                    <div class="validation-item">
                                        <div class="validation-label">Output Validation:</div>
                                        <div class="validation-result ${scan.aiGuardResults.outputValidation.action === 'Allow' ? 'allowed' : 'blocked'}">
                                            ${scan.aiGuardResults.outputValidation.action === 'Allow' ? '✅ Allowed' : '❌ Blocked'}
                                        </div>
                                        ${scan.aiGuardResults.outputValidation.resultId ? `
                                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 4px;">
                                                Result ID: ${scan.aiGuardResults.outputValidation.resultId}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.outputValidation.riskScore !== null && scan.aiGuardResults.outputValidation.riskScore !== undefined ? `
                                            <div style="font-size: 0.8rem; margin-top: 4px;">
                                                Risk Score: <strong>${scan.aiGuardResults.outputValidation.riskScore}</strong>
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.outputValidation.categories && scan.aiGuardResults.outputValidation.categories.length > 0 ? `
                                            <div style="font-size: 0.8rem; margin-top: 4px;">
                                                Categories: ${scan.aiGuardResults.outputValidation.categories.join(', ')}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.outputValidation.reasons && scan.aiGuardResults.outputValidation.reasons.length > 0 ? `
                                            <div class="validation-reasons">
                                                <strong>Reasons:</strong> ${scan.aiGuardResults.outputValidation.reasons.join(', ')}
                                            </div>
                                        ` : ''}
                                        ${scan.aiGuardResults.outputValidation.warning ? `
                                            <div class="validation-warning">⚠️ ${scan.aiGuardResults.outputValidation.warning}</div>
                                        ` : ''}
                                    </div>
                                ` : '<div class="validation-item">Output: Not validated</div>'}
                            </div>
                        </div>
                    ` : ''}
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

// Load all models in a table view (Ollama only)
async function loadAllModelsTable() {
    if (config.provider !== 'ollama') {
        return;
    }

    const modelsTableContainer = document.getElementById('modelsTableContainer');
    if (!modelsTableContainer) return;

    modelsTableContainer.innerHTML = '<div class="models-table-loading">Loading models...</div>';

    try {
        const response = await fetch('/api/ollama/models/all', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint
            })
        });

        if (!response.ok) throw new Error('Failed to load models');

        const data = await response.json();

        if (data.models.length === 0) {
            modelsTableContainer.innerHTML = '<div class="models-table-empty">No models available. Download a model to get started.</div>';
        } else {
            renderModelsTable(data.models, data.stats);
        }
    } catch (error) {
        console.error('Error loading models table:', error);
        modelsTableContainer.innerHTML = '<div class="models-table-empty">Error loading models: ' + escapeHtml(error.message) + '</div>';
    }
}

// Render models table
function renderModelsTable(models, stats) {
    const modelsTableContainer = document.getElementById('modelsTableContainer');
    if (!modelsTableContainer) return;

    modelsTableContainer.innerHTML = `
        <div class="models-stats">
            <div class="models-stat-item">
                <span class="models-stat-label">Total Models:</span>
                <span class="models-stat-value">${stats.total}</span>
            </div>
            <div class="models-stat-item">
                <span class="models-stat-label">Loaded:</span>
                <span class="models-stat-value">${stats.loaded}</span>
            </div>
            <div class="models-stat-item">
                <span class="models-stat-label">VRAM Used:</span>
                <span class="models-stat-value">${stats.totalVramGb} GB</span>
            </div>
            <div class="models-stat-item">
                <span class="models-stat-label">Total Memory:</span>
                <span class="models-stat-value">${stats.totalMemoryGb} GB</span>
            </div>
            <div class="models-stat-item">
                <span class="models-stat-label">Available Memory:</span>
                <span class="models-stat-value">${stats.availableMemoryGb} GB</span>
            </div>
        </div>
        <div class="models-table-wrapper">
            <table class="models-table">
                <thead>
                    <tr>
                        <th>Model Name</th>
                        <th>Size</th>
                        <th>Status</th>
                        <th>VRAM</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${models.map(model => `
                        <tr class="${model.loaded ? 'model-loaded' : ''}">
                            <td class="model-name-cell">
                                <div class="model-name-text">${escapeHtml(model.name)}</div>
                                <div class="model-digest">${model.digest ? model.digest.substring(0, 12) + '...' : ''}</div>
                            </td>
                            <td>${model.size_gb} GB</td>
                            <td>
                                ${model.loaded
                                    ? '<span class="status-badge status-loaded">Loaded</span>'
                                    : '<span class="status-badge status-available">Available</span>'}
                            </td>
                            <td>${model.loaded ? model.loaded_info.size_vram_gb + ' GB' : '-'}</td>
                            <td class="model-actions-cell">
                                ${model.loaded
                                    ? `<button class="btn-table-action btn-unload-table" onclick="unloadModelFromTable('${escapeHtml(model.name)}')">Unload</button>`
                                    : `<button class="btn-table-action btn-load-table" onclick="loadModelFromTable('${escapeHtml(model.name)}')">Load</button>`
                                }
                                <button class="btn-table-action btn-delete-table" onclick="deleteModelFromTable('${escapeHtml(model.name)}')">Delete</button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Load model from table
async function loadModelFromTable(modelName) {
    const row = Array.from(document.querySelectorAll('.models-table tbody tr')).find(
        tr => tr.querySelector('.model-name-text').textContent === modelName
    );

    if (row) {
        const loadBtn = row.querySelector('.btn-load-table');
        if (loadBtn) {
            loadBtn.disabled = true;
            loadBtn.textContent = 'Loading...';
        }
    }

    try {
        const response = await fetch('/api/ollama/load', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint,
                model: modelName
            })
        });

        const data = await response.json();

        if (response.ok && data.success) {
            await new Promise(resolve => setTimeout(resolve, 1000));
            await loadAllModelsTable();
        } else {
            alert(`Failed to load ${modelName}: ${data.error || data.message || 'Unknown error'}`);
            if (row) {
                const loadBtn = row.querySelector('.btn-load-table');
                if (loadBtn) {
                    loadBtn.disabled = false;
                    loadBtn.textContent = 'Load';
                }
            }
        }
    } catch (error) {
        console.error('Error loading model:', error);
        alert(`Error loading model: ${error.message}`);
        if (row) {
            const loadBtn = row.querySelector('.btn-load-table');
            if (loadBtn) {
                loadBtn.disabled = false;
                loadBtn.textContent = 'Load';
            }
        }
    }
}

// Unload model from table
async function unloadModelFromTable(modelName) {
    if (!confirm(`Unload ${modelName} from memory?`)) {
        return;
    }

    const row = Array.from(document.querySelectorAll('.models-table tbody tr')).find(
        tr => tr.querySelector('.model-name-text').textContent === modelName
    );

    if (row) {
        const unloadBtn = row.querySelector('.btn-unload-table');
        if (unloadBtn) {
            unloadBtn.disabled = true;
            unloadBtn.textContent = 'Unloading...';
        }
    }

    try {
        const response = await fetch('/api/ollama/unload', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint,
                model: modelName
            })
        });

        const data = await response.json();

        if (data.success) {
            await new Promise(resolve => setTimeout(resolve, 1000));
            await loadAllModelsTable();
        } else {
            alert(`Failed to unload ${modelName}: ${data.message || 'Unknown error'}`);
            if (row) {
                const unloadBtn = row.querySelector('.btn-unload-table');
                if (unloadBtn) {
                    unloadBtn.disabled = false;
                    unloadBtn.textContent = 'Unload';
                }
            }
        }
    } catch (error) {
        console.error('Error unloading model:', error);
        alert(`Error unloading model: ${error.message}`);
        if (row) {
            const unloadBtn = row.querySelector('.btn-unload-table');
            if (unloadBtn) {
                unloadBtn.disabled = false;
                unloadBtn.textContent = 'Unload';
            }
        }
    }
}

// Delete model from table
async function deleteModelFromTable(modelName) {
    if (!confirm(`Are you sure you want to permanently delete "${modelName}"?\n\nThis will remove the model from Ollama.`)) {
        return;
    }

    const row = Array.from(document.querySelectorAll('.models-table tbody tr')).find(
        tr => tr.querySelector('.model-name-text').textContent === modelName
    );

    if (row) {
        const deleteBtn = row.querySelector('.btn-delete-table');
        if (deleteBtn) {
            deleteBtn.disabled = true;
            deleteBtn.textContent = 'Deleting...';
        }
    }

    try {
        const response = await fetch('/api/ollama/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                modelName: modelName,
                endpoint: config.endpoint
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Delete failed');
        }

        await loadAllModelsTable();
        await loadModels(); // Refresh the model dropdown too
    } catch (error) {
        console.error('Model delete error:', error);
        alert(`Delete failed: ${error.message}`);
        if (row) {
            const deleteBtn = row.querySelector('.btn-delete-table');
            if (deleteBtn) {
                deleteBtn.disabled = false;
                deleteBtn.textContent = 'Delete';
            }
        }
    }
}

// Load loaded models (Ollama only) - LEGACY FUNCTION
async function loadLoadedModels() {
    if (config.provider !== 'ollama') {
        return;
    }

    const loadedModelsList = document.getElementById('loadedModelsList');
    if (!loadedModelsList) return;

    loadedModelsList.innerHTML = '<div class="loaded-models-empty">Loading...</div>';

    try {
        const response = await fetch('/api/ollama/loaded', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint
            })
        });

        if (!response.ok) throw new Error('Failed to load models');

        const data = await response.json();

        if (data.count === 0) {
            loadedModelsList.innerHTML = '<div class="loaded-models-empty">No models currently loaded in memory</div>';
        } else {
            loadedModelsList.innerHTML = data.models.map(model => `
                <div class="loaded-model-item">
                    <div class="loaded-model-info">
                        <div class="loaded-model-name">${escapeHtml(model.name)}</div>
                        <div class="loaded-model-details">
                            <span class="loaded-model-vram">💾 ${model.size_vram_gb} GB VRAM</span>
                            <span>⏱️ Expires: ${new Date(model.expires_at).toLocaleTimeString()}</span>
                        </div>
                    </div>
                    <button class="btn-unload" onclick="unloadModel('${escapeHtml(model.name)}')">Unload</button>
                </div>
            `).join('');

            // Add summary
            const summary = document.createElement('div');
            summary.className = 'loaded-models-summary';
            summary.innerHTML = `
                <span><strong>Total Models:</strong> ${data.count}</span>
                <span><strong>Total VRAM:</strong> ${data.totalVramGb} GB</span>
            `;
            loadedModelsList.appendChild(summary);
        }
    } catch (error) {
        console.error('Error loading models:', error);
        loadedModelsList.innerHTML = '<div class="loaded-models-empty">Error loading models: ' + escapeHtml(error.message) + '</div>';
    }
}

// Unload a specific model
async function unloadModel(modelName) {
    if (!confirm(`Are you sure you want to unload ${modelName}?`)) {
        return;
    }

    // Disable all unload buttons during the operation
    const unloadButtons = document.querySelectorAll('.btn-unload');
    unloadButtons.forEach(btn => btn.disabled = true);

    try {
        const response = await fetch('/api/ollama/unload', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint,
                model: modelName
            })
        });

        const data = await response.json();

        if (data.success) {
            // Wait a moment for Ollama to fully unload the model
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Refresh the list
            await loadLoadedModels();
            alert(`Successfully unloaded ${modelName}`);
        } else {
            alert(`Failed to unload ${modelName}: ${data.message || 'Unknown error'}`);
            // Re-enable buttons on failure
            unloadButtons.forEach(btn => btn.disabled = false);
        }
    } catch (error) {
        console.error('Error unloading model:', error);
        alert(`Error unloading model: ${error.message}`);
        // Re-enable buttons on error
        unloadButtons.forEach(btn => btn.disabled = false);
    }
}

// Load a specific model
async function handleLoadModel() {
    const modelToLoadSelect = document.getElementById('modelToLoad');
    const modelName = modelToLoadSelect.value;

    if (!modelName) {
        alert('Please select a model to load');
        return;
    }

    const loadModelButton = document.getElementById('loadModelButton');
    const originalText = loadModelButton.textContent;

    // Disable button and show loading state
    loadModelButton.disabled = true;
    loadModelButton.textContent = 'Loading...';

    try {
        const response = await fetch('/api/ollama/load', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint,
                model: modelName
            })
        });

        const data = await response.json();

        if (response.ok && data.success) {
            // Wait a moment for Ollama to fully load the model
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Refresh the loaded models list
            await loadLoadedModels();

            // Reset the dropdown
            modelToLoadSelect.value = '';

            alert(`Successfully loaded ${modelName}`);
        } else {
            alert(`Failed to load ${modelName}: ${data.error || data.message || 'Unknown error'}`);
        }
    } catch (error) {
        console.error('Error loading model:', error);
        alert(`Error loading model: ${error.message}`);
    } finally {
        // Re-enable button and restore text
        loadModelButton.disabled = false;
        loadModelButton.textContent = originalText;
    }
}

// Pull/Download a model
async function handlePullModel() {
    const modelToPullInput = document.getElementById('modelToPull');
    const modelName = modelToPullInput.value.trim();

    if (!modelName) {
        alert('Please enter a model name to download');
        return;
    }

    const pullModelButton = document.getElementById('pullModelButton');
    const pullProgress = document.getElementById('pullProgress');
    const pullProgressBar = document.getElementById('pullProgressBar');
    const pullStatus = document.getElementById('pullStatus');
    const originalText = pullModelButton.textContent;

    // Disable button and show progress
    pullModelButton.disabled = true;
    pullModelButton.textContent = 'Downloading...';
    pullProgress.style.display = 'block';
    pullProgressBar.style.width = '0%';
    pullStatus.textContent = 'Initializing download...';

    try {
        const response = await fetch('/api/ollama/pull', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                endpoint: config.endpoint,
                model: modelName
            })
        });

        if (!response.ok) {
            throw new Error('Failed to start download');
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
            const { done, value } = await reader.read();

            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const data = JSON.parse(line.slice(6));

                        if (data.status === 'complete') {
                            pullProgressBar.style.width = '100%';
                            pullStatus.textContent = 'Download complete!';

                            // Refresh models list
                            await loadModels();

                            // Clear input and hide progress after a delay
                            setTimeout(() => {
                                modelToPullInput.value = '';
                                pullProgress.style.display = 'none';
                                alert(`Successfully downloaded ${modelName}`);
                            }, 1500);

                            break;
                        } else if (data.status === 'error') {
                            throw new Error(data.error || 'Download failed');
                        } else if (data.status) {
                            // Update progress
                            const status = data.status;
                            let percentage = 0;

                            if (data.completed && data.total) {
                                percentage = Math.round((data.completed / data.total) * 100);
                                pullProgressBar.style.width = percentage + '%';
                                pullProgressBar.textContent = percentage + '%';
                            }

                            pullStatus.textContent = status + (data.digest ? ` (${data.digest.slice(0, 12)}...)` : '');
                        }
                    } catch (e) {
                        console.error('Error parsing SSE data:', e);
                    }
                }
            }
        }
    } catch (error) {
        console.error('Error pulling model:', error);
        pullStatus.textContent = 'Error: ' + error.message;
        pullProgressBar.style.width = '0%';
        alert(`Error downloading model: ${error.message}`);
    } finally {
        // Re-enable button and restore text
        pullModelButton.disabled = false;
        pullModelButton.textContent = originalText;
    }
}

// Make functions globally accessible for onclick handlers
window.toggleThinkingDetails = toggleThinkingDetails;
window.removeFile = removeFile;
window.unloadModel = unloadModel;
window.loadModelFromTable = loadModelFromTable;
window.unloadModelFromTable = unloadModelFromTable;
window.deleteModelFromTable = deleteModelFromTable;
window.toggleVulnDetails = toggleVulnDetails;
window.toggleRawOutput = toggleRawOutput;

// Start the app
init();
