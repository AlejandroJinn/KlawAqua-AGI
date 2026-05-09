#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Hermes Plugin - Auto Router Integration
Plugin para que Hermes use el router automático local↔cloud
"""

import os
import sys
sys.path.insert(0, '/opt/klawaqua/scripts')

from auto_router import AutoRouter

ROUTER = None

def route_query(prompt: str, conversation_id: str = "default", force_model: str = None):
    """
    Enruta consulta automáticamente local↔cloud
    
    Uso desde Hermes:
      from hermes_auto_router import route_query
      result = route_query("Tu pregunta")
    """
    global ROUTER
    
    if ROUTER is None:
        ROUTER = AutoRouter()
    
    result = ROUTER.generate(
        prompt=prompt,
        conversation_id=conversation_id,
        force_model=force_model
    )
    
    return result['response'], result['model_used'], result['source']

def get_best_model(task_type: str = 'general'):
    """Obtener el mejor modelo disponible"""
    global ROUTER
    
    if ROUTER is None:
        ROUTER = AutoRouter()
    
    return ROUTER.get_best_model(task_type)

# Test rápida
if __name__ == "__main__":
    print("Test: Obteniendo mejor modelo...")
    best = get_best_model()
    print(f"Mejor modelo disponible: {best}")
    
    print("\nTest: Generando respuesta...")
    response, model, source = route_query("Di hola en una frase")
    print(f"Modelo usado: {model}")
    print(f"Fuente: {source}")
    print(f"Respuesta: {response}")
