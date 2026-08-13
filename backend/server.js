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
    const fileName = String(file?.originalname || "").toLowerCase();
    if (fileName.endsWith(".png")) mimeType = "image/png";
    else if (fileName.endsWith(".webp")) mimeType = "image/webp";
    else mimeType = "image/jpeg";
  }
  return mimeType;
}

function parseModelJson(outputText) {
  const cleaned = String(outputText || "")
    .replaceAll("```json", "")
    .replaceAll("```", "")
    .trim();
  return JSON.parse(cleaned);
}

app.get("/", (req, res) => {
  res.json({ status: "ok", service: "En Iyi Cekim Noktasi AI Backend" });
});

app.post("/analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Fotoğraf gönderilmedi." });
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "OPENAI_API_KEY tanımlı değil." });
    }

    const mimeType = detectMimeType(req.file);
    const base64Image = req.file.buffer.toString("base64");
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: `Bu fotoğrafı profesyonel bir fotoğrafçı gibi analiz et. SADECE geçerli JSON döndür. Markdown kullanma. Şu formatı kullan: {"score":0,"composition":0,"lighting":0,"perspective":0,"sharpness":0,"summary":"","suggestions":[]}. score 0-100; diğer puanlar 0-10. summary Türkçe ve fotoğrafa özel olsun. suggestions 3-5 kısa uygulanabilir Türkçe öneri içersin. Görmediğin şeyi uydurma.`,
          },
          {
            type: "input_image",
            image_url: `data:${mimeType};base64,${base64Image}`,
            detail: "auto",
          },
        ],
      }],
    });

    return res.json(parseModelJson(response.output_text));
  } catch (error) {
    console.error("Analyze error:", error);
    return res.status(500).json({ error: "Fotoğraf analizi başarısız." });
  }
});

app.post("/live-analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Kamera karesi gönderilmedi." });
    const mimeType = detectMimeType(req.file);
    const base64Image = req.file.buffer.toString("base64");
    const mode = String(req.body?.mode || "Normal");

    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: `Sen gerçek zamanlı fotoğraf çekim asistanısın. Seçili çekim modu: ${mode}. Kullanıcı deklanşöre basmadan önce kısa yönlendirme ver. SADECE geçerli JSON döndür: {"status":"adjust","main_tip":"","composition_tip":"","light_tip":"","subject_tip":""}. status sadece good/adjust/warning. Tüm öneriler Türkçe ve en fazla 6-8 kelime olsun. Seçilen moda göre ışık, hareket ve ana özneyi değerlendir. Görmediğin şeyi uydurma.`,
          },
          {
            type: "input_image",
            image_url: `data:${mimeType};base64,${base64Image}`,
            detail: "low",
          },
        ],
      }],
    });

    const parsed = parseModelJson(response.output_text);
    return res.json({
      status: String(parsed.status || "adjust"),
      main_tip: String(parsed.main_tip || ""),
      composition_tip: String(parsed.composition_tip || ""),
      light_tip: String(parsed.light_tip || ""),
      subject_tip: String(parsed.subject_tip || ""),
    });
  } catch (error) {
    console.error("Live analyze error:", error);
    return res.status(500).json({ error: "Canlı kadraj analizi başarısız." });
  }
});

function modeProfile(mode) {
  const m = String(mode || "").toLowerCase();
  if (m.includes("sinematik")) {
    return { brightness: 0.93, saturation: 0.94, contrast: 1.10, warmth: true };
  }
  if (m.includes("gece") || m.includes("astro")) {
    return { brightness: 1.06, saturation: 0.92, contrast: 1.08, warmth: false };
  }
  if (m.includes("portre")) {
    return { brightness: 1.01, saturation: 0.98, contrast: 1.04, warmth: true };
  }
  return { brightness: 0.98, saturation: 0.97, contrast: 1.06, warmth: false };
}

async function processPhoto(buffer, action, mode) {
  const profile = modeProfile(mode);
  let pipeline = sharp(buffer).rotate();

  if (action === "fix_light") {
    pipeline = pipeline
      .modulate({ brightness: mode?.toLowerCase().includes("gece") ? 1.08 : 0.94, saturation: 0.98 })
      .linear(1.08, -7)
      .sharpen({ sigma: 0.55, m1: 0.7, m2: 1.4 });
  } else if (action === "auto_enhance") {
    pipeline = pipeline
      .modulate({ brightness: profile.brightness, saturation: profile.saturation })
      .linear(profile.contrast, profile.contrast > 1 ? -5 : 0)
      .sharpen({ sigma: 0.6, m1: 0.75, m2: 1.5 });
  } else {
    throw new Error("UNSUPPORTED_EDIT_ACTION");
  }

  if (profile.warmth) {
    pipeline = pipeline.tint({ r: 255, g: 248, b: 238 });
  }

  return pipeline.jpeg({ quality: 94, chromaSubsampling: "4:4:4" }).toBuffer();
}

app.post("/edit-photo", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Düzenlenecek fotoğraf gönderilmedi." });

    const action = String(req.body?.action || "auto_enhance");
    const mode = String(req.body?.mode || "Fotoğraf");

    if (action === "remove_people" || action === "remove_object") {
      return res.status(501).json({
        error: "Nesne/insan kaldırma AI görüntü düzenleme servisi henüz bağlı değil.",
      });
    }

    const output = await processPhoto(req.file.buffer, action, mode);
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("Cache-Control", "no-store");
    return res.status(200).send(output);
  } catch (error) {
    console.error("Edit photo error:", error);
    if (String(error?.message || "").includes("UNSUPPORTED_EDIT_ACTION")) {
      return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });
    }
    return res.status(500).json({ error: "Fotoğraf düzenleme başarısız." });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`AI backend ${port} portunda çalışıyor.`);
});
