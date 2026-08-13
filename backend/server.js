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

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "En Iyi Cekim Noktasi AI Backend", developEngine: "mode-aware-v1" });
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

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v))); }

function fallbackDevelop(mode) {
  const m = String(mode || "").toLowerCase();
  if (m.includes("sinematik")) return { exposure:-0.22, highlights:-34, shadows:10, contrast:10, saturation:-6, warmth:4, sharpness:8 };
  if (m.includes("gece") || m.includes("astro")) return { exposure:0.12, highlights:-28, shadows:20, contrast:8, saturation:-5, warmth:-2, sharpness:7 };
  if (m.includes("portre")) return { exposure:0.05, highlights:-18, shadows:12, contrast:4, saturation:-2, warmth:3, sharpness:4 };
  if (m.includes("hareket")) return { exposure:0.00, highlights:-22, shadows:8, contrast:9, saturation:0, warmth:0, sharpness:12 };
  return { exposure:0.00, highlights:-24, shadows:10, contrast:6, saturation:-1, warmth:0, sharpness:7 };
}

async function aiDevelopSettings(buffer, mode) {
  const fallback = fallbackDevelop(mode);
  if (!process.env.OPENAI_API_KEY) return fallback;
  try {
    const mime = "image/jpeg";
    const preview = await sharp(buffer).rotate().resize({ width: 900, withoutEnlargement: true }).jpeg({ quality: 72 }).toBuffer();
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{ role: "user", content: [
        { type: "input_text", text: `Sen bir RAW/JPEG geliştirme uzmanısın. Seçili çekim modu: ${mode}. Görüntüyü yeniden üretmeyeceksin; sadece doğal fotoğraf geliştirme parametreleri seç. Amaç: gerçekçi görünüm, patlayan beyazları geri almak, gölgede detay, doğal ten ve moda uygun karakter. SADECE JSON döndür: {\"exposure\":0,\"highlights\":0,\"shadows\":0,\"contrast\":0,\"saturation\":0,\"warmth\":0,\"sharpness\":0}. Aralıklar: exposure -0.8..0.8 EV, highlights -60..20, shadows -20..50, contrast -20..25, saturation -20..20, warmth -12..12, sharpness 0..20. Sinematik modda özellikle highlight koru; portrede teni doğal tut; gecede gölgeyi aç ama siyahı griye çevirme; harekette mikro-kontrast ve keskinliği koru.` },
        { type: "input_image", image_url: `data:${mime};base64,${preview.toString("base64")}`, detail: "low" },
      ] }],
    });
    const p = parseModelJson(response.output_text);
    return {
      exposure: clamp(p.exposure, -0.8, 0.8), highlights: clamp(p.highlights, -60, 20),
      shadows: clamp(p.shadows, -20, 50), contrast: clamp(p.contrast, -20, 25),
      saturation: clamp(p.saturation, -20, 20), warmth: clamp(p.warmth, -12, 12),
      sharpness: clamp(p.sharpness, 0, 20),
    };
  } catch (e) {
    console.error("AI develop settings fallback", e);
    return fallback;
  }
}

async function developPhoto(buffer, settings, action) {
  const exposureGain = Math.pow(2, settings.exposure);
  const contrastGain = 1 + settings.contrast / 100;
  const saturation = 1 + settings.saturation / 100;
  const warmth = settings.warmth;
  const shadowLift = settings.shadows / 100 * 18;
  const highlightProtect = -settings.highlights / 100;

  let pipeline = sharp(buffer).rotate().toColorspace("srgb");
  pipeline = pipeline.modulate({ brightness: exposureGain, saturation });

  // Gentle filmic tone curve approximation: protect highlights, open shadows.
  const blackPoint = Math.round(clamp(shadowLift, -4, 12));
  const whiteCompression = clamp(1 - highlightProtect * 0.16, 0.88, 1.04);
  pipeline = pipeline.linear(contrastGain * whiteCompression, blackPoint - (contrastGain - 1) * 22);

  if (warmth !== 0) {
    const r = Math.round(clamp(255 + warmth * 1.8, 225, 255));
    const b = Math.round(clamp(255 - warmth * 2.2, 225, 255));
    pipeline = pipeline.tint({ r, g: 255, b });
  }

  const s = action === "fix_light" ? Math.max(3, settings.sharpness * 0.55) : settings.sharpness;
  if (s > 0) pipeline = pipeline.sharpen({ sigma: 0.45 + s / 35, m1: 0.55 + s / 35, m2: 1.2 });
  return pipeline.jpeg({ quality: 95, chromaSubsampling: "4:4:4", mozjpeg: true }).toBuffer();
}

app.post("/edit-photo", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Düzenlenecek fotoğraf gönderilmedi." });
    const action = String(req.body?.action || "auto_enhance");
    const mode = String(req.body?.mode || "Fotoğraf");
    if (action === "remove_people" || action === "remove_object") {
      return res.status(501).json({ error: "Nesne/insan kaldırma generatif düzenleme motoru henüz bağlı değil." });
    }
    if (!["auto_enhance", "fix_light"].includes(action)) {
      return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });
    }

    let settings = await aiDevelopSettings(req.file.buffer, mode);
    if (action === "fix_light") {
      settings = { ...settings, saturation: clamp(settings.saturation, -8, 8), sharpness: clamp(settings.sharpness, 0, 10) };
    }
    const output = await developPhoto(req.file.buffer, settings, action);
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("X-Develop-Engine", "mode-aware-v1");
    res.setHeader("Cache-Control", "no-store");
    return res.status(200).send(output);
  } catch (e) {
    console.error("Edit photo error", e);
    return res.status(500).json({ error: "Fotoğraf geliştirme başarısız." });
  }
});

app.listen(port, "0.0.0.0", () => console.log(`AI backend ${port} portunda çalışıyor.`));
