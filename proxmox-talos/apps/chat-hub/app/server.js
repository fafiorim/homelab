const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Chat endpoint - proxy to various LLM providers
app.post('/api/chat', async (req, res) => {
  const { provider, endpoint, apiKey, model, messages } = req.body;

  try {
    let response;

    if (provider === 'ollama') {
      // Ollama format
      response = await axios.post(`${endpoint}/api/chat`, {
        model: model,
        messages: messages,
        stream: false
      });
      res.json({
        message: response.data.message.content,
        model: response.data.model
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

      const payload = provider === 'anthropic'
        ? {
            model: model,
            messages: messages,
            max_tokens: 4096
          }
        : {
            model: model,
            messages: messages
          };

      response = await axios.post(endpoint, payload, { headers });

      const content = provider === 'anthropic'
        ? response.data.content[0].text
        : response.data.choices[0].message.content;

      res.json({
        message: content,
        model: response.data.model
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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Chat Hub server running on port ${PORT}`);
});
