from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

class BaseTool(ABC):
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description

    @abstractmethod
    async def execute(self, **kwargs) -> Any:
        """Ejecuta la herramienta con los argumentos proporcionados."""
        pass

    def to_dict(self) -> Dict[str, str]:
        return {
            "name": self.name,
            "description": self.description
        }

class ToolCollection:
    def __init__(self):
        self.tools: Dict[str, BaseTool] = {}

    def register_tool(self, tool: BaseTool):
        self.tools[tool.name] = tool

    async def execute_tool(self, name: str, **kwargs) -> Any:
        if name not in self.tools:
            raise ValueError(f"Herramienta '{name}' no encontrada.")
        return await self.tools[name].execute(**kwargs)

    def list_tools(self) -> List[Dict[str, str]]:
        return [tool.to_dict() for tool in self.tools.values()]
    
    def get_tool_names(self) -> List[str]:
        return list(self.tools.keys())
