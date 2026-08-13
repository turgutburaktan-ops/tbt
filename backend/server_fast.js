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

function clamp(v, lo, hi) {
  const n = Number(v);
  return Math.max(lo, Math.min(hi, Number.isFinite(n) ? n : 0));
}

function detectMimeType(file) {
  let mime = file?.mimetype || "";
  if (!mime || mime === "application/octet-stream") {
    const name = String(file?.originalname || "").toLowerCase();
    mime = name.endsWith(".png") ? "image/png" : name.endsWith(".webp") ? "image/webp" : "image/jpeg";
  }
  return mime;
}

function parseModelJson(text) {
  return JSON.parse(String(text || "").replaceAll("```json", "").replaceAll("```", "").trim());
}

async function imageMetrics(buffer) {
  const { data, info } = await sharp(buffer)
    .rotate()
    .resize({ width: 256, height: 256, fit: "inside", withoutEnlargement: true })
    .removeAlpha()
    .toColourspace("srgb")
    .raw()
    .toBuffer({ resolveWithObject: true });

  let sum = 0;
  let sumSq = 0;
  let bright = 0;
  let dark = 0;
  const pixels = Math.max(1, info.width * info.height);
  for (let i = 0; i < data.length; i += 3) {
    const y = 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
    sum += y;
    sumSq += y * y;
    if (y > 238) bright++;
    if (y < 24) dark++;
  }
  const mean = sum / pixels;
  const variance = Math.max(0, sumSq / pixels - mean * mean);
  return {
    mean,
    contrast: Math.sqrt(variance),
    highlightRatio: bright / pixels,
    shadowRatio: dark / pixels,
  };
}

function liveDecision(metrics, mode) {
  const m = String(mode || "Normal").toLowerCase();

  // V5: small ceiling lamps/windows must not make a mostly dark frame look
  // globally overexposed. Protect highlights aggressively only when the whole
  // frame is already bright, or when clipped whites occupy a very large area.
  const blown =
    metrics.mean > 190 ||
    (metrics.mean > 145 && metrics.highlightRatio > 0.10) ||
    metrics.highlightRatio > 0.24;
  const veryDark = metrics.mean < 52;
  const dark = metrics.mean < 82;
  const flat = metrics.contrast < 28;

  let status = "good";
  let main = "Kadraj hazır — çekebilirsin.";
  let light = "Işık dengeli.";
  let subject = "";

  if (veryDark) {
    status = "adjust";
    main = m.includes("hareket") ? "Işık az — shutter hızını koru." : "Düşük ışık — pozlamayı artır.";
    light = "Gölgelerde detay koru.";
  } else if (dark) {
    status = "adjust";
    main = "Işık düşük — modu dengeliyorum.";
    light = "Gürültüyü sınırlı tut.";
  } else if (blown) {
    status = "adjust";
    main = "Pozlamayı hafif azalt, parlak alanı koru.";
    light = "Parlak alanları koru.";
  } else if (flat) {
    status = "adjust";
    main = "Kontrast düşük — tonu güçlendir.";
    light = "Orta tonları ayır.";
  }

  if (m.includes("portre")) subject = "Yüz netliği öncelikli.";
  if (m.includes("sinematik")) subject = "Highlight ve atmosfer öncelikli.";
  if (m.includes("gece")) subject = "Işıkları patlatmadan koru.";
  if (m.includes("astro")) subject = "Telefonu sabit tut.";
  if (m.includes("hareket")) subject = "Hızlı shutter öncelikli.";

  return {
    status,
    main_tip: main,
    composition_tip: "",
    light_tip: light,
    subject_tip: subject,
  };
}

