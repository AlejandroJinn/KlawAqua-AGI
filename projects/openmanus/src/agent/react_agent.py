from typing import Any, List, Optional
from .base_agent import BaseAgent, AgentState

class ReActAgent(BaseAgent):
    def __init__(
        self,
        name: str,
        description: str,
        llm: Any,
        system_prompt: str,
        memory: Optional[Any] = None,
        max_steps: int = 10
    ):
        super().__init__(name, description, llm, memory, max_steps)
        self.system_prompt = system_prompt
        self.next_step_prompt = "Based on the previous steps and observations, what is the next step?"

    async def run(self, request: str) -> str:
        self.state = AgentState.RUNNING
        self.memory.append({"role": "user", "content": request})
        
        while self.state == AgentState.RUNNING:
            if self.is_stuck():
                self.handle_stuck_state()
                break
            
            result = await self.step()
            self.current_step += 1
            
            if "FINAL ANSWER" in result:
                self.state = AgentState.FINISHED
                return result
        
        return "Task could not be completed."

    async def step(self) -> str:
        # Aquí se llamaría al LLM para razonar y actuar
        # Por ahora es un marcador de posición
        prompt = self._build_prompt()
        response = await self.llm.generate(prompt)
        self.memory.append({"role": "assistant", "content": response})
        return response

    def _build_prompt(self) -> str:
        # Construye el prompt completo para el LLM
        history = "\n".join([f"{m['role']}: {m['content']}" for m in self.memory])
        return f"{self.system_prompt}\n\n{history}\n\nAssistant:"

class ToolCallAgent(ReActAgent):
    def __init__(
        self,
        name: str,
        description: str,
        llm: Any,
        system_prompt: str,
        tools: Any,
        memory: Optional[Any] = None,
        max_steps: int = 10
    ):
        super().__init__(name, description, llm, system_prompt, memory, max_steps)
        self.tools = tools

    async def think(self) -> str:
        """Decide qué herramienta usar."""
        # Lógica para llamar al LLM y obtener una llamada a herramienta
        pass

    async def act(self, tool_call: Any) -> str:
        """Ejecuta la herramienta seleccionada."""
        # Lógica para ejecutar la herramienta y devolver el resultado
        pass
