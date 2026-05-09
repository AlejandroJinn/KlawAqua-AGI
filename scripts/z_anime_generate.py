#!/usr/bin/env python3
"""
Z-Anime Avatar Generator - KlawAqua AGI
Descarga y usa Z-Anime (SeeSee21) con CPU offloading para 6GB VRAM
Integración via Router Mesh: POST /mesh/call -> openmanus -> /avatar/generate
"""
import os, sys, json, time, argparse

Z_ANIME_DIR = "/opt/klawaqua/models/z-anime"
AVATARS_DIR = "/opt/klawaqua/projects/klawaqua-avatar/avatars"
os.makedirs(Z_ANIME_DIR, exist_ok=True)
os.makedirs(AVATARS_DIR, exist_ok=True)

def download_model():
    """Descarga Z-Anime diffusers desde HuggingFace"""
    from huggingface_hub import snapshot_download
    
    print("📥 Descargando Z-Anime diffusers (FP8, CPU offload optimizado)...")
    print("   Solo archivos esenciales (~10GB total)")
    
    # Descargar solo archivos diffusers esenciales
    snapshot_download(
        repo_id="SeeSee21/Z-Anime",
        local_dir=Z_ANIME_DIR,
        allow_patterns=[
            "diffusers/**",
            "config.json",
            "model_index.json",
            "vae/*",
        ],
        ignore_patterns=["*.md", "images/*", "aio/*", "gguf/*", 
                        "diffusion_models/*", "workflows/*", "text_encoder/*.gguf"],
        max_workers=2,
    )
    print("✅ Z-Anime descargado en", Z_ANIME_DIR)

def generate(prompt, negative_prompt=None, num_steps=4, seed=None):
    """Genera avatar anime con Z-Anime + CPU offloading"""
    import torch
    from diffusers import DiffusionPipeline
    
    if not os.path.exists(os.path.join(Z_ANIME_DIR, "model_index.json")):
        raise FileNotFoundError(f"Z-Anime no encontrado en {Z_ANIME_DIR}. Ejecuta --download primero.")
    
    print(f"🎌 Generando avatar Z-Anime...")
    print(f"   Prompt: {prompt[:80]}...")
    
    # Cargar con CPU offloading para 6GB VRAM
    pipe = DiffusionPipeline.from_pretrained(
        Z_ANIME_DIR,
        torch_dtype=torch.float16,
        variant="fp16",
    )
    
    # CPU offloading - solo mantiene un componente en GPU a la vez
    pipe.enable_model_cpu_offload()
    
    if negative_prompt is None:
        negative_prompt = "nsfw, low quality, worst quality, bad anatomy, extra fingers, deformed, blurry, text, watermark"
    
    generator = torch.Generator(device="cuda").manual_seed(seed) if seed else None
    
    start = time.time()
    image = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        num_inference_steps=num_steps,
        guidance_scale=3.5,
        width=512,
        height=512,
        generator=generator,
    ).images[0]
    elapsed = time.time() - start
    
    # Guardar
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(AVATARS_DIR, f"z_anime_{timestamp}.png")
    image.save(path)
    
    size_kb = os.path.getsize(path) / 1024
    print(f"✅ Avatar generado: {path} ({size_kb:.0f} KB, {elapsed:.1f}s)")
    
    return {
        "path": path,
        "size_kb": round(size_kb, 1),
        "time_s": round(elapsed, 1),
        "prompt": prompt,
        "model": "SeeSee21/Z-Anime",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Z-Anime Avatar Generator")
    parser.add_argument("--download", action="store_true", help="Descargar modelo Z-Anime")
    parser.add_argument("--prompt", type=str, default="1girl, anime style, portrait, high quality, beautiful, Z-Anime", 
                       help="Prompt para generar avatar")
    parser.add_argument("--negative", type=str, default=None)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args()
    
    if args.download:
        download_model()
    else:
        result = generate(args.prompt, args.negative, args.steps, args.seed)
        print(json.dumps(result, ensure_ascii=False, indent=2))
