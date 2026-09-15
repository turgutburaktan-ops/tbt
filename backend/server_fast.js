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
    mime = name.endsWith(".png")
      ? "image/png"
      : name.endsWith(".webp")
        ? "image/webp"
        : "image/jpeg";
  }
  return mime;
}

function parseModelJson(text) {
  return JSON.parse(
    String(text || "")
      .replaceAll("```json", "")
      .replaceAll("```", "")
      .trim(),
  );
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
  return {
    mean,
    contrast: Math.sqrt(Math.max(0, sumSq / pixels - mean * mean)),
    highlightRatio: bright / pixels,
    shadowRatio: dark / pixels,
  };
}

function liveDecision(metrics, mode) {
  const m = String(mode || "Normal").toLowerCase();
  const blown = metrics.mean > 188 || metrics.highlightRatio > 0.18;
  const dark = metrics.mean < 82;
  const veryDark = metrics.mean < 48;

  let ev = 0;
  if (blown) ev = -0.35;
  else if (metrics.mean > 155) ev = -0.18;
  else if (veryDark) ev = 0.30;
  else if (dark) ev = 0.15;

  let iso = 100;
  let shutter = 125;
  let subject = "Dengeli otomatik çekim.";

  if (m.includes("portre")) {
    shutter = dark ? 125 : 250;
    iso = veryDark ? 800 : dark ? 400 : 100;
    ev = clamp(ev, -0.35, 0.18);
    subject = "Yüz ve göz netliği öncelikli; ten tonlarını ve parlak alanları koru.";
  } else if (m.includes("manzara")) {
    shutter = dark ? 80 : 160;
    iso = dark ? 200 : 100;
    ev = Math.min(ev, -0.08);
    subject = "Geniş dinamik aralık ve uzak detay öncelikli; gökyüzünü patlatma.";
  } else if (m.includes("spor")) {
    shutter = veryDark ? 500 : dark ? 640 : 1000;
    iso = veryDark ? 1600 : dark ? 800 : 320;
    ev = clamp(ev, -0.25, 0.12);
    subject = "Hareketi dondur; hızlı shutter öncelikli, ışığı ISO ile telafi et.";
  } else if (m.includes("gece")) {
    shutter = veryDark ? 15 : 30;
    iso = veryDark ? 1250 : dark ? 800 : 400;
    ev = clamp(Math.max(ev, 0.05), -0.10, 0.35);
    subject = "Telefon sabitse daha fazla ışık topla; ışık kaynaklarını patlatma.";
  } else if (m.includes("makro")) {
    shutter = dark ? 160 : 250;
    iso = veryDark ? 800 : dark ? 400 : 125;
    ev = clamp(ev, -0.25, 0.12);
    subject = "Yakın nesne netliği ve mikro titreşim kontrolü öncelikli.";
  } else {
    iso = veryDark ? 640 : dark ? 320 : 100;
    shutter = veryDark ? 60 : dark ? 100 : 125;
    ev = clamp(ev, -0.30, 0.22);
  }

  let main = "Kadraj hazır — çekebilirsin.";
  let light = "Işık dengeli.";
  if (blown) {
    main = "Parlak alanları koruyorum.";
    light = "Pozlamayı kontrollü azalt.";
  } else if (veryDark) {
    main = m.includes("spor")
      ? "Işık az; hareketi donduracak hızı koruyorum."
      : "Düşük ışığı moda göre dengeliyorum.";
    light = "Gölgelerde detay koru, gürültüyü sınırlı tut.";
  } else if (dark) {
    main = "Işık düşük; modu güvenli sınırlar içinde dengeliyorum.";
    light = "Orta tonları koru.";
  }

  return {
    status: blown || dark ? "adjust" : "good",
    main_tip: main,
    composition_tip: "",
    light_tip: light,
    subject_tip: subject,
    recommended_ev: Number(ev.toFixed(2)),
    recommended_iso: iso,
    recommended_shutter_denominator: shutter,
  };
}

