import express from "express";
import cors from "cors";
import multer from "multer";
import OpenAI from "openai";
import sharp from "sharp";

const app = express();
const port = process.env.PORT || 10000;
app.use(cors());
app.use(express.json({ limit: "2mb" }));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 },
});

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

function detectMimeType(file) {
  let mimeType = file?.mimetype || "";
  if (!mimeType || mimeType === "application/octet-stream") {
    const n = String(file?.originalname || "").toLowerCase();
    mimeType = n.endsWith(".png") ? "image/png" : n.endsWith(".webp") ? "image/webp" : "image/jpeg";
  }
  return mimeType;
}

function parseModelJson(text) {
  return JSON.parse(String(text || "").replaceAll("```json", "").replaceAll("```", "").trim());
}

function clamp(v, lo, hi) {
  const n = Number(v);
  return Math.max(lo, Math.min(hi, Number.isFinite(n) ? n : 0));
}

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "En Iyi Cekim Noktasi AI Backend", developEngine: "mode-aware-v2" });
});

app.post("/analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Fotoğraf gönderilmedi." });
    const mimeType = detectMimeType(req.file);
    const image = req.file.buffer.toString("base64");
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{ role: "user", content: [
        { type: "input_text", text: "Bu fotoğrafı profesyonel bir fotoğrafçı gibi analiz et. SADECE JSON döndür: {\"score\":0,\"composition\":0,\"lighting\":0,\"perspective\":0,\"sharpness\":0,\"summary\":\"\",\"suggestions\":[]}. score 0-100, diğerleri 0-10. Türkçe, kısa ve fotoğrafa özel ol." },
        { type: "input_image", image_url: `data:${mimeType};base64,${image}`, detail: "auto" },
      ] }],
    });
    return res.json(parseModelJson(response.output_text));
  } catch (e) {
    console.error("Analyze error", e);
    return res.status(500).json({ error: "Fotoğraf analizi başarısız." });
  }
});

app.post("/live-analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Kamera karesi gönderilmedi." });
    const mode = String(req.body?.mode || "Fotoğraf");
    const mimeType = detectMimeType(req.file);
    const image = req.file.buffer.toString("base64");
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{ role: "user", content: [
        { type: "input_text", text: `Gerçek zamanlı fotoğraf asistanısın. Seçili mod: ${mode}. SADECE JSON: {\"status\":\"adjust\",\"main_tip\":\"\",\"composition_tip\":\"\",\"light_tip\":\"\",\"subject_tip\":\"\"}. Öneriler Türkçe, en fazla 8 kelime. Seçilen modun amacına göre ışık, hareket, özne ve kadrajı değerlendir.` },
        { type: "input_image", image_url: `data:${mimeType};base64,${image}`, detail: "low" },
      ] }],
    });
    const p = parseModelJson(response.output_text);
    return res.json({
      status: String(p.status || "adjust"), main_tip: String(p.main_tip || ""),
      composition_tip: String(p.composition_tip || ""), light_tip: String(p.light_tip || ""),
      subject_tip: String(p.subject_tip || ""),
    });
  } catch (e) {
    console.error("Live analyze error", e);
    return res.status(500).json({ error: "Canlı kadraj analizi başarısız." });
  }
});

function fallbackDevelop(mode) {
  const m = String(mode || "").toLowerCase();
  if (m.includes("sinematik")) return { exposure:-0.16, highlights:-34, shadows:10, contrast:9, saturation:-4, warmth:3, sharpness:7 };
  if (m.includes("gece") || m.includes("astro")) return { exposure:0.10, highlights:-30, shadows:18, contrast:7, saturation:-2, warmth:-1, sharpness:6 };
  if (m.includes("portre")) return { exposure:0.04, highlights:-18, shadows:11, contrast:3, saturation:1, warmth:2, sharpness:3 };
  if (m.includes("hareket")) return { exposure:0.00, highlights:-22, shadows:8, contrast:8, saturation:0, warmth:0, sharpness:10 };
  return { exposure:0.00, highlights:-24, shadows:10, contrast:5, saturation:0, warmth:0, sharpness:6 };
}