function baseDevelop(mode) {
  const m = String(mode || "").toLowerCase();
  if (m.includes("sinematik")) return { exposure:-0.18, highlights:-40, shadows:8, contrast:11, saturation:-3, warmth:2, sharpness:6 };
  if (m.includes("gece")) return { exposure:0.08, highlights:-34, shadows:18, contrast:8, saturation:-2, warmth:-1, sharpness:5 };
  if (m.includes("astro")) return { exposure:0.04, highlights:-26, shadows:12, contrast:12, saturation:2, warmth:-2, sharpness:8 };
  if (m.includes("portre")) return { exposure:0.02, highlights:-22, shadows:10, contrast:3, saturation:1, warmth:2, sharpness:3 };
  if (m.includes("hareket")) return { exposure:-0.02, highlights:-24, shadows:7, contrast:10, saturation:0, warmth:0, sharpness:10 };
  if (m.includes("pro")) return { exposure:0.00, highlights:-26, shadows:8, contrast:5, saturation:0, warmth:0, sharpness:5 };
  // Normal is deliberately neutral. It should look like a polished phone camera,
  // not like a creative preset.
  return { exposure:0.03, highlights:-20, shadows:9, contrast:4, saturation:1, warmth:0, sharpness:5 };
}

async function fastDevelopSettings(buffer, mode, action) {
  const metrics = await imageMetrics(buffer);
  const s = { ...baseDevelop(mode) };

  if (metrics.mean > 195 || (metrics.mean > 150 && metrics.highlightRatio > 0.12)) {
    s.exposure -= 0.14;
    s.highlights -= 10;
  } else if (metrics.mean < 62) {
    s.exposure += 0.24;
    s.shadows += 11;
  } else if (metrics.mean < 92) {
    s.exposure += 0.12;
    s.shadows += 6;
  }

  if (metrics.contrast < 28) s.contrast += 3;
  if (metrics.contrast > 72) s.contrast -= 3;

  if (action === "fix_light") {
    s.saturation = clamp(s.saturation, -2, 4);
    s.sharpness = clamp(s.sharpness, 0, 4);
    s.highlights = Math.min(s.highlights, -14);
    s.shadows = Math.max(s.shadows, 9);
  }

  return {
    exposure: clamp(s.exposure, -0.40, 0.48),
    highlights: clamp(s.highlights, -52, 5),
    shadows: clamp(s.shadows, -5, 38),
    contrast: clamp(s.contrast, -8, 16),
    saturation: clamp(s.saturation, -6, 10),
    warmth: clamp(s.warmth, -6, 6),
    sharpness: clamp(s.sharpness, 0, 10),
  };
}

async function developPhoto(buffer, settings, action) {
  const exposureGain = Math.pow(2, settings.exposure);
  const saturation = 1 + settings.saturation / 100;
  const contrast = settings.contrast / 100;
  const highlightCompression = clamp((-settings.highlights) / 100 * 0.09, 0, 0.06);
  const shadowOffset = clamp(settings.shadows / 100 * 10, -2, 8);
  const gain = clamp((1 + contrast) * (1 - highlightCompression), 0.89, 1.13);
  const offset = clamp(shadowOffset - contrast * 15, -6, 10);

  let pipeline = sharp(buffer)
    .rotate()
    .removeAlpha()
    .toColourspace("srgb")
    .modulate({ brightness: exposureGain, saturation })
    .linear([gain, gain, gain], [offset, offset, offset]);

  if (Math.abs(settings.warmth) > 0.05) {
    const r = clamp(1 + settings.warmth * 0.0035, 0.975, 1.025);
    const b = clamp(1 - settings.warmth * 0.0035, 0.975, 1.025);
    pipeline = pipeline.linear([r, 1, b], [0, 0, 0]);
  }

  const sharpen = action === "fix_light" ? Math.min(3.5, settings.sharpness) : settings.sharpness;
  if (sharpen > 0.5) pipeline = pipeline.sharpen({ sigma: 0.5 + sharpen / 38 });

  return pipeline.jpeg({ quality: 94, chromaSubsampling: "4:4:4" }).toBuffer();
}