function editPrompt(action, userPrompt, pointX, pointY) {
  switch (action) {
    case "auto_enhance":
      return "Bu fotoğrafı profesyonel bir fotoğraf editörü gibi doğal biçimde iyileştir. Pozlama, beyaz dengesi, dinamik aralık, gölgeler, parlak alanlar, kontrast, renk doğruluğu, gürültü ve keskinliği sahneye göre düzelt. İnsanların yüzünü ve kimliğini, yazıları, nesneleri, geometriyi, perspektifi ve kadrajı değiştirme. Hiçbir şey ekleme veya kaldırma. Fotoğrafı gri, soluk, aşırı HDR veya filtreli yapma. Sonuç gerçekçi ve temiz olsun.";
    case "fix_light":
      return "Bu fotoğrafta yalnızca ışık ve ton dengesini profesyonelce düzelt. Patlayan parlak alanları mümkün olduğunca toparla, karanlık bölgelerde doğal detay aç, orta tonları ve beyaz dengesini düzelt. Nesneleri, insanları, yüzleri, yazıları, renk kimliğini, perspektifi ve kadrajı değiştirme. Hiçbir şey ekleme veya kaldırma. Fotoğrafı yıkama, sisli/gri yapma, solarize etme veya yapay HDR görünümü verme.";
    case "remove_people":
      return "Fotoğrafın ana konusunu, yüzleri, yazıları, renkleri, ışığı ve kadrajı koru. Yalnızca arka plandaki dikkat dağıtan insanları kaldır ve boşlukları gerçekçi çevre dokusuyla doldur. Ana kişiyi değiştirme.";
    case "remove_object":
      return `Fotoğrafın tamamını koru. Yalnızca normalize x=${pointX ?? 0.5}, y=${pointY ?? 0.5} koordinatı çevresindeki seçili nesneyi kaldır ve oluşan boşluğu doğal çevre dokusuyla doldur. Diğer insanları, nesneleri, yazıları, ışığı, perspektifi ve kadrajı değiştirme.`;
    case "custom_prompt":
      return `Mevcut fotoğrafı gerçekçi biçimde düzenle. Kullanıcı açıkça istemedikçe insanların yüzünü/kimliğini, yazıları, perspektifi, geometriyi ve kadrajı koru. Gereksiz nesne ekleme. Kullanıcının talebi: ${String(userPrompt || "").trim().slice(0, 1200)}`;
    default:
      throw new Error("Geçersiz düzenleme işlemi.");
  }
}

function legacyDevelopProfile(mode, metrics, action) {
  const normalizedMode = String(mode || "Fotoğraf").toLowerCase();
  const settings = normalizedMode.includes("gece")
    ? { exposure: 0.08, saturation: -2, contrast: 8, warmth: -1, sharpness: 5 }
    : normalizedMode.includes("portre")
      ? { exposure: 0.04, saturation: 1, contrast: 3, warmth: 2, sharpness: 3 }
      : { exposure: 0, saturation: 0, contrast: 6, warmth: 0, sharpness: 6 };

  if (metrics.mean < 62) settings.exposure += 0.20;
  else if (metrics.mean < 92) settings.exposure += 0.10;
  else if (metrics.mean > 195 || metrics.highlightRatio > 0.10) {
    settings.exposure -= 0.22;
  }
  if (metrics.contrast < 28) settings.contrast += 4;
  if (metrics.contrast > 72) settings.contrast -= 3;
  if (action === "fix_light") {
    settings.saturation = clamp(settings.saturation, -3, 4);
    settings.sharpness = clamp(settings.sharpness, 0, 4);
  }
  return settings;
}

async function legacyDevelopPhoto(buffer, mode, action) {
  const settings = legacyDevelopProfile(
    mode,
    await imageMetrics(buffer),
    action,
  );
  const brightness = Math.pow(2, clamp(settings.exposure, -0.5, 0.4));
  const saturation = clamp(1 + settings.saturation / 100, 0.90, 1.10);
  const contrast = clamp(settings.contrast / 100, -0.08, 0.16);
  const gain = 1 + contrast;
  const offset = -contrast * 16;
  let pipeline = sharp(buffer)
    .rotate()
    .removeAlpha()
    .toColourspace("srgb")
    .modulate({ brightness, saturation })
    .linear([gain, gain, gain], [offset, offset, offset]);

  if (Math.abs(settings.warmth) > 0.05) {
    const red = clamp(1 + settings.warmth * 0.0035, 0.975, 1.025);
    const blue = clamp(1 - settings.warmth * 0.0035, 0.975, 1.025);
    pipeline = pipeline.linear([red, 1, blue], [0, 0, 0]);
  }
  if (settings.sharpness > 0.5) {
    pipeline = pipeline.sharpen({ sigma: 0.5 + settings.sharpness / 36 });
  }
  return pipeline
    .jpeg({ quality: 94, chromaSubsampling: "4:4:4" })
    .toBuffer();
}

async function prepareAiInput(buffer) {
  return sharp(buffer)
    .rotate()
    .removeAlpha()
    .toColourspace("srgb")
    .jpeg({ quality: 95, chromaSubsampling: "4:4:4" })
    .toBuffer({ resolveWithObject: true });
}

