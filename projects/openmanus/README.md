# OpenManus: Agente de IA Autónomo de Código Abierto

OpenManus es un proyecto de código abierto que busca replicar las capacidades de un agente de IA autónomo, con funcionalidades de planificación, razonamiento, uso de herramientas y ejecución en bucle. Este proyecto está diseñado para ser modular, extensible y flexible, permitiendo a los desarrolladores construir y experimentar con agentes de IA avanzados.

## Características Principales

- **Arquitectura Modular**: Componentes desacoplados para facilitar el desarrollo y la personalización.
- **Bucle ReAct**: Implementación del patrón Razonamiento-Acción para una toma de decisiones inteligente.
- **Sistema de Herramientas Extensible**: Fácil integración de nuevas herramientas para interactuar con el entorno.
- **Modos de Ejecución Duales**: Soporte para ejecución directa (ReAct) y orquestación de flujo (PlanningFlow) para tareas de diferente complejidad.
- **Interfaces Flexibles**: Interfaz de línea de comandos (CLI) y API REST para diversas necesidades de integración.

## Estructura del Proyecto

```
openmanus/
├── src/
│   ├── agent/             # Implementación de los agentes (BaseAgent, ReActAgent, ToolCallAgent, OpenManusAgent)
│   ├── tools/             # Definición y colección de herramientas (ShellTool, FileTool, BrowserTool, SearchTool)
│   ├── flow/              # Lógica de orquestación de flujo (PlanningFlow)
│   ├── memory/            # Gestión de la memoria del agente (aún no implementado completamente)
│   ├── cli/               # Interfaz de línea de comandos
│   └── api/               # Interfaz API REST
├── tests/                 # Pruebas unitarias e de integración
├── docs/                  # Documentación del proyecto
├── config/                # Archivos de configuración
├── .env.example           # Ejemplo de variables de entorno
├── README.md              # Este archivo
├── requirements.txt       # Dependencias de Python
└── Dockerfile             # Configuración para Docker (aún no implementado)
```

## Instalación

1.  **Clonar el repositorio**:
    ```bash
    git clone https://github.com/tu_usuario/openmanus.git
    cd openmanus
    ```

2.  **Crear un entorno virtual** (recomendado):
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

3.  **Instalar dependencias**:
    ```bash
    pip install -r requirements.txt
    ```

4.  **Configurar variables de entorno**:
    Copia `.env.example` a `.env` y edita las variables necesarias (por ejemplo, claves de API para LLMs).
    ```bash
    cp .env.example .env
    ```

## Uso

### Interfaz de Línea de Comandos (CLI)

Para ejecutar una tarea en modo agente directo:

```bash
python -m src.cli.main "Tu tarea aquí"
```

Para ejecutar una tarea en modo de orquestación de flujo:

```bash
python -m src.cli.main --flow "Tu tarea compleja aquí"
```

### API REST

1.  **Iniciar el servidor API**:
    ```bash
    uvicorn src.api.main:app --host 0.0.0.0 --port 8000
    ```

2.  **Acceder a la API**: Puedes interactuar con la API a través de `http://localhost:8000` (o la dirección de tu servidor). La documentación de la API (Swagger UI) estará disponible en `http://localhost:8000/docs`.

## Contribución

¡Las contribuciones son bienvenidas! Consulta `CONTRIBUTING.md` (aún no creado) para obtener más detalles sobre cómo puedes ayudar.

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo `LICENSE` (aún no creado) para más detalles.

## Contacto

Para preguntas o sugerencias, por favor abre un issue en el repositorio de GitHub.
