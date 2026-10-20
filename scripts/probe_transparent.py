"""验证中转站的透明背景到底有多透明：直接发一次请求，把返回的 PNG 落盘。"""

import base64
import json
import os
import sys
import urllib.request

DATA = r"E:\code\10.20MintImage-main\MintImage-main\build\windows\x64\runner\Release\data"


def main() -> None:
    profile_prefix = sys.argv[1]
    out_path = sys.argv[2]
    prompt = sys.argv[3]

    with open(os.path.join(DATA, "shared_preferences.json"), "r", encoding="utf-8") as handle:
        settings = json.loads(json.load(handle)["flutter.settings_model_v1"])

    profile = next(p for p in settings["profiles"] if p["id"].startswith(profile_prefix))
    url = profile["baseUrl"].rstrip("/") + "/v1/images/generations"
    model = os.environ.get("PROBE_MODEL") or profile["models"][0]

    body = {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "quality": "low",
        "output_format": "png",
        "background": "transparent",
        "stream": True,
        "partial_images": 0,
    }

    print(f"POST {url} model={model}")
    print(f"prompt={prompt}")

    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {profile['apiKey']}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Dart/3.13 (dart:io)",
        },
        method="POST",
    )

    b64 = None
    with urllib.request.urlopen(request, timeout=600) as response:
        for raw_line in response:
            line = raw_line.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if not payload or payload == "[DONE]":
                continue
            try:
                parsed = json.loads(payload)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict) and parsed.get("b64_json"):
                b64 = parsed["b64_json"]
            if isinstance(parsed, dict) and parsed.get("error"):
                print("上游错误:", parsed["error"])

    if not b64:
        print("没拿到图片")
        return

    with open(out_path, "wb") as handle:
        handle.write(base64.b64decode(b64))
    print(f"已写入 {out_path} ({os.path.getsize(out_path)} 字节)")


if __name__ == "__main__":
    main()
