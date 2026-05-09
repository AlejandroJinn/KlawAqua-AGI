"""OpenManus Agent - Integración KlawAqua-AGI
Agente autónomo con ReAct + Ollama qwen3.5:4b"""
from typing import Any, Optional, List, Dict
from .react_agent import ToolCallAgent
from ..llm.ollama_llm import OllamaLLM
from ..tools.common_tools import ShellTool, FileTool, SearchTool

class OpenManusAgent(ToolCallAgent):
    def __init__(
        self,
        name: str = "OpenManus",
        description: str = "Agente autónomo KlawAqua - razonamiento ReAct + herramientas",
        llm: Any = None,
        tools: Any = None,
        memory: Optional[List[Dict]] = None,
        max_steps: int = 12
    ):
        system_prompt = (
            "Eres OpenManus, un agente de IA autónomo del ecosistema KlawAqua-AGI. "
            "Utilizas el patrón ReAct (Reasoning + Action) para resolver tareas. "
            "Para cada paso:\n"
            "1. Piensa (Thought) sobre qué necesitas hacer\n"
            "2. Actúa (Action) usando herramientas si es necesario\n"
            "3. Observa (Observation) el resultado\n"
            "Cuando tengas la respuesta final, escribe 'FINAL ANSWER:' seguido de tu respuesta.\n\n"
            "Herramientas disponibles:\n"
            "- shell: ejecuta comandos del sistema\n"
            "- file_manager: lee/escribe archivos (acciones: read, write, append)\n"
            "- google_search: busca información en internet"
        )
        
        # Usar Ollama por defecto si no se provee LLM
        if llm is None:
            llm = OllamaLLM()
        
        # Herramientas por defecto
        if tools is None:
            from ..tools import ToolCollection
            tools = ToolCollection()
            tools.register_tool(ShellTool())
            tools.register_tool(FileTool())
            tools.register_tool(SearchTool())
        
        super().__init__(name, description, llm, system_prompt, tools, memory, max_steps)
    
    async def step(self) -> str:
        """Un paso del bucle ReAct usando Ollama"""
        if self.current_step >= self.max_steps:
            return "FINAL ANSWER: Alcancé el límite de pasos. Aquí está lo que encontré."
        
        # Construir prompt con historial
        history = self._build_prompt()
        
        # Llamar al LLM
        response = await self.llm.generate(history, temperature=0.7, max_tokens=1024)
        
        # Guardar en memoria
        self.memory.append({"role": "assistant", "content": response})
        
        # Intentar ejecutar herramienta si se detecta sintaxis de acción
        result = await self._try_execute_tool(response)
        if result:
            self.memory.append({"role": "system", "content": f"Tool result: {result}"})
            return f"Action executed: {result[:200]}"
        
        return response
    
    async def _try_execute_tool(self, response: str) -> Optional[str]:
        """Detecta y ejecuta llamadas a herramientas en la respuesta"""
        if not self.tools:
            return None
        
        # Buscar patrones: tool_name(args) o "Usar herramienta X con Y"
        import re
        
        for tool_name in self.tools.get_tool_names():
            if tool_name in response.lower():
                try:
                    if tool_name == "shell" and "shell(" in response:
                        cmd = response.split("shell(")[1].split(")")[0].strip("\"'")
                        return await self.tools.execute_tool("shell", command=cmd)
                    elif tool_name == "file_manager":
                        if "read(" in response:
                            path = response.split("read(")[1].split(")")[0].strip("\"'")
                            return await self.tools.execute_tool("file_manager", action="read", path=path)
                        elif "write(" in response:
                            parts = response.split("write(")[1].split(")")[0]
                            args = [a.strip("\"' ") for a in parts.split(",", 1)]
                            if len(args) >= 2:
                                return await self.tools.execute_tool("file_manager", action="write", path=args[0], content=args[1])
                except Exception as e:
                    return f"Error ejecutando {tool_name}: {e}"
        
        return None
    
    def get_status(self) -> Dict:
        """Estado del agente para health checks"""
        return {
            "name": self.name,
            "state": self.state.value,
            "current_step": self.current_step,
            "max_steps": self.max_steps,
            "memory_size": len(self.memory),
            "tools": self.tools.get_tool_names() if self.tools else [],
            "model": self.llm.model if hasattr(self.llm, 'model') else "unknown"
        }