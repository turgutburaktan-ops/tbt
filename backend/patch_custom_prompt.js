import { readFileSync, writeFileSync } from "node:fs";

const path = new URL("./server_fast.js", import.meta.url);
let text = readFileSync(path, "utf8");

// Keep custom free-text editing available.
if (!text.includes('action === "custom_prompt"')) {
  text = text.replace(
    'async function generativeRemove(buffer, mimeType, action, pointX, pointY) {',
    'async function generativeRemove(buffer, mimeType, action, pointX, pointY, userPrompt) {',
  );

  text = text.replace(
    '  const prompt = action === "remove_people"\n    ? "Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme."\n    : `Fotoğrafı koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve alanı doğal çevre dokusuyla doldur. Diğer insanları ve nesneleri değiştirme.`;',
    '  const prompt = action === "custom_prompt"\n    ? `Mevcut fotoğrafı gerçekçi biçimde düzenle. Ana kişilerin kimliğini/yüzünü, yazıları, perspektifi ve kadrajı kullanıcı açıkça istemedikçe koru. Gereksiz nesne ekleme. Kullanıcı isteği: ${String(userPrompt || "").trim().slice(0, 1200)}`\n    : action === "remove_people"\n    ? "Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme."\n    : `Fotoğrafı koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve alanı doğal çevre dokusuyla doldur. Diğer insanları ve nesneleri değiştirme.`;',
  );

  text = text.replace(
    '    if (action === "remove_people" || action === "remove_object") {',
    '    if (action === "custom_prompt") {\n      const prompt = String(req.body?.prompt || "").trim();\n      if (!prompt) return res.status(400).json({ error: "Düzenleme tarifini yazmalısın." });\n      const output = await generativeRemove(req.file.buffer, detectMimeType(req.file), action, null, null, prompt);\n      res.setHeader("Content-Type", "image/jpeg"); res.setHeader("X-Develop-Engine", "gpt-image-2-custom-edit"); res.setHeader("Cache-Control", "no-store");\n      return res.status(200).send(output);\n    }\n    if (action === "remove_people" || action === "remove_object") {',
  );
}

// All visible edit buttons are AI-driven. The old Sharp/CLAHE light path caused
// washed-out/solarized results on some photos, so Auto and Light now use the
// same image-edit model as object removal with strict preservation prompts.
text = text.replace(
  '  const prompt = action === "custom_prompt"\n    ? `Mevcut fotoğrafı gerçekçi biçimde düzenle. Ana kişilerin kimliğini/yüzünü, yazıları, perspektifi ve kadrajı kullanıcı açıkça istemedikçe koru. Gereksiz nesne ekleme. Kullanıcı isteği: ${String(userPrompt || "").trim().slice(0, 1200)}`\n    : action === "remove_people"',
  '  const prompt = action === "auto_enhance"\n    ? "Bu fotoğrafı profesyonel ve doğal biçimde iyileştir. Yalnızca pozlama, beyaz dengesi, dinamik aralık, gölgeler, parlak alanlar, kontrast, renk doğruluğu, gürültü ve keskinliği düzelt. İnsanların yüzünü/kimliğini, yazıları, nesneleri, geometriyi, perspektifi ve kadrajı KESİNLİKLE değiştirme; hiçbir şey ekleme veya kaldırma. Sonuç gerçekçi ve doğal olsun, HDR/filtre görünümü verme."\n    : action === "fix_light"\n    ? "Bu fotoğrafta SADECE ışığı profesyonelce düzelt. Patlayan parlak alanları mümkün olduğunca toparla, karanlık bölgelerde doğal detay aç, beyaz dengesini ve orta tonları dengele. Nesneleri, insanları, yüzleri, yazıları, renk kimliğini, geometriyi, perspektifi ve kadrajı değiştirme; hiçbir şey ekleme veya kaldırma. Fotoğrafı yıkama, gri/sisli yapma veya yapay HDR oluşturma."\n    : action === "custom_prompt"\n    ? `Mevcut fotoğrafı gerçekçi biçimde düzenle. Ana kişilerin kimliğini/yüzünü, yazıları, perspektifi ve kadrajı kullanıcı açıkça istemedikçe koru. Gereksiz nesne ekleme. Kullanıcı isteği: ${String(userPrompt || "").trim().slice(0, 1200)}`\n    : action === "remove_people"',
);

text = text.replace(
  '    if (!["auto_enhance", "fix_light"].includes(action)) return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });\n    const settings = await fastDevelopSettings(req.file.buffer, mode, action);\n    const output = await developPhoto(req.file.buffer, settings, action);',
  '    if (action === "auto_enhance" || action === "fix_light") {\n      const output = await generativeRemove(req.file.buffer, detectMimeType(req.file), action, null, null);\n      res.setHeader("Content-Type", "image/jpeg");\n      res.setHeader("X-Develop-Engine", action === "fix_light" ? "gpt-image-2-light" : "gpt-image-2-enhance");\n      res.setHeader("Cache-Control", "no-store");\n      return res.status(200).send(output);\n    }\n    return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });',
);

// Keep this compatibility fix in case an older server revision still contains CLAHE.
text = text.replaceAll("maxSlope: 1.35", "maxSlope: 2");

writeFileSync(path, text, "utf8");
