import { readFileSync, writeFileSync } from "node:fs";

const path = new URL("./server_fast.js", import.meta.url);
let text = readFileSync(path, "utf8");

if (!text.includes("action === \"custom_prompt\"")) {
  text = text.replace(
    "async function generativeRemove(buffer, mimeType, action, pointX, pointY) {",
    "async function generativeRemove(buffer, mimeType, action, pointX, pointY, userPrompt) {",
  );

  text = text.replace(
    "  const prompt = action === \"remove_people\"\n    ? \"Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme.\"\n    : `Fotoğrafı koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve alanı doğal çevre dokusuyla doldur. Diğer insanları ve nesneleri değiştirme.`;",
    "  const prompt = action === \"custom_prompt\"\n    ? `Mevcut fotoğrafı gerçekçi biçimde düzenle. Ana kişilerin kimliğini/yüzünü, yazıları, perspektifi ve kadrajı kullanıcı açıkça istemedikçe koru. Gereksiz nesne ekleme. Kullanıcı isteği: ${String(userPrompt || \"\").trim().slice(0, 1200)}`\n    : action === \"remove_people\"\n    ? \"Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme.\"\n    : `Fotoğrafı koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve alanı doğal çevre dokusuyla doldur. Diğer insanları ve nesneleri değiştirme.`;",
  );

  text = text.replace(
    "    if (action === \"remove_people\" || action === \"remove_object\") {",
    "    if (action === \"custom_prompt\") {\n      const prompt = String(req.body?.prompt || \"\").trim();\n      if (!prompt) return res.status(400).json({ error: \"Düzenleme tarifini yazmalısın.\" });\n      const output = await generativeRemove(req.file.buffer, detectMimeType(req.file), action, null, null, prompt);\n      res.setHeader(\"Content-Type\", \"image/jpeg\"); res.setHeader(\"X-Develop-Engine\", \"gpt-image-2-custom-edit\"); res.setHeader(\"Cache-Control\", \"no-store\");\n      return res.status(200).send(output);\n    }\n    if (action === \"remove_people\" || action === \"remove_object\") {",
  );
}

// sharp.clahe maxSlope is an integer in [0, 100]. Older startup code used 1.35,
// which throws at runtime and made the Light tool return HTTP 500.
text = text.replaceAll("maxSlope: 1.35", "maxSlope: 2");

writeFileSync(path, text, "utf8");