async function aiDevelopSettings(buffer, mode) {
  const fallback = fallbackDevelop(mode);
  if (!process.env.OPENAI_API_KEY) return fallback;
  try {
    const preview = await sharp(buffer).rotate().resize({ width: 900, withoutEnlargement: true }).jpeg({ quality: 72 }).toBuffer();
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{ role: "user", content: [
        { type: "input_text", text: `Sen bir doğal fotoğraf geliştirme uzmanısın. Seçili çekim modu: ${mode}. Görüntüyü yeniden üretme; sadece doğal geliştirme değerleri seç. Renkleri koru, fotoğrafı siyah-beyaz yapma, beyazları patlatma, gölgede detay tut, tenleri doğal bırak. SADECE JSON: {\"exposure\":0,\"highlights\":0,\"shadows\":0,\"contrast\":0,\"saturation\":0,\"warmth\":0,\"sharpness\":0}. Aralıklar: exposure -0.6..0.6, highlights -55..10, shadows -10..40, contrast -15..20, saturation -12..15, warmth -8..8, sharpness 0..16.` },
        { type: "input_image", image_url: `data:image/jpeg;base64,${preview.toString("base64")}`, detail: "low" },
      ] }],
    });
    const p = parseModelJson(response.output_text);
    return {
      exposure: clamp(p.exposure, -0.6, 0.6), highlights: clamp(p.highlights, -55, 10),
      shadows: clamp(p.shadows, -10, 40), contrast: clamp(p.contrast, -15, 20),
      saturation: clamp(p.saturation, -12, 15), warmth: clamp(p.warmth, -8, 8),
      sharpness: clamp(p.sharpness, 0, 16),
    };
  } catch (e) {
    console.error("AI develop settings fallback", e);
    return fallback;
  }
}

async function developPhoto(buffer, settings, action) {
  const exposureGain = Math.pow(2, clamp(settings.exposure, -0.6, 0.6));
  const saturation = clamp(1 + settings.saturation / 100, 0.85, 1.15);
  const contrast = clamp(settings.contrast / 100, -0.15, 0.20);
  const shadowOffset = clamp(settings.shadows / 100 * 11, -3, 8);
  const highlightCompression = clamp((-settings.highlights) / 100 * 0.10, 0, 0.07);
  const warmth = clamp(settings.warmth, -8, 8);

  let pipeline = sharp(buffer)
    .rotate()
    .removeAlpha()
    .toColourspace("srgb")
    .modulate({ brightness: exposureGain, saturation });

  // Gentle contrast/highlight control. Keep all three RGB channels independent.
  const gain = clamp((1 + contrast) * (1 - highlightCompression), 0.86, 1.16);
  const offset = clamp(shadowOffset - contrast * 20, -8, 10);
  pipeline = pipeline.linear([gain, gain, gain], [offset, offset, offset]);

  // IMPORTANT: Sharp.tint() colorizes the whole frame and caused the previous
  // black-and-white/monochrome result. Warmth is now a subtle per-channel gain.
  if (Math.abs(warmth) > 0.05) {
    const redGain = clamp(1 + warmth * 0.0045, 0.965, 1.04);
    const blueGain = clamp(1 - warmth * 0.0045, 0.965, 1.04);
    pipeline = pipeline.linear([redGain, 1.0, blueGain], [0, 0, 0]);
  }

  const s = action === "fix_light"
    ? clamp(settings.sharpness * 0.45, 0, 5)
    : clamp(settings.sharpness, 0, 10);
  if (s > 0.5) {
    pipeline = pipeline.sharpen({ sigma: 0.55 + s / 30 });
  }

  return pipeline.jpeg({ quality: 95, chromaSubsampling: "4:4:4" }).toBuffer();
}

