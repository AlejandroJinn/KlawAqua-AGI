from typing import Any, List, Dict
from abc import ABC, abstractmethod

class BaseFlow(ABC):
    @abstractmethod
    async def execute(self, request: str) -> str:
        pass

class PlanningFlow(BaseFlow):
    def __init__(self, agent: Any, llm: Any):
        self.agent = agent
        self.llm = llm
        self.plan: List[Dict[str, Any]] = []
        self.current_step_index = 0

    async def create_initial_plan(self, request: str) -> List[Dict[str, Any]]:
        prompt = f"Crea un plan detallado para resolver la siguiente tarea: {request}\nDivide la tarea en pasos lógicos y manejables."
        # response = await self.llm.generate(prompt)
        # Lógica para parsear la respuesta en una lista de pasos
        self.plan = [{"step": 1, "description": "Analizar la solicitud", "status": "pending"}]
        return self.plan

    async def execute(self, request: str) -> str:
        print(f"Creando plan para: {request}")
        await self.create_initial_plan(request)
        
        results = []
        for i, step in enumerate(self.plan):
            self.current_step_index = i
            print(f"Ejecutando paso {i+1}: {step['description']}")
            step['status'] = 'running'
            
            # El agente ejecuta el paso específico
            result = await self.agent.run(step['description'])
            step['status'] = 'completed'
            results.append(result)
            
        return f"Tarea completada. Resumen: {results[-1]}"
