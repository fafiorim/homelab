const express = require('express');
const axios = require('axios');
const path = require('path');
const pdfParse = require('pdf-parse');

const app = express();
const PORT = process.env.PORT || 3000;

// Increase body size limit for file uploads (default is 100kb)
// 50mb should be enough for base64-encoded files (max 20MB file = ~27MB base64)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// AI Guard validation function
async function validateWithAIGuard(content, aiGuardConfig, requestType = 'SimpleRequestGuardrails') {
  if (!aiGuardConfig || !aiGuardConfig.enabled || !aiGuardConfig.apiKey) {
    return { allowed: true }; // Skip if AI Guard not configured
  }

  const { apiKey, region, appName } = aiGuardConfig;

  // US region doesn't use region prefix, other regions do
  const regionPrefix = region === 'us' ? '' : `.${region}`;
  const endpoint = `https://api${regionPrefix}.xdr.trendmicro.com/v3.0/aiSecurity/applyGuardrails`;

  try {
    const response = await axios.post(
      endpoint,
      { prompt: content },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'TMV1-Application-Name': appName,
          'Content-Type': 'application/json'
        }
      }
    );

    // Log full response for analysis
    console.log('AI Guard Full Response:', JSON.stringify(response.data, null, 2));

    const action = response.data.action;
    const reasons = response.data.reasons || [];
    const resultId = response.data.resultId || response.data.id || null;
    const riskScore = response.data.riskScore || null;
    const categories = response.data.categories || [];

    if (action === 'Block') {
      return {
        allowed: false,
        reasons: reasons,
        resultId: resultId,
        riskScore: riskScore,
        categories: categories,
        fullResponse: response.data,
        message: `AI Guard blocked this content: ${reasons.join(', ')}`
      };
    }

    return {
      allowed: true,
      resultId: resultId,
      riskScore: riskScore,
      fullResponse: response.data
    };

  } catch (error) {
    console.error('AI Guard Error:', error.response?.data || error.message);
    // On AI Guard error, allow the request to proceed but log the error
    return {
      allowed: true,
      warning: 'AI Guard validation failed - proceeding without validation'
    };
  }
}

// Extract text from PDF file
async function extractPdfText(base64Data) {
  try {
    // Convert base64 to buffer
    const pdfBuffer = Buffer.from(base64Data, 'base64');

    // Parse PDF
    const data = await pdfParse(pdfBuffer);

    return data.text;
  } catch (error) {
    console.error('PDF extraction error:', error.message);
    return null;
  }
}

// Format messages with files for different providers
function formatMessagesWithFiles(provider, messages, files) {
  if (!files || files.length === 0) {
    return messages;
  }

  // For Anthropic Claude, format with content array
  if (provider === 'anthropic') {
    const lastMessage = messages[messages.length - 1];
    const formattedLastMessage = {
      role: lastMessage.role,
      content: []
    };

    // Add text content if present
    const textContent = lastMessage.content.replace(/\[Attached:.*?\]/g, '').trim();
    if (textContent) {
      formattedLastMessage.content.push({
        type: 'text',
        text: textContent
      });
    }

    // Add file content
    files.forEach(file => {
      if (file.type.startsWith('image/')) {
        formattedLastMessage.content.push({
          type: 'image',
          source: {
            type: 'base64',
            media_type: file.type,
            data: file.data
          }
        });
      } else if (file.type === 'application/pdf') {
        formattedLastMessage.content.push({
          type: 'document',
          source: {
            type: 'base64',
            media_type: 'application/pdf',
            data: file.data
          }
        });
      }
    });

    return [...messages.slice(0, -1), formattedLastMessage];
  }

  // For OpenAI (GPT-4 Vision), format with content array
  if (provider === 'openai') {
    const lastMessage = messages[messages.length - 1];
    const formattedLastMessage = {
      role: lastMessage.role,
      content: []
    };

    // Add text content if present
    const textContent = lastMessage.content.replace(/\[Attached:.*?\]/g, '').trim();
    if (textContent) {
      formattedLastMessage.content.push({
        type: 'text',
        text: textContent
      });
    }

    // Add image content (OpenAI only supports images in vision models)
    files.forEach(file => {
      if (file.type.startsWith('image/')) {
        formattedLastMessage.content.push({
          type: 'image_url',
          image_url: {
            url: `data:${file.type};base64,${file.data}`
          }
        });
      }
    });

    return [...messages.slice(0, -1), formattedLastMessage];
  }

  // For Ollama with vision models, format with images array
  if (provider === 'ollama') {
    // Ollama vision models use a separate images array
    // We'll handle this in the Ollama-specific code
    return messages;
  }

  return messages;
}