async function generativeRemove(buffer, mimeType, action, pointX, pointY) {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY tanımlı değil.");
  }

  const prompt = action === "remove_people"
    ? "Bu fotoğrafın ana konusunu, yüzleri, kıyafetleri, mimariyi, yazıları, renkleri, ışığı ve kadrajı aynen koru. Yalnızca arka plandaki dikkat dağıtan insanları doğal biçimde kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi kesinlikle kaldırma veya değiştirme. Yeni nesne ekleme."
    : `Bu fotoğrafı mümkün olduğunca aynen koru. Yalnızca normalize koordinatı x=${pointX ?? 0.5}, y=${pointY ?? 0.5} civarında kullanıcının işaret ettiği nesneyi kaldır ve oluşan alanı çevredeki gerçek doku, ışık ve perspektifle doğal biçimde doldur. İnsan yüzlerini ve diğer nesneleri değiştirme. Yeni nesne ekleme.`;

  const form = new FormData();
  form.append("model", "gpt-image-2");
  form.append("prompt", prompt);
  form.append("image", new Blob([buffer], { type: mimeType }), "input.jpg");
  form.append("size", "auto");
  form.append("quality", "medium");
  form.append("output_format", "jpeg");
  form.append("output_compression", "94");

  let response = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    body: form,
  });

  // Compatibility retry in case an account/API version rejects optional fields.
  if (!response.ok && response.status === 400) {
    const retry = new FormData();
    retry.append("model", "gpt-image-2");
    retry.append("prompt", prompt);
    retry.append("image", new Blob([buffer], { type: mimeType }), "input.jpg");
    response = await fetch("https://api.openai.com/v1/images/edits", {
      method: "POST",
      headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      body: retry,
    });
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Image edit ${response.status}: ${errorText}`);
  }

  const json = await response.json();
  const b64 = json?.data?.[0]?.b64_json;
  if (!b64) throw new Error("Generatif düzenleme görsel döndürmedi.");
  return Buffer.from(b64, "base64");
}

app.post("/edit-photo", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Düzenlenecek fotoğraf gönderilmedi." });
    const action = String(req.body?.action || "auto_enhance");
    const mode = String(req.body?.mode || "Fotoğraf");

    if (action === "remove_people" || action === "remove_object") {
      const x = req.body?.point_x != null ? clamp(req.body.point_x, 0, 1) : null;
      const y = req.body?.point_y != null ? clamp(req.body.point_y, 0, 1) : null;
      if (action === "remove_object" && (x == null || y == null)) {
        return res.status(400).json({ error: "Kaldırılacak nesne için konum seçilmedi." });
      }
      const output = await generativeRemove(req.file.buffer, detectMimeType(req.file), action, x, y);
      res.setHeader("Content-Type", "image/jpeg");
      res.setHeader("X-Develop-Engine", "gpt-image-2-edit");
      res.setHeader("Cache-Control", "no-store");
      return res.status(200).send(output);
    }

    if (!["auto_enhance", "fix_light"].includes(action)) {
      return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });
    }

    let settings = await aiDevelopSettings(req.file.buffer, mode);
    if (action === "fix_light") {
      settings = {
        ...settings,
        saturation: clamp(settings.saturation, -5, 8),
        sharpness: clamp(settings.sharpness, 0, 7),
        highlights: Math.min(settings.highlights, -12),
        shadows: Math.max(settings.shadows, 6),
      };
    }

    let output;
    try {
      output = await developPhoto(req.file.buffer, settings, action);
    } catch (primaryError) {
      console.error("Develop primary failed; safe fallback", primaryError);
      const safe = fallbackDevelop(mode);
      output = await sharp(req.file.buffer)
        .rotate()
        .removeAlpha()
        .toColourspace("srgb")
        .modulate({ brightness: Math.pow(2, safe.exposure), saturation: 1 + safe.saturation / 100 })
        .jpeg({ quality: 94, chromaSubsampling: "4:4:4" })
        .toBuffer();
    }

    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("X-Develop-Engine", "mode-aware-v2");
    res.setHeader("Cache-Control", "no-store");
    return res.status(200).send(output);
  } catch (e) {
    console.error("Edit photo error", e);
    return res.status(500).json({ error: "Fotoğraf düzenleme başarısız.", detail: String(e?.message || e) });
  }
});

app.listen(port, "0.0.0.0", () => console.log(`AI backend ${port} portunda çalışıyor.`));
