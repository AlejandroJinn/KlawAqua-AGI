"""OpenManus API - Integración KlawAqua-AGI
FastAPI server con Ollama qwen3.5:4b"""
import os
import sys
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

# Asegurar imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.llm.ollama_llm import OllamaLLM
from src.agent.openmanus_agent import OpenManusAgent
from src.api.dashboard import router as dashboard_router
from src.api.avatar_pipeline import router as avatar_router

app = FastAPI(
    title="OpenManus - KlawAqua AGI",
    description="Agente autónomo con ReAct + Ollama qwen3.5:4b",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir dashboard
app.include_router(dashboard_router)

# Incluir avatar pipeline
app.include_router(avatar_router)

# Inicializar agente con Ollama
llm = OllamaLLM(
    base_url=os.getenv("OLLAMA_BASE_URL", "http://localhost:11434"),
    model=os.getenv("OPENMANUS_MODEL", "qwen3.5:4b"),
)
agent = OpenManusAgent(llm=llm)

class TaskRequest(BaseModel):
    prompt: str
    use_flow: bool = False
    max_steps: Optional[int] = None

class TaskResponse(BaseModel):
    status: str
    result: str
    steps: int = 0

@app.get("/")
async def root():
    return {
        "name": "OpenManus",
        "ecosystem": "KlawAqua-AGI",
        "model": llm.model,
        "version": "1.0.0"
    }

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "agent_state": agent.state.value,
        "model": llm.model,
        "tools": agent.tools.get_tool_names() if agent.tools else [],
    }

@app.post("/run", response_model=TaskResponse)
async def run_task(request: TaskRequest):
    try:
        if request.max_steps:
            agent.max_steps = request.max_steps
        agent.reset()
        result = await agent.run(request.prompt)
        return TaskResponse(
            status=agent.state.value,
            result=result,
            steps=agent.current_step
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/status")
async def status():
    return agent.get_status()

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("OPENMANUS_PORT", "8002"))
    host = os.getenv("OPENMANUS_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port)