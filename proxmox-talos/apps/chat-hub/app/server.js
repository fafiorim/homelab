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

    const action = response.data.action;
    const reasons = response.data.reasons || [];

    if (action === 'Block') {
      return {
        allowed: false,
        reasons: reasons,
        message: `AI Guard blocked this content: ${reasons.join(', ')}`
      };
    }

    return { allowed: true };

  } catch (error) {
    console.error('AI Guard Error:', error.response?.data || error.message);
    // On AI Guard error, allow the request to proceed but log the error
    return {
      allowed: true,
      warning: 'AI Guard validation failed - proceeding without validation'
    };
  }
}

// Chat endpoint - proxy to various LLM providers
app.post('/api/chat', async (req, res) => {
  const { provider, endpoint, apiKey, model, messages, aiGuard } = req.body;

  // Track AI Guard validation results
  const aiGuardResults = {
    enabled: aiGuard && aiGuard.enabled,
    inputValidation: null,
    outputValidation: null
  };

  try {
    // Step 1: Validate user input with AI Guard (if enabled)
    if (aiGuard && aiGuard.enabled) {
      const userMessage = messages[messages.length - 1].content;
      const inputValidation = await validateWithAIGuard(userMessage, aiGuard);

      aiGuardResults.inputValidation = {
        action: inputValidation.allowed ? 'Allow' : 'Block',
        reasons: inputValidation.reasons || [],
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

    // Step 2: Call LLM provider
    let response;

    if (provider === 'ollama') {
      // Ollama format
      response = await axios.post(`${endpoint}/api/chat`, {
        model: model,
        messages: messages,
        stream: false
      });

      const content = response.data.message.content;
      const modelName = response.data.model;

      // Step 3: Validate LLM output with AI Guard (if enabled)
      if (aiGuard && aiGuard.enabled) {
        const outputValidation = await validateWithAIGuard(content, aiGuard);

        aiGuardResults.outputValidation = {
          action: outputValidation.allowed ? 'Allow' : 'Block',
          reasons: outputValidation.reasons || [],
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

      const modelName = response.data.model;

      // Step 3: Validate LLM output with AI Guard (if enabled)
      if (aiGuard && aiGuard.enabled) {
        const outputValidation = await validateWithAIGuard(content, aiGuard);

        aiGuardResults.outputValidation = {
          action: outputValidation.allowed ? 'Allow' : 'Block',
          reasons: outputValidation.reasons || [],
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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Chat Hub server running on port ${PORT}`);
});
