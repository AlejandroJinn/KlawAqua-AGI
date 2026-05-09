const http = require('http');
const PORT = 8889;
const CONVERSATIONS = {};
const MODELS = ['qwen3.5:4b','nemotron-free','laguna-free','qwen3-coder-free','gemma4-free','laguna-xs-free','llama-3.2-free','qwen3-next-free','minimax-free','hy3-free','gpt-oss-free'];

function queryLiteLLM(model, messages, cb) {
  const data = JSON.stringify({model, messages, stream: false, max_tokens: 2048, timeout: 120});
  const req = http.request({hostname:'localhost',port:4000,path:'/v1/chat/completions',method:'POST',headers:{'Content-Type':'application/json'},timeout:120000}, (res) => {
    let body = '';
    res.on('data', c => body += c);
    res.on('end', () => {
      try {
        const json = JSON.parse(body);
        if (json.choices?.[0]?.message?.content) cb(null, json.choices[0].message.content, model);
        else if (json.error) cb(new Error(json.error.message || 'no response'));
        else cb(new Error('empty response'));
      } catch(e) { cb(new Error('parse error')); }
    });
  });
  req.on('error', () => cb(new Error('connection failed')));
  req.on('timeout', () => { req.destroy(); cb(new Error('timeout')); });
  req.write(data); req.end();
}

function smartReply(prompt, modelIndex, messages, cb) {
  queryLiteLLM(MODELS[modelIndex], messages, (err, reply, model) => {
    if (err && modelIndex < MODELS.length - 1) {
      console.log('[fallback] ' + model + ' error -> trying next');
      smartReply(prompt, modelIndex + 1, messages, cb);
    } else if (err) {
      cb(new Error('All models failed'));
    } else {
      cb(null, reply, model);
    }
  });
}

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }
  if (req.method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const prompt = data.prompt || data.message;
        const convId = data.conversation_id || 'default';
        if (!prompt) { res.writeHead(400); res.end(JSON.stringify({error:'Missing prompt'})); return; }
        if (!CONVERSATIONS[convId]) CONVERSATIONS[convId] = [];
        CONVERSATIONS[convId].push({role:'user',content:prompt});
        smartReply(prompt, 0, CONVERSATIONS[convId], (err, reply, model) => {
          if (err) { res.writeHead(500); res.end(JSON.stringify({error:err.message})); return; }
          CONVERSATIONS[convId].push({role:'assistant',content:reply});
          res.writeHead(200); res.end(JSON.stringify({reply,model,conversation_id:convId,success:true}));
        });
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:e.message})); }
    });
  } else if (req.method === 'GET') {
    res.writeHead(200); res.end(JSON.stringify({status:'ok',port:PORT,models:MODELS.length}));
  } else { res.writeHead(405); res.end(JSON.stringify({error:'Method not allowed'})); }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('KlawAqua Local Chat running on ' + PORT);
  console.log('Usage: POST {prompt: "hello", conversation_id: "chat1"}');
});