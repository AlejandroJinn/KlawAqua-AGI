#!/usr/bin/env python3
"""
KlawAqua-AGI Repository Analyzer
Analiza, categoriza e integra todos los repositorios del ecosistema
"""

import os
import json
from pathlib import Path
from datetime import datetime

PROJECTS_DIR = "/opt/klawaqua/projects"
OUTPUT_FILE = "/opt/klawaqua/REPOSITORY_INDEX.json"

# Categorías predefinidas
CATEGORIES = {
    "agent-frameworks": {
        "keywords": ["agent", "hand", "claude", "opencode", "bot", "assistant"],
        "description": "Frameworks de agentes de IA autónomos"
    },
    "ai-ml-tools": {
        "keywords": ["localai", "deepgemm", "generative", "graphrag", "parse", "markitdown"],
        "description": "Herramientas de IA/ML"
    },
    "coding-development": {
        "keywords": ["browser", "typescript", "git", "code", "dev"],
        "description": "Herramientas de desarrollo y coding"
    },
    "data-analytics": {
        "keywords": ["openbb", "fincept", "trading", "timesfm", "graphify", "data"],
        "description": "Análisis de datos y finanzas"
    },
    "infrastructure": {
        "keywords": ["dokploy", "vault", "searx", "traefik", "docker"],
        "description": "Infraestructura y deployment"
    },
    "productivity": {
        "keywords": ["excel", "ppt", "marimo", "obsidian", "notion", "calendar"],
        "description": "Productividad y oficina"
    },
    "creative": {
        "keywords": ["avatar", "wav2lip", "sadtalker", "fooocus", "comfy", "image", "video"],
        "description": "Contenido creativo y multimedia"
    },
    "research": {
        "keywords": ["arxiv", "paper", "research", "knowledge"],
        "description": "Investigación y conocimiento"
    },
    "communication": {
        "keywords": ["telegram", "chat", "message", "voice", "tts", "stt"],
        "description": "Comunicación y mensajería"
    },
    "automation": {
        "keywords": ["auto", "workflow", "pipeline", "cron", "sync"],
        "description": "Automatización de flujos de trabajo"
    }
}

def analyze_repository(repo_path):
    """Analiza un repositorio y extrae información clave"""
    repo_info = {
        "name": repo_path.name,
        "path": str(repo_path),
        "category": "uncategorized",
        "confidence": 0,
        "description": "",
        "has_skill": False,
        "has_readme": False,
        "has_docker": False,
        "has_python": False,
        "has_node": False,
        "language": "unknown",
        "last_modified": None,
        "size_mb": 0
    }
    
    # Verificar archivos clave
    for file in repo_path.iterdir():
        if file.is_file():
            name_lower = file.name.lower()
            if "skill.md" in name_lower:
                repo_info["has_skill"] = True
            elif "readme" in name_lower:
                repo_info["has_readme"] = True
            elif "dockerfile" in name_lower or "docker-compose" in name_lower:
                repo_info["has_docker"] = True
            elif file.suffix == ".py":
                repo_info["has_python"] = True
            elif file.suffix == ".js" or file.suffix == ".ts" or name_lower == "package.json":
                repo_info["has_node"] = True
    
    # Determinar lenguaje principal
    if repo_info["has_python"]:
        repo_info["language"] = "Python"
    elif repo_info["has_node"]:
        repo_info["language"] = "JavaScript/TypeScript"
    elif repo_info["has_docker"]:
        repo_info["language"] = "Docker"
    
    # Categorizar basado en keywords
    repo_name_lower = repo_path.name.lower()
    for category, config in CATEGORIES.items():
        matches = sum(1 for keyword in config["keywords"] if keyword in repo_name_lower)
        if matches > 0:
            confidence = matches / len(config["keywords"])
            if confidence > repo_info["confidence"]:
                repo_info["category"] = category
                repo_info["confidence"] = confidence
                repo_info["description"] = config["description"]
    
    # Calcular tamaño
    try:
        total_size = sum(f.stat().st_size for f in repo_path.rglob('*') if f.is_file())
        repo_info["size_mb"] = round(total_size / (1024 * 1024), 2)
    except:
        repo_info["size_mb"] = 0
    
    # Última modificación
    try:
        repo_info["last_modified"] = datetime.fromtimestamp(repo_path.stat().st_mtime).isoformat()
    except:
        pass
    
    return repo_info

def main():
    print("=" * 60)
    print("   KLAWAQUA-AGI REPOSITORY ANALYZER")
    print("=" * 60)
    print()
    
    projects = Path(PROJECTS_DIR)
    if not projects.exists():
        print(f"ERROR: {PROJECTS_DIR} no existe")
        return
    
    repos = [d for d in projects.iterdir() if d.is_dir() and not d.name.startswith('.')]
    print(f"Analizando {len(repos)} repositorios...")
    print()
    
    results = {
        "generated_at": datetime.now().isoformat(),
        "total_repositories": len(repos),
        "categories": {},
        "repositories": []
    }
    
    # Analizar cada repositorio
    for i, repo in enumerate(repos, 1):
        print(f"[{i}/{len(repos)}] Analizando {repo.name}...", end="\r")
        info = analyze_repository(repo)
        results["repositories"].append(info)
        
        # Contar por categoría
        cat = info["category"]
        if cat not in results["categories"]:
            results["categories"][cat] = {
                "count": 0,
                "description": CATEGORIES.get(cat, {}).get("description", "Sin descripción"),
                "repos": []
            }
        results["categories"][cat]["count"] += 1
        results["categories"][cat]["repos"].append(info["name"])
    
    print()
    print()
    
    # Ordenar categorías por cantidad
    sorted_categories = sorted(results["categories"].items(), key=lambda x: x[1]["count"], reverse=True)
    
    # Resumen
    print("=" * 60)
    print("   RESUMEN POR CATEGORÍA")
    print("=" * 60)
    print()
    
    for cat_name, cat_data in sorted_categories:
        print(f"{cat_name.upper()}: {cat_data['count']} repositorios")
        print(f"  {cat_data['description']}")
        if cat_data['count'] <= 10:
            print(f"  Repos: {', '.join(cat_data['repos'][:5])}{'...' if len(cat_data['repos']) > 5 else ''}")
        print()
    
    # Estadísticas
    total_size = sum(r["size_mb"] for r in results["repositories"])
    with_skills = sum(1 for r in results["repositories"] if r["has_skill"])
    with_docker = sum(1 for r in results["repositories"] if r["has_docker"])
    
    print("=" * 60)
    print("   ESTADÍSTICAS GENERALES")
    print("=" * 60)
    print(f"Total repositorios: {len(results['repositories'])}")
    print(f"Tamaño total: {total_size:.2f} MB")
    print(f"Con SKILL.md: {with_skills}")
    print(f"Con Docker: {with_docker}")
    print(f"Categorías: {len(results['categories'])}")
    print()
    
    # Guardar resultados
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print(f"✓ Índice guardado en: {OUTPUT_FILE}")
    print()
    print("=" * 60)
    print("   ANÁLISIS COMPLETADO")
    print("=" * 60)

if __name__ == "__main__":
    main()