async function generativeRemove(buffer, mimeType, action, pointX, pointY) {
  if (!process.env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY tanımlı değil.");

  const prompt = action === "remove_people"
    ? "Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme."
    : `Fotoğrafı koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve alanı doğal çevre dokusuyla doldur. Diğer insanları ve nesneleri değiştirme.`;

  const form = new FormData();
  form.append("model", "gpt-image-2");
  form.append("prompt", prompt);
  form.append("image", new Blob([buffer], { type: mimeType }), "input.jpg");
  form.append("size", "auto");
  form.append("quality", "medium");
  form.append("output_format", "jpeg");

  const response = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    body: form,
  });
  if (!response.ok) throw new Error(`Image edit ${response.status}: ${await response.text()}`);
  const json = await response.json();
  const b64 = json?.data?.[0]?.b64_json;
  if (!b64) throw new Error("Generatif düzenleme görsel döndürmedi.");
  return Buffer.from(b64, "base64");
}

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "En Iyi Cekim Noktasi AI Backend", liveEngine: "fast-meter-v2", developEngine: "fast-mode-develop-v4" });
});

app.post("/live-analyze", upload.single("image"), async (req, res) => {
  const started = Date.now();
  try {
    if (!req.file) return res.status(400).json({ error: "Kamera karesi gönderilmedi." });
    const metrics = await imageMetrics(req.file.buffer);
    const result = liveDecision(metrics, req.body?.mode || "Normal");
    res.setHeader("X-Live-Engine", "fast-meter-v2");
    res.setHeader("X-Processing-Ms", String(Date.now() - started));
    return res.json(result);
  } catch (e) {
    console.error("Fast live analyze error", e);
    return res.status(500).json({ error: "Canlı sahne analizi başarısız." });
  }
});

app.post("/analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Fotoğraf gönderilmedi." });
    if (!process.env.OPENAI_API_KEY) return res.status(503).json({ error: "AI anahtarı tanımlı değil." });
    const mime = detectMimeType(req.file);
    const image = req.file.buffer.toString("base64");
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [{ role: "user", content: [
        { type: "input_text", text: "Bu fotoğrafı profesyonel fotoğrafçı gibi analiz et. SADECE JSON: {\"score\":0,\"composition\":0,\"lighting\":0,\"perspective\":0,\"sharpness\":0,\"summary\":\"\",\"suggestions\":[]}. Türkçe, kısa ve fotoğrafa özel." },
        { type: "input_image", image_url: `data:${mime};base64,${image}`, detail: "low" },
      ] }],
    });
    return res.json(parseModelJson(response.output_text));
  } catch (e) {
    console.error("Analyze error", e);
    return res.status(500).json({ error: "Fotoğraf analizi başarısız." });
  }
});

app.post("/edit-photo", upload.single("image"), async (req, res) => {
  const started = Date.now();
  try {
    if (!req.file) return res.status(400).json({ error: "Düzenlenecek fotoğraf gönderilmedi." });
    const action = String(req.body?.action || "auto_enhance");
    const mode = String(req.body?.mode || "Normal");

    if (action === "remove_people" || action === "remove_object") {
      const x = req.body?.point_x != null ? clamp(req.body.point_x, 0, 1) : null;
      const y = req.body?.point_y != null ? clamp(req.body.point_y, 0, 1) : null;
      if (action === "remove_object" && (x == null || y == null)) return res.status(400).json({ error: "Nesne konumu seçilmedi." });
      const output = await generativeRemove(req.file.buffer, detectMimeType(req.file), action, x, y);
      res.setHeader("Content-Type", "image/jpeg");
      res.setHeader("X-Develop-Engine", "gpt-image-2-edit");
      return res.status(200).send(output);
    }

    if (!["auto_enhance", "fix_light"].includes(action)) return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });

    const settings = await fastDevelopSettings(req.file.buffer, mode, action);
    const output = await developPhoto(req.file.buffer, settings, action);
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("X-Develop-Engine", "fast-mode-develop-v4");
    res.setHeader("X-Processing-Ms", String(Date.now() - started));
    res.setHeader("Cache-Control", "no-store");
    return res.status(200).send(output);
  } catch (e) {
    console.error("Edit photo error", e);
    return res.status(500).json({ error: "Fotoğraf düzenleme başarısız.", detail: String(e?.message || e) });
  }
});

app.listen(port, "0.0.0.0", () => console.log(`Fast hybrid AI backend ${port} portunda çalışıyor.`));
