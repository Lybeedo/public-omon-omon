// Simple test app for OpenCode Go vision models
// Usage: node test-vision.js

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// ── CONFIG ──────────────────────────────────────────────────────────
const API_URL = process.env.OPENCODE_GO_API_URL || 'http://62.169.26.143:20128/v1';
const API_KEY = process.env.OPENCODE_GO_API_KEY || 'your-api-key';
const TEST_IMAGE = process.env.TEST_IMAGE || 'https://raw.githubusercontent.com/decolua/9router/master/images/9router.png';

// Vision-capable models to test (based on skill.md research)
const VISION_MODELS = [
  { name: 'kimi-k2.6',       model: 'opencode-go/kimi-k2.6',       provider: 'Moonshot AI' },
  { name: 'kimi-k2.5',       model: 'opencode-go/kimi-k2.5',       provider: 'Moonshot AI' },
  { name: 'minimax-m2.7',    model: 'opencode-go/minimax-m2.7',    provider: 'MiniMax' },
  { name: 'minimax-m2.5',    model: 'opencode-go/minimax-m2.5',    provider: 'MiniMax' },
];

// Text-only models to verify (should fail on image)
const TEXT_MODELS = [
  { name: 'glm-5.1',         model: 'opencode-go/glm-5.1',         provider: 'Z.ai' },
  { name: 'glm-5',           model: 'opencode-go/glm-5',             provider: 'Z.ai' },
  { name: 'qwen3.6-plus',    model: 'opencode-go/qwen3.6-plus',     provider: 'Alibaba' },
  { name: 'qwen3.5-plus',    model: 'opencode-go/qwen3.5-plus',     provider: 'Alibaba' },
  { name: 'deepseek-v4',     model: 'deepseek-ai/DeepSeek-V4',      provider: 'DeepSeek' },
];

// ── HELPERS ─────────────────────────────────────────────────────────

function fetchImageAsBase64(imageUrl) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(imageUrl);
    const protocol = urlObj.protocol === 'https:' ? https : http;
    
    protocol.get(imageUrl, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Failed to fetch image: ${res.statusCode}`));
        return;
      }
      
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        const ext = path.extname(imageUrl).toLowerCase() || '.png';
        const mimeTypes = {
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.png': 'image/png',
          '.gif': 'image/gif',
          '.webp': 'image/webp',
        };
        const mime = mimeTypes[ext] || 'image/png';
        resolve({ base64: buffer.toString('base64'), mime });
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

function callOpenCode(model, imageBase64, mime) {
  return new Promise((resolve, reject) => {
    const payload = {
      model: model,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Look at this image and tell me what you see. Describe the main elements in one short sentence.'
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:${mime};base64,${imageBase64}`
              }
            }
          ]
        }
      ],
      max_tokens: 100,
      temperature: 0.7
    };

    const data = JSON.stringify(payload);
    const urlObj = new URL(API_URL);
    
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
      path: urlObj.pathname,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    };

    const protocol = urlObj.protocol === 'https:' ? https : http;
    const req = protocol.request(options, (res) => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        try {
          const response = JSON.parse(Buffer.concat(chunks).toString());
          if (response.error) {
            reject(new Error(`API Error: ${response.error.message || JSON.stringify(response.error)}`));
          } else {
            resolve(response.choices?.[0]?.message?.content || 'No response');
          }
        } catch (e) {
          reject(new Error(`Parse error: ${e.message}`));
        }
      });
      res.on('error', reject);
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// ── MAIN TEST ───────────────────────────────────────────────────────

async function runTests() {
  console.log('
========================================');
  console.log(' OpenCode Go - Vision Model Tester');
  console.log('========================================');
  console.log(`API URL: ${API_URL}`);
  console.log(`Test Image: ${TEST_IMAGE}
`);
  
  console.log('Fetching test image...');
  let imageData;
  try {
    imageData = await fetchImageAsBase64(TEST_IMAGE);
    console.log(`Image loaded: ${(imageData.base64.length / 1024).toFixed(1)} KB (base64)
`);
  } catch (e) {
    console.error(`Failed to fetch image: ${e.message}`);
    process.exit(1);
  }

  // Test vision models
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(' VISION-CAPABLE MODELS (should work)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  for (const m of VISION_MODELS) {
    process.stdout.write(`[${m.name}] ${m.provider}... `);
    try {
      const result = await callOpenCode(m.model, imageData.base64, imageData.mime);
      console.log(`✅ PASS
      → "${result.substring(0, 80)}..."
`);
    } catch (e) {
      const errMsg = e.message.includes('500') ? '❌ HTTP 500 (no vision)' : 
                     e.message.includes('400') ? '⚠️ HTTP 400 (bad request)' : 
                     e.message.includes('403') ? '❌ HTTP 403 (forbidden)' : '❌';
      console.log(`${errMsg} ${e.message.substring(0, 60)}
`);
    }
  }

  // Test text models (should fail)
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(' TEXT-ONLY MODELS (should fail/vision)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  for (const m of TEXT_MODELS) {
    process.stdout.write(`[${m.name}] ${m.provider}... `);
    try {
      const result = await callOpenCode(m.model, imageData.base64, imageData.mime);
      console.log(`⚠️  Unexpectedly worked!
      → "${result.substring(0, 80)}..."
`);
    } catch (e) {
      const errMsg = e.message.includes('500') ? '❌ HTTP 500 (no vision)' : 
                     e.message.includes('400') ? '✅ HTTP 400 (rejected)' : 
                     e.message.includes('403') ? '❌ HTTP 403' : '❌';
      console.log(`${errMsg} ${e.message.substring(0, 60)}
`);
    }
  }

  console.log('========================================');
  console.log(' Done! Legend:');
  console.log('  ✅ = Vision works');
  console.log('  ❌ = Vision not supported');
  console.log('  ⚠️  = Unexpected result');
  console.log('========================================
');
}

runTests().catch(console.error);