// Chat endpoint - proxy to various LLM providers
app.post('/api/chat', async (req, res) => {
  const { provider, endpoint, apiKey, model, messages, files, aiGuard } = req.body;

  // Track AI Guard validation results
  const aiGuardResults = {
    enabled: aiGuard && aiGuard.enabled,
    inputValidation: null,
    outputValidation: null
  };

  try {
    // Step 1: Extract text from PDF files and append to message
    if (files && files.length > 0) {
      const pdfFiles = files.filter(f => f.type === 'application/pdf');

      if (pdfFiles.length > 0) {
        let extractedTexts = [];

        for (const pdfFile of pdfFiles) {
          const text = await extractPdfText(pdfFile.data);
          if (text) {
            extractedTexts.push(`\n\n--- Content from ${pdfFile.name || 'PDF'} ---\n${text}\n--- End of ${pdfFile.name || 'PDF'} ---\n`);
          }
        }

        // Append extracted text to the last message
        if (extractedTexts.length > 0) {
          const lastMessage = messages[messages.length - 1];
          lastMessage.content = lastMessage.content + extractedTexts.join('\n');
        }
      }
    }

    // Step 2: Validate user input with AI Guard (if enabled)
    if (aiGuard && aiGuard.enabled) {
      const userMessage = messages[messages.length - 1].content;
      const inputValidation = await validateWithAIGuard(userMessage, aiGuard);

      aiGuardResults.inputValidation = {
        action: inputValidation.allowed ? 'Allow' : 'Block',
        reasons: inputValidation.reasons || [],
        resultId: inputValidation.resultId,
        riskScore: inputValidation.riskScore,
        categories: inputValidation.categories || [],
        warning: inputValidation.warning
      };

      if (!inputValidation.allowed) {
        return res.status(400).json({
          error: inputValidation.message,
          aiGuardBlocked: true,
          reasons: inputValidation.reasons,
          aiGuardResults
        });
      }
    }

    // Step 3: Call LLM provider
    let response;

    if (provider === 'ollama') {
      // Ollama format
      const payload = {
        model: model,
        messages: messages,
        stream: false
      };

      // Add images array for vision/OCR models (llava, bakllava, etc.)
      // Some OCR models can accept PDFs directly in the images array
      if (files && files.length > 0) {
        const images = files
          .filter(f => f.type.startsWith('image/') || f.type === 'application/pdf')
          .map(f => f.data);

        if (images.length > 0) {
          payload.images = images;
        }
      }

      response = await axios.post(`${endpoint}/api/chat`, payload);

      const content = response.data.message.content;
      const modelName = response.data.model;

      // Step 4: Validate LLM output with AI Guard (if enabled)
      if (aiGuard && aiGuard.enabled) {
        const outputValidation = await validateWithAIGuard(content, aiGuard);

        aiGuardResults.outputValidation = {
          action: outputValidation.allowed ? 'Allow' : 'Block',
          reasons: outputValidation.reasons || [],
          resultId: outputValidation.resultId,
          riskScore: outputValidation.riskScore,
          categories: outputValidation.categories || [],
          warning: outputValidation.warning
        };

        if (!outputValidation.allowed) {
          return res.status(400).json({
            error: outputValidation.message,
            aiGuardBlocked: true,
            reasons: outputValidation.reasons,
            aiGuardResults
          });
        }
      }

      res.json({
        message: content,
        model: modelName,
        aiGuardResults
      });

    } else if (provider === 'openai' || provider === 'anthropic') {
      // OpenAI/Anthropic format
      const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      };

      if (provider === 'anthropic') {
        headers['anthropic-version'] = '2023-06-01';
      }

      // Format messages with files if present
      const formattedMessages = formatMessagesWithFiles(provider, messages, files);

      const payload = provider === 'anthropic'
        ? {
            model: model,
            messages: formattedMessages,
            max_tokens: 4096
          }
        : {
            model: model,
            messages: formattedMessages
          };

      response = await axios.post(endpoint, payload, { headers });

      // Extract content from response
      let content;
      if (provider === 'anthropic') {
        // Anthropic returns content as an array, extract text blocks
        content = response.data.content
          .filter(block => block.type === 'text')
          .map(block => block.text)
          .join('\n');
      } else {
        // OpenAI returns content as string or null
        content = response.data.choices[0].message.content || '';
      }

      const modelName = response.data.model;

      // Step 4: Validate LLM output with AI Guard (if enabled)
      if (aiGuard && aiGuard.enabled) {
        const outputValidation = await validateWithAIGuard(content, aiGuard);

        aiGuardResults.outputValidation = {
          action: outputValidation.allowed ? 'Allow' : 'Block',
          reasons: outputValidation.reasons || [],
          resultId: outputValidation.resultId,
          riskScore: outputValidation.riskScore,
          categories: outputValidation.categories || [],
          warning: outputValidation.warning
        };

        if (!outputValidation.allowed) {
          return res.status(400).json({
            error: outputValidation.message,
            aiGuardBlocked: true,
            reasons: outputValidation.reasons,
            aiGuardResults
          });
        }
      }

      res.json({
        message: content,
        model: modelName,
        aiGuardResults
      });

    } else {
      res.status(400).json({ error: 'Unsupported provider' });
    }

  } catch (error) {
    console.error('Chat API Error:', error.response?.data || error.message);
    res.status(500).json({
      error: error.response?.data?.error?.message || error.message
    });
  }
});