async function buildRemovalMask(width, height, pointX, pointY) {
  const x = Math.round(clamp(pointX, 0, 1) * width);
  const y = Math.round(clamp(pointY, 0, 1) * height);
  const radius = Math.round(Math.min(width, height) * 0.13);
  const svg = Buffer.from(`
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <mask id="edit-region">
          <rect width="100%" height="100%" fill="white"/>
          <circle cx="${x}" cy="${y}" r="${radius}" fill="black"/>
        </mask>
      </defs>
      <rect width="100%" height="100%" fill="white" mask="url(#edit-region)"/>
    </svg>
  `);
  return sharp(svg).png().toBuffer();
}

async function aiImageEdit(buffer, mimeType, action, { pointX, pointY, userPrompt } = {}) {
  if (!process.env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY tanımlı değil.");

  const prepared = await prepareAiInput(buffer);

  const form = new FormData();
  form.append("model", "gpt-image-2");
  form.append("prompt", editPrompt(action, userPrompt, pointX, pointY));
  form.append("image", new Blob([prepared.data], { type: "image/jpeg" }), "input.jpg");
  if (action === "remove_object" && pointX != null && pointY != null) {
    const mask = await buildRemovalMask(
      prepared.info.width,
      prepared.info.height,
      pointX,
      pointY,
    );
    form.append("mask", new Blob([mask], { type: "image/png" }), "mask.png");
  }
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
  if (!b64) throw new Error("AI düzenleme görsel döndürmedi.");
  return Buffer.from(b64, "base64");
}

app.get("/", (_req, res) =>
  res.json({
    status: "ok",
    service: "En Iyi Cekim Noktasi AI Backend",
    liveEngine: "mode-aware-meter-v4",
    developEngine: "gpt-image-2-all-edits",
  }),
);

app.post("/live-analyze", upload.single("image"), async (req, res) => {
  const started = Date.now();
  try {
    if (!req.file) return res.status(400).json({ error: "Kamera karesi gönderilmedi." });
    const result = liveDecision(await imageMetrics(req.file.buffer), req.body?.mode || "Normal");
    res.setHeader("X-Live-Engine", "mode-aware-meter-v4");
    res.setHeader("X-Processing-Ms", String(Date.now() - started));
    return res.json(result);
  } catch (e) {
    console.error("Live analyze error", e);
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
      input: [{
        role: "user",
        content: [
          { type: "input_text", text: "Bu fotoğrafı profesyonel fotoğrafçı gibi analiz et. SADECE JSON: {\"score\":0,\"composition\":0,\"lighting\":0,\"perspective\":0,\"sharpness\":0,\"summary\":\"\",\"suggestions\":[]}. Türkçe, kısa ve fotoğrafa özel." },
          { type: "input_image", image_url: `data:${mime};base64,${image}`, detail: "low" },
        ],
      }],
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
    const allowed = new Set(["auto_enhance", "fix_light", "remove_people", "remove_object", "custom_prompt"]);
    if (!allowed.has(action)) return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });

    const x = req.body?.point_x != null ? clamp(req.body.point_x, 0, 1) : null;
    const y = req.body?.point_y != null ? clamp(req.body.point_y, 0, 1) : null;
    const prompt = String(req.body?.prompt || "").trim();
    const mode = String(req.body?.mode || "Fotoğraf");
    if (action === "remove_object" && (x == null || y == null)) {
      return res.status(400).json({ error: "Nesne konumu seçilmedi." });
    }
    if (action === "custom_prompt" && !prompt) {
      return res.status(400).json({ error: "Düzenleme tarifini yazmalısın." });
    }

    let output;
    let engine = `gpt-image-2-${action}`;
    let usedLegacyFallback = false;
    try {
      output = await aiImageEdit(req.file.buffer, detectMimeType(req.file), action, {
        pointX: x,
        pointY: y,
        userPrompt: prompt,
      });
    } catch (primaryError) {
      // The previous deterministic editor remains available for the two
      // operations it can perform safely. Generative removal/prompt failures
      // stay visible instead of pretending that an unchanged image succeeded.
      if (action !== "auto_enhance" && action !== "fix_light") {
        throw primaryError;
      }
      console.error("Primary image API failed; using legacy develop", primaryError);
      output = await legacyDevelopPhoto(req.file.buffer, mode, action);
      engine = `legacy-sharp-${action}`;
      usedLegacyFallback = true;
    }
    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("X-Develop-Engine", engine);
    res.setHeader("X-AI-Fallback", usedLegacyFallback ? "legacy" : "none");
    res.setHeader("X-Processing-Ms", String(Date.now() - started));
    res.setHeader("Cache-Control", "no-store");
    return res.status(200).send(output);
  } catch (e) {
    console.error("Edit photo error", e);
    return res.status(500).json({
      error: "Fotoğraf düzenleme başarısız.",
      detail: String(e?.message || e),
    });
  }
});

app.listen(port, "0.0.0.0", () =>
  console.log(`AI photo backend ${port} portunda çalışıyor.`),
);
