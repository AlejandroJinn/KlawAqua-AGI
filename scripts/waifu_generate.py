#!/usr/bin/env python3
"""
Avatar Generator - Waifu Diffusion (alternativa ligera a Z-Anime)
SD 1.5 anime, ~3.5GB VRAM con CPU offloading. Cabe en RTX 4050 6GB.
"""
import os, sys, json, time, argparse
import torch
from diffusers import StableDiffusionPipeline

MODEL_ID = "hakurei/waifu-diffusion"
MODEL_DIR = "/opt/klawaqua/models/waifu-diffusion"
AVATARS_DIR = "/opt/klawaqua/projects/klawaqua-avatar/avatars"
os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(AVATARS_DIR, exist_ok=True)

def download_model():
    """Descarga Waifu Diffusion (solo archivos esenciales)"""
    print(f"📥 Descargando {MODEL_ID}...")
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16,
        cache_dir=MODEL_DIR,
        safety_checker=None,  # Desactivar para avatares
    )
    pipe.save_pretrained(MODEL_DIR)
    print(f"✅ Guardado en {MODEL_DIR}")

def generate(prompt, negative_prompt=None, steps=20, seed=None, width=512, height=512):
    """Genera avatar anime con Waifu Diffusion + CPU offloading"""
    
    print(f"🎌 Waifu Diffusion: {prompt[:80]}...")
    
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_DIR,
        torch_dtype=torch.float16,
        safety_checker=None,
    )
    
    # CPU offloading - solo UNET en GPU, el resto en CPU
    pipe.enable_model_cpu_offload()
    
    if negative_prompt is None:
        negative_prompt = "nsfw, lowres, bad anatomy, bad hands, text, error, missing fingers, extra digit, fewer digits, cropped, worst quality, low quality, normal quality, jpeg artifacts, signature, watermark, username, blurry"
    
    generator = torch.Generator(device="cuda").manual_seed(seed) if seed else None
    
    # Liberar VRAM de Ollama si es necesario
    if torch.cuda.memory_allocated() > 4e9:
        print("   ⚠️ VRAM ocupada, liberando...")
        torch.cuda.empty_cache()
    
    start = time.time()
    image = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        num_inference_steps=steps,
        guidance_scale=7.5,
        width=width,
        height=height,
        generator=generator,
    ).images[0]
    elapsed = time.time() - start
    
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(AVATARS_DIR, f"waifu_{timestamp}.png")
    image.save(path)
    
    size_kb = os.path.getsize(path) / 1024
    vram_used = torch.cuda.memory_allocated() / 1e9
    print(f"✅ Avatar: {path} ({size_kb:.0f}KB, {elapsed:.1f}s, VRAM:{vram_used:.1f}GB)")
    
    return {"path": path, "size_kb": round(size_kb, 1), "time_s": round(elapsed, 1), "model": "waifu-diffusion"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--prompt", type=str, default="masterpiece, best quality, 1girl, anime style, portrait, detailed face, beautiful")
    parser.add_argument("--negative", type=str, default=None)
    parser.add_argument("--steps", type=int, default=20)
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args()
    
    if args.download:
        download_model()
    else:
        result = generate(args.prompt, args.negative, args.steps, args.seed)
        print(json.dumps(result, ensure_ascii=False, indent=2))
