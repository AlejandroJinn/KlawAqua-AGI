#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Smart Router v2.0
Selecciona automáticamente el mejor modelo según la tarea
Configuración: qwen3.5:4b (principal) + llama3.1:8b (especializado)
"""

import json
import re
import requests
import time
from pathlib import Path
from datetime import datetime

# Configuración
CONFIG_FILE = "/opt/klawaqua/config/smart-router-v2.json"
OLLAMA_BASE = "http://localhost:11434"
LOG_FILE = "/opt/klawaqua/logs/smart-router.log"

class SmartRouter:
    def __init__(self):
        self.config = self.load_config()
        self.model_cache = {}
        self.log_file = Path(LOG_FILE)
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        
    def load_config(self):
        """Cargar configuración"""
        try:
            with open(CONFIG_FILE) as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ Error cargando config: {e}")
            return self.get_default_config()
    
    def get_default_config(self):
        """Configuración por defecto"""
        return {
            "models": {
                "primary": {"name": "qwen3.5:4b"},
                "secondary": {"name": "llama3.1:8b"},
                "specialized": {
                    "code": "qwen2.5-coder:1.5b",
                    "fast": "qwen2.5:0.5b"
                }
            },
            "routing_rules": {
                "keywords_use_llama": ["matemática", "teorema", "inglés", "razona"],
                "keywords_use_qwen": ["hola", "código", "español"],
                "keywords_use_coder": ["python", "javascript", "debug"],
                "keywords_use_fast": ["rápido", "breve", "sí o no"]
            }
        }
    
    def log(self, message: str, level: str = "INFO"):
        """Registrar en log"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        log_line = f"[{timestamp}] [{level}] {message}"
        print(log_line)
        
        with open(self.log_file, 'a') as f:
            f.write(log_line + '\n')
    
    def detect_language(self, text: str) -> str:
        """Detectar idioma del texto"""
        # Simple detection basada en caracteres comunes
        if re.search(r'[a-zA-Z]{3,}', text) and not re.search(r'[áéíóúñü¿¡]', text):
            return 'en'
        elif re.search(r'[áéíóúñü¿¡]', text):
            return 'es'
        elif re.search(r'[\u4e00-\u9fff]', text):
            return 'zh'
        return 'unknown'
    
    def detect_intent(self, text: str) -> str:
        """Detectar intención del usuario"""
        text_lower = text.lower()
        
        # Verificar palabras clave por categoría
        rules = self.config.get('routing_rules', {})
        
        # Código/Programación
        for keyword in rules.get('keywords_use_coder', []):
            if keyword.lower() in text_lower:
                return 'code'
        
        # Tareas rápidas
        for keyword in rules.get('keywords_use_fast', []):
            if keyword.lower() in text_lower:
                return 'fast'
        
        # Razonamiento complejo (usar llama)
        for keyword in rules.get('keywords_use_llama', []):
            if keyword.lower() in text_lower:
                return 'complex'
        
        # Conversación normal (usar qwen)
        for keyword in rules.get('keywords_use_qwen', []):
            if keyword.lower() in text_lower:
                return 'chat'
        
        # Detectar por idioma
        lang = self.detect_language(text)
        if lang == 'en':
            return 'complex'  # Inglés -> llama
        elif lang == 'es':
            return 'chat'  # Español -> qwen
        
        return 'chat'  # Default
    
    def select_model(self, prompt: str) -> str:
        """Seleccionar el mejor modelo para el prompt"""
        intent = self.detect_intent(prompt)
        
        models = self.config.get('models', {})
        
        # Mapeo de intención a modelo
        intent_to_model = {
            'code': models.get('specialized', {}).get('code', 'qwen2.5-coder:1.5b'),
            'fast': models.get('specialized', {}).get('fast', 'qwen2.5:0.5b'),
            'complex': models.get('secondary', {}).get('name', 'llama3.1:8b'),
            'chat': models.get('primary', {}).get('name', 'qwen3.5:4b')
        }
        
        selected = intent_to_model.get(intent, models.get('primary', {}).get('name', 'qwen3.5:4b'))
        
        self.log(f"Intent: {intent} → Model: {selected}", "ROUTING")
        
        return selected
    
    def generate(self, prompt: str, model: str = None) -> dict:
        """Generar respuesta con el modelo seleccionado"""
        start_time = time.time()
        
        # Auto-seleccionar modelo si no se especifica
        if model is None:
            model = self.select_model(prompt)
        
        self.log(f"Generating with {model}...")
        
        try:
            # Intentar con Ollama
            response = requests.post(
                f"{OLLAMA_BASE}/api/generate",
                json={
                    'model': model,
                    'prompt': prompt,
                    'stream': False
                },
                timeout=120
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result.get('response', '')
                latency = int((time.time() - start_time) * 1000)
                
                self.log(f"Success: {len(text)} chars in {latency}ms", "SUCCESS")
                
                return {
                    'response': text,
                    'model': model,
                    'latency_ms': latency,
                    'success': True
                }
            else:
                # Fallback a modelo primario
                self.log(f"HTTP {response.status_code}, falling back", "ERROR")
                return self.generate(prompt, 'qwen3.5:4b')
                
        except requests.exceptions.Timeout:
            self.log("Timeout, falling back to faster model", "ERROR")
            return self.generate(prompt, 'qwen2.5:0.5b')
            
        except Exception as e:
            self.log(f"Error: {e}", "ERROR")
            return {
                'response': f"Error: {str(e)}",
                'model': model,
                'latency_ms': 0,
                'success': False
            }
    
    def chat(self, prompt: str) -> str:
        """Interfaz simple de chat"""
        result = self.generate(prompt)
        
        if result.get('success'):
            return f"{result['response']}\n\n[Modelo: {result['model']} | {result['latency_ms']}ms]"
        else:
            return result.get('response', 'Error desconocido')


# CLI interface
if __name__ == "__main__":
    import sys
    
    router = SmartRouter()
    
    print("=" * 70)
    print("KLAWAQUA-AGI: Smart Router v2.0")
    print("Configuración: qwen3.5:4b (principal) + llama3.1:8b (especializado)")
    print("=" * 70)
    print()
    
    if len(sys.argv) > 1:
        # Modo comando directo
        prompt = ' '.join(sys.argv[1:])
        print(f"🔍 Analizando: {prompt[:100]}...")
        print()
        
        response = router.chat(prompt)
        print(response)
    else:
        # Modo interactivo
        print("💬 Chat interactivo (escribe 'salir' para terminar)")
        print()
        
        while True:
            try:
                prompt = input("Tú: ").strip()
                
                if not prompt:
                    continue
                if prompt.lower() in ['salir', 'exit', 'quit']:
                    print("👋 ¡Hasta luego!")
                    break
                
                print()
                response = router.chat(prompt)
                print(f"\n{response}\n")
                
            except KeyboardInterrupt:
                print("\n👋 ¡Hasta luego!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