// Models endpoint - get available models
app.post('/api/models', async (req, res) => {
  const { provider, endpoint, apiKey } = req.body;

  try {
    let response;

    if (provider === 'ollama') {
      response = await axios.get(`${endpoint}/api/tags`);
      const models = response.data.models.map(m => m.name);
      res.json({ models });

    } else if (provider === 'openai') {
      const headers = {
        'Authorization': `Bearer ${apiKey}`
      };
      response = await axios.get(`${endpoint}/models`, { headers });
      const models = response.data.data
        .filter(m => m.id.includes('gpt'))
        .map(m => m.id);
      res.json({ models });

    } else {
      // Return default models for other providers
      res.json({
        models: provider === 'anthropic'
          ? ['claude-3-5-sonnet-20241022', 'claude-3-opus-20240229', 'claude-3-haiku-20240307']
          : []
      });
    }

  } catch (error) {
    console.error('Models API Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// Get loaded models (Ollama only)
app.post('/api/ollama/loaded', async (req, res) => {
  const { endpoint } = req.body;

  try {
    const response = await axios.get(`${endpoint}/api/ps`);
    const loadedModels = response.data.models || [];

    // Format the response with useful information
    const formattedModels = loadedModels.map(model => ({
      name: model.name,
      size_vram: model.size_vram,
      size_vram_gb: (model.size_vram / 1024 / 1024 / 1024).toFixed(2),
      expires_at: model.expires_at,
      digest: model.digest
    }));

    // Calculate total VRAM
    const totalVram = loadedModels.reduce((sum, m) => sum + (m.size_vram || 0), 0);
    const totalVramGb = (totalVram / 1024 / 1024 / 1024).toFixed(2);

    res.json({
      models: formattedModels,
      count: formattedModels.length,
      totalVramGb: totalVramGb
    });
  } catch (error) {
    console.error('Loaded Models API Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// Unload a specific model (Ollama only)
app.post('/api/ollama/unload', async (req, res) => {
  const { endpoint, model } = req.body;

  if (!model) {
    return res.status(400).json({ error: 'Model name is required' });
  }

  try {
    const response = await axios.post(`${endpoint}/api/generate`, {
      model: model,
      keep_alive: 0
    });

    if (response.data.done_reason === 'unload') {
      res.json({
        success: true,
        message: `Successfully unloaded ${model}`
      });
    } else {
      res.json({
        success: false,
        message: 'Model may not have been unloaded',
        response: response.data
      });
    }
  } catch (error) {
    console.error('Unload Model API Error:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// Load a specific model (Ollama only)
app.post('/api/ollama/load', async (req, res) => {
  const { endpoint, model } = req.body;

  if (!model) {
    return res.status(400).json({ error: 'Model name is required' });
  }

  try {
    // Load the model by making a minimal chat request with keep_alive
    const response = await axios.post(`${endpoint}/api/chat`, {
      model: model,
      messages: [{ role: 'user', content: 'ping' }],
      stream: false,
      keep_alive: '5m'
    });

    res.json({
      success: true,
      message: `Successfully loaded ${model}`,
      model: response.data.model
    });
  } catch (error) {
    console.error('Load Model API Error:', error.message);
    res.status(500).json({
      error: error.response?.data?.error || error.message
    });
  }
});

// Pull/Download a model (Ollama only)
app.post('/api/ollama/pull', async (req, res) => {
  const { endpoint, model } = req.body;

  if (!model) {
    return res.status(400).json({ error: 'Model name is required' });
  }

  try {
    // Set headers for SSE-like streaming
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    // Make streaming request to Ollama
    const response = await axios.post(
      `${endpoint}/api/pull`,
      { name: model, stream: true },
      { responseType: 'stream' }
    );

    // Forward the stream to the client
    response.data.on('data', (chunk) => {
      try {
        const data = JSON.parse(chunk.toString());
        res.write(`data: ${JSON.stringify(data)}\n\n`);
      } catch (e) {
        // Handle incomplete JSON chunks
        console.error('Error parsing chunk:', e);
      }
    });

    response.data.on('end', () => {
      res.write('data: {"status":"complete"}\n\n');
      res.end();
    });

    response.data.on('error', (error) => {
      console.error('Stream error:', error);
      res.write(`data: {"status":"error","error":"${error.message}"}\n\n`);
      res.end();
    });

  } catch (error) {
    console.error('Pull Model API Error:', error.message);
    res.status(500).json({
      error: error.response?.data?.error || error.message
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Chat Hub server running on port ${PORT}`);
});
