import asyncio
import argparse
from ..agent.openmanus_agent import OpenManusAgent
from ..flow.planning_flow import PlanningFlow

async def main():
    parser = argparse.ArgumentParser(description="OpenManus CLI - Tu Agente de IA Autónomo")
    parser.add_argument("query", nargs="?", help="La tarea que deseas que OpenManus realice")
    parser.add_argument("--flow", action="store_true", help="Usar el modo de orquestación de flujo (PlanningFlow)")
    args = parser.parse_args()

    # Inicialización simulada de LLM y herramientas
    llm = None 
    agent = OpenManusAgent(llm=llm)

    if not args.query:
        print("Bienvenido a OpenManus. ¿En qué puedo ayudarte hoy?")
        query = input("> ")
    else:
        query = args.query

    if args.flow:
        flow = PlanningFlow(agent=agent, llm=llm)
        result = await flow.execute(query)
    else:
        result = await agent.run(query)

    print(f"\nResultado final:\n{result}")

if __name__ == "__main__":
    asyncio.run(main())
