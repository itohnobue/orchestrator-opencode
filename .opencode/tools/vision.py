#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# ///
"""Vision tool — invoke GLM-4.6V to describe/analyze images via Z.ai API.

Reads API key from ~/.config/opencode/opencode.json (provider.zai.options.apiKey).
Supports PNG, JPG, JPEG formats. Max image size: 5MB, max pixels: 6000x6000.

Usage:
    vision.py <image_path> [prompt]

Examples:
    vision.py screenshot.png
    vision.py diagram.jpg "Explain this architecture diagram"
    vision.py error.png "What error is shown and how to fix it?"
"""

import sys, json, base64, mimetypes
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

API_URL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
MODEL = "glm-4.6v"
MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5MB


def get_api_key():
    config_path = Path.home() / ".config" / "opencode" / "opencode.json"
    if not config_path.exists():
        raise SystemExit(f"Config not found: {config_path}")
    with open(config_path) as f:
        config = json.load(f)
    try:
        return config["provider"]["zai"]["options"]["apiKey"]
    except KeyError:
        raise SystemExit("Could not find provider.zai.options.apiKey in opencode config")


def get_mime_type(path):
    mime, _ = mimetypes.guess_type(str(path))
    if mime and mime.startswith("image/"):
        return mime
    # Fallback based on extension
    ext = Path(path).suffix.lower()
    ext_map = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}
    return ext_map.get(ext, "image/png")


def describe_image(image_path, prompt):
    img_path = Path(image_path)
    if not img_path.exists():
        raise SystemExit(f"Image not found: {image_path}")

    img_data = img_path.read_bytes()
    if len(img_data) > MAX_IMAGE_BYTES:
        raise SystemExit(f"Image too large: {len(img_data)} bytes (max {MAX_IMAGE_BYTES})")

    b64_data = base64.b64encode(img_data).decode()
    mime = get_mime_type(image_path)
    data_uri = f"data:{mime};base64,{b64_data}"

    body = {
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": data_uri}},
                {"type": "text", "text": prompt}
            ]
        }],
        "max_tokens": 4096
    }

    api_key = get_api_key()
    req = Request(API_URL,
                  data=json.dumps(body).encode("utf-8"),
                  headers={
                      "Content-Type": "application/json",
                      "Authorization": f"Bearer {api_key}"
                  })

    try:
        with urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
    except HTTPError as e:
        err_body = e.read().decode() if e.fp else ""
        raise SystemExit(f"API HTTP {e.code}: {err_body}")
    except URLError as e:
        raise SystemExit(f"API connection error: {e.reason}")

    if "choices" not in result or not result["choices"]:
        raise SystemExit(f"Unexpected API response: {json.dumps(result)[:500]}")

    msg = result["choices"][0]["message"]
    return msg.get("content") or msg.get("reasoning_content", "(no text in response)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: vision.py <image_path> [prompt]", file=sys.stderr)
        print("  image_path — path to PNG/JPG/JPEG image (max 5MB)", file=sys.stderr)
        print("  prompt     — optional description of what to look for (default: describe in detail)", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Describe this image in detail. Include all visible text, UI elements, layout, and any notable details."

    try:
        result = describe_image(image_path, prompt)
        print(result.strip())
    except SystemExit as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"UNEXPECTED ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)
