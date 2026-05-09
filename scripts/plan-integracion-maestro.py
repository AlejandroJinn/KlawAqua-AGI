#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Plan Maestro de Integración y Optimización
Analiza todos los repositorios y crea estrategia óptima
"""

import os
import json
from pathlib import Path
from datetime import datetime
import subprocess

PROJECTS_DIR = "/opt/klawaqua/projects"
OUTPUT_DIR = "/opt/klawaqua/PLAN_INTEGRACION"

# Categorías estratégicas para KlawAqua-AGI
CATEGORIAS = {
    "core-agents": {
        "repos": ["agent-zero", "OpenHands", "openclaude", "opencode", "thepopebot", "openclaw"],
        "prioridad": "CRÍTICA",
        "descripcion": "Agentes principales del ecosistema"
    },
    "infrastructure": {
        "repos": ["docker", "traefik", "dokploy", "vaultwarden", "searxng", "litellm"],
        "prioridad": "ALTA",
        "descripcion": "Infraestructura base y deployment"
    },
    "ai-ml-core": {
        "repos": ["LocalAI", "ollama", "llama.cpp", "whisper.cpp", "vllm"],
        "prioridad": "CRÍTICA",
        "descripcion": "Modelos y engines de inferencia"
    },
    "creative-media": {
        "repos": ["Wav2Lip", "SadTalker", "Fooocus", "ComfyUI", "klawaqua-avatar"],
        "prioridad": "ALTA",
        "descripcion": "Avatares, video, imágenes, TTS/STT"
    },
    "coding-tools": {
        "repos": ["browser-use", "GitNexus", "typescript-go", "markitdown"],
        "prioridad": "MEDIA",
        "descripcion": "Herramientas de desarrollo"
    },
    "data-analytics": {
        "repos": ["OpenBB", "FinceptTerminal", "graphrag", "timesfm"],
        "prioridad": "MEDIA",
        "descripcion": "Análisis de datos y finanzas"
    },
    "automation": {
        "repos": ["agent-flow", "cron", "workflow", "pipeline"],
        "prioridad": "ALTA",
        "descripcion": "Automatización de flujos"
    },
    "research": {
        "repos": ["arxiv", "paper", "knowledge", "llm-wiki"],
        "prioridad": "BAJA",
        "descripcion": "Investigación y conocimiento"
    },
    "deprecated": {
        "repos": ["OpenManus", "OpenWebUI"],
        "prioridad": "DESCARTADO",
        "descripcion": "Repositorios eliminados del ecosistema"
    }
}

def analyze_repo_health(repo_path):
    """Analiza salud de un repositorio"""
    health = {
        "name": repo_path.name,
        "status": "unknown",
        "has_requirements": False,
        "has_setup": False,
        "has_docker": False,
        "is_active": True,
        "last_commit": "unknown",
        "size_mb": 0,
        "integration_complexity": "low"
    }
    
    # Verificar archivos clave
    for file in repo_path.iterdir():
        if file.is_file():
            name = file.name.lower()
            if "requirements" in name or "package.json" in name or "Cargo.toml" in name:
                health["has_requirements"] = True
            elif "setup" in name or "install" in name or "build" in name:
                health["has_setup"] = True
            elif "dockerfile" in name or "docker-compose" in name:
                health["has_docker"] = True
    
    # Intentar obtener último commit
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_path), "log", "-1", "--format=%ci"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            health["last_commit"] = result.stdout.strip()[:10]
    except:
        pass
    
    # Calcular tamaño
    try:
        total_size = sum(f.stat().st_size for f in repo_path.rglob('*') if f.is_file())
        health["size_mb"] = round(total_size / (1024 * 1024), 2)
    except:
        health["size_mb"] = 0
    
    # Determinar complejidad
    if health["has_docker"]:
        health["integration_complexity"] = "medium"
    if health["has_requirements"] and health["has_setup"]:
        health["integration_complexity"] = "high"
    
    return health

def main():
    print("=" * 80)
    print("   KLAWAQUA-AGI: PLAN MAESTRO DE INTEGRACIÓN Y OPTIMIZACIÓN")
    print("=" * 80)
    print()
    
    projects = Path(PROJECTS_DIR)
    repos = [d for d in projects.iterdir() if d.is_dir() and not d.name.startswith('.')]
    
    print(f"Analizando {len(repos)} repositorios...\n")
    
    # Analizar cada repo
    repo_health_list = []
    categorized = {cat: [] for cat in CATEGORIAS.keys()}
    
    for i, repo in enumerate(repos, 1):
        print(f"[{i}/{len(repos)}] {repo.name}...", end="\r")
        health = analyze_repo_health(repo)
        repo_health_list.append(health)
        
        # Categorizar
        categorized_flag = False
        for cat_name, cat_data in CATEGORIAS.items():
            if cat_name != "deprecated":
                if any(kw.lower() in repo.name.lower() for kw in cat_data["repos"]) or \
                   any(kw.lower() in repo.name.lower() for kw in cat_data["repos"]):
                    categorized[cat_name].append(health)
                    categorized_flag = True
                    break
        
        if not categorized_flag:
            # Categorización automática por keywords
            name_lower = repo.name.lower()
            if any(x in name_lower for x in ["agent", "hand", "claude", "bot"]):
                categorized["core-agents"].append(health)
            elif any(x in name_lower for x in ["docker", "infra", "deploy"]):
                categorized["infrastructure"].append(health)
            elif any(x in name_lower for x in ["wav", "talker", "avatar", "tts", "speech"]):
                categorized["creative-media"].append(health)
            elif any(x in name_lower for x in ["data", "finance", "graph", "analytics"]):
                categorized["data-analytics"].append(health)
            else:
                categorized["research"].append(health)
    
    print("\n")
    
    # Crear directorio de output
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Generar reporte
    plan = {
        "generated_at": datetime.now().isoformat(),
        "total_repositories": len(repos),
        "categories": {},
        "optimization_plan": [],
        "integration_roadmap": []
    }
    
    # Procesar categorías
    for cat_name, repos_list in categorized.items():
        if repos_list:
            total_size = sum(r["size_mb"] for r in repos_list)
            plan["categories"][cat_name] = {
                "count": len(repos_list),
                "total_size_mb": round(total_size, 2),
                "priority": CATEGORIAS[cat_name]["prioridad"],
                "description": CATEGORIAS[cat_name]["descripcion"],
                "repositories": repos_list
            }
    
    # Ordenar por prioridad
    priority_order = {"CRÍTICA": 0, "ALTA": 1, "MEDIA": 2, "BAJA": 3, "DESCARTADO": 4}
    sorted_cats = sorted(plan["categories"].items(), 
                        key=lambda x: priority_order.get(x[1]["priority"], 5))
    
    # Generar plan de optimización
    print("Generando plan de optimización...\n")
    
    phase = 1
    for cat_name, cat_data in sorted_cats:
        if cat_data["priority"] in ["CRÍTICA", "ALTA"]:
            plan["optimization_plan"].append({
                "phase": phase,
                "category": cat_name,
                "priority": cat_data["priority"],
                "action": f"Integrar y optimizar {cat_data['count']} repositorios de {cat_name}",
                "estimated_time": f"{cat_data['count'] * 2} horas",
                "impact": "Alto - Componentes core del ecosistema"
            })
            phase += 1
    
    # roadmap de integración
    plan["integration_roadmap"] = [
        {
            "fase": "1 - INMEDIATA (24-48h)",
            "objetivo": "Core agents + Infrastructure operativa",
            "repos": sum(cat_data["count"] for cat, cat_data in plan["categories"].items() 
                        if cat in ["core-agents", "infrastructure"]),
            "entregables": ["100% agentes configurados", "Infraestructura estable"]
        },
        {
            "fase": "2 - CORTO PLAZO (1 semana)",
            "objetivo": "Creative media + AI/ML core",
            "repos": sum(cat_data["count"] for cat, cat_data in plan["categories"].items() 
                        if cat in ["creative-media", "ai-ml-core"]),
            "entregables": ["Avatar parlante", "Pipeline TTS/STT", "Modelos optimizados"]
        },
        {
            "fase": "3 - MEDIANO PLAZO (2 semanas)",
            "objetivo": "Coding tools + Data analytics",
            "repos": sum(cat_data["count"] for cat, cat_data in plan["categories"].items() 
                        if cat in ["coding-tools", "data-analytics"]),
            "entregables": ["GitNexus fully operational", "Dashboard analytics"]
        },
        {
            "fase": "4 - LATENTE (según necesidad)",
            "objetivo": "Research + misceláneos",
            "repos": sum(cat_data["count"] for cat, cat_data in plan["categories"].items() 
                        if cat in ["research"]),
            "entregables": ["Knowledge base actualizada"]
        }
    ]
    
    # Resumen ejecutivo
    print("\n" + "=" * 80)
    print("   RESUMEN EJECUTIVO")
    print("=" * 80)
    print()
    
    total_repos = sum(cat_data["count"] for cat_data in plan["categories"].values())
    total_size = sum(cat_data["total_size_mb"] for cat_data in plan["categories"].values())
    
    print(f"Total repositorios analizados: {total_repos}")
    print(f"Tamaño total: {total_size:.2f} MB ({total_size/1024:.2f} GB)")
    print()
    
    print("Distribución por categoría:")
    for cat_name, cat_data in sorted_cats:
        print(f"  {cat_name.upper()}: {cat_data['count']} repos "
              f"({cat_data['total_size_mb']:.2f} MB) - {cat_data['priority']}")
    print()
    
    print("Roadmap de integración:")
    for roadmap_item in plan["integration_roadmap"]:
        print(f"\n  {roadmap_item['fase']}")
        print(f"    Objetivo: {roadmap_item['objetivo']}")
        print(f"    Repositorios: {roadmap_item['repos']}")
        print(f"    Entregables: {', '.join(roadmap_item['entregables'])}")
    
    # Guardar plan completo
    output_file = os.path.join(OUTPUT_DIR, "PLAN_MAESTRO.json")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(plan, f, indent=2, ensure_ascii=False)
    
    print("\n" + "=" * 80)
    print(f"   ✅ PLAN GENERADO EXITOSAMENTE")
    print("=" * 80)
    print(f"\nPlan completo guardado en: {output_file}")
    print(f"Directorio de trabajo: {OUTPUT_DIR}")
    print("\n" + "=" * 80)

if __name__ == "__main__":
    main()
