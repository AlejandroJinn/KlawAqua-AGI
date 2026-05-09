import subprocess
import os
from .base_tool import BaseTool

class ShellTool(BaseTool):
    def __init__(self):
        super().__init__(
            name="shell",
            description="Ejecuta comandos de shell en el sistema. Úsalo para instalar paquetes, verificar el entorno, etc."
        )

    async def execute(self, command: str) -> str:
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True, timeout=30
            )
            return f"STDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        except Exception as e:
            return f"Error al ejecutar comando: {str(e)}"

class FileTool(BaseTool):
    def __init__(self):
        super().__init__(
            name="file_manager",
            description="Lee, escribe o edita archivos. Acciones: 'read', 'write', 'append'."
        )

    async def execute(self, action: str, path: str, content: str = "") -> str:
        try:
            if action == "read":
                if not os.path.exists(path):
                    return f"Error: El archivo {path} no existe."
                with open(path, "r") as f:
                    return f.read()
            elif action == "write":
                with open(path, "w") as f:
                    f.write(content)
                return f"Archivo escrito en {path}"
            elif action == "append":
                with open(path, "a") as f:
                    f.write(content)
                return f"Contenido añadido a {path}"
            else:
                return f"Acción no válida: {action}"
        except Exception as e:
            return f"Error en operación de archivo: {str(e)}"

class SearchTool(BaseTool):
    def __init__(self):
        super().__init__(
            name="google_search",
            description="Busca información en internet."
        )

    async def execute(self, query: str) -> str:
        # Aquí se integraría con una API de búsqueda como Serper o Google Custom Search
        return f"Simulated search results for: {query}"
