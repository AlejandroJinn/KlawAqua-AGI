"""Conector LLM para Ollama - integración nativa con KlawAqua-AGI"""
import aiohttp
import json
import os
from typing import Optional, List, Dict, Any

class OllamaLLM:
    """Cliente asíncrono para Ollama con API compatible OpenAI"""
    
    def __init__(
        self,
        base_url: str = None,
        model: str = None,
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ):
        self.base_url = (base_url or os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")).rstrip("/")
        self.model = model or os.getenv("OPENMANUS_MODEL", "qwen3.5:4b")
        self.temperature = temperature
        self.max_tokens = max_tokens
        
    async def generate(
        self,
        prompt: str,
        system: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> str:
        """Genera respuesta usando Ollama API"""
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})
        
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": temperature or self.temperature,
                "num_predict": max_tokens or self.max_tokens,
                "num_ctx": 4096,
            }
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/api/chat",
                    json=payload,
                    timeout=aiohttp.ClientTimeout(total=120)
                ) as resp:
                    if resp.status != 200:
                        error = await resp.text()
                        return f"[ERROR Ollama {resp.status}]: {error[:300]}"
                    data = await resp.json()
                    return data.get("message", {}).get("content", "")
        except aiohttp.ClientError as e:
            return f"[ERROR conexión Ollama]: {str(e)[:200]}"
        except Exception as e:
            return f"[ERROR]: {str(e)[:200]}"

    async def chat(
        self,
        messages: List[Dict[str, str]],
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
    ) -> str:
        """Chat multi-turno"""
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": temperature or self.temperature,
                "num_predict": max_tokens or self.max_tokens,
                "num_ctx": 4096,
            }
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/api/chat",
                    json=payload,
                    timeout=aiohttp.ClientTimeout(total=120)
                ) as resp:
                    if resp.status != 200:
                        return f"[ERROR]: HTTP {resp.status}"
                    data = await resp.json()
                    return data.get("message", {}).get("content", "")
        except Exception as e:
            return f"[ERROR]: {str(e)[:200]}"
