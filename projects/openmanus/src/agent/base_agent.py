from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Dict, List, Optional

class AgentState(Enum):
    IDLE = "idle"
    RUNNING = "running"
    FINISHED = "finished"
    STUCK = "stuck"
    ERROR = "error"

class BaseAgent(ABC):
    def __init__(
        self,
        name: str,
        description: str,
        llm: Any,
        memory: Optional[Any] = None,
        max_steps: int = 10
    ):
        self.name = name
        self.description = description
        self.llm = llm
        self.memory = memory or []
        self.max_steps = max_steps
        self.current_step = 0
        self.state = AgentState.IDLE

    @abstractmethod
    async def run(self, request: str) -> str:
        """Inicia la ejecución del agente con una solicitud del usuario."""
        pass

    @abstractmethod
    async def step(self) -> str:
        """Realiza un único paso de ejecución."""
        pass

    def is_stuck(self) -> bool:
        """Verifica si el agente está atascado en un bucle infinito."""
        if self.current_step >= self.max_steps:
            return True
        # Lógica adicional para detectar repeticiones de acciones
        return False

    def handle_stuck_state(self):
        """Maneja el estado de bloqueo del agente."""
        self.state = AgentState.STUCK
        print(f"Agent {self.name} is stuck after {self.current_step} steps.")

    def reset(self):
        """Reinicia el estado del agente."""
        self.current_step = 0
        self.state = AgentState.IDLE
        self.memory = []
