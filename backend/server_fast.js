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
  const blown =
    metrics.mean > 190 ||
    (metrics.mean > 145 && metrics.highlightRatio > 0.1) ||
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
    main = m.includes("spor")
      ? "Işık az — hareketi donduracak hızı koru."
      : "Düşük ışık — pozlamayı dengeliyorum.";
    light = "Gölgelerde detay koru.";
  } else if (dark) {
    status = "adjust";
    main = "Işık düşük — modu dengeliyorum.";
    light = "Gürültüyü sınırlı tut.";
  } else if (blown) {
    status = "adjust";
    main = "Parlak alanları koru.";
    light = "Pozlamayı hafif azalt.";
  } else if (flat) {
    status = "adjust";
    main = "Kontrast düşük — tonu güçlendir.";
    light = "Orta tonları ayır.";
  }

  if (m.includes("portre")) subject = "Yüz ve göz netliği öncelikli.";
  if (m.includes("manzara")) subject = "Ufuk ve geniş alan detayı öncelikli.";
  if (m.includes("spor")) subject = "Hareket takibi ve hızlı çekim öncelikli.";
  if (m.includes("gece")) subject = "Işıkları patlatmadan koru.";
  if (m.includes("makro")) subject = "Yakın konu netliği öncelikli.";

  return {
    status,
    main_tip: main,
    composition_tip: "",
    light_tip: light,
    subject_tip: subject,
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

async function aiImageEdit(buffer, mimeType, action, { pointX, pointY, userPrompt } = {}) {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY tanımlı değil.");
  }

  const form = new FormData();
  form.append("model", "gpt-image-2");
  form.append("prompt", editPrompt(action, userPrompt, pointX, pointY));
  form.append("image", new Blob([buffer], { type: mimeType }), "input.jpg");
  form.append("size", "auto");
  form.append("quality", "medium");
  form.append("output_format", "jpeg");

  const response = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    body: form,
  });

  if (!response.ok) {
    throw new Error(`Image edit ${response.status}: ${await response.text()}`);
  }

  const json = await response.json();
  const b64 = json?.data?.[0]?.b64_json;
  if (!b64) throw new Error("AI düzenleme görsel döndürmedi.");
  return Buffer.from(b64, "base64");
}

app.get("/", (_req, res) =>
  res.json({
    status: "ok",
    service: "En Iyi Cekim Noktasi AI Backend",
    liveEngine: "fast-meter-v3",
    developEngine: "gpt-image-2-all-edits",
  }),
);

app.post("/live-analyze", upload.single("image"), async (req, res) => {
  const started = Date.now();
  try {
    if (!req.file) {
      return res.status(400).json({ error: "Kamera karesi gönderilmedi." });
    }
    const result = liveDecision(
      await imageMetrics(req.file.buffer),
      req.body?.mode || "Normal",
    );
    res.setHeader("X-Live-Engine", "fast-meter-v3");
    res.setHeader("X-Processing-Ms", String(Date.now() - started));
    return res.json(result);
  } catch (e) {
    console.error("Fast live analyze error", e);
    return res.status(500).json({ error: "Canlı sahne analizi başarısız." });
  }
});

app.post("/analyze", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "Fotoğraf gönderilmedi." });
    }
    if (!process.env.OPENAI_API_KEY) {
      return res.status(503).json({ error: "AI anahtarı tanımlı değil." });
    }

    const mime = detectMimeType(req.file);
    const image = req.file.buffer.toString("base64");
    const response = await openai.responses.create({
      model: "gpt-5-mini",
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: "Bu fotoğrafı profesyonel fotoğrafçı gibi analiz et. SADECE JSON: {\"score\":0,\"composition\":0,\"lighting\":0,\"perspective\":0,\"sharpness\":0,\"summary\":\"\",\"suggestions\":[]}. Türkçe, kısa ve fotoğrafa özel.",
            },
            {
              type: "input_image",
              image_url: `data:${mime};base64,${image}`,
              detail: "low",
            },
          ],
        },
      ],
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
    if (!req.file) {
      return res.status(400).json({ error: "Düzenlenecek fotoğraf gönderilmedi." });
    }

    const action = String(req.body?.action || "auto_enhance");
    const allowed = new Set([
      "auto_enhance",
      "fix_light",
      "remove_people",
      "remove_object",
      "custom_prompt",
    ]);

    if (!allowed.has(action)) {
      return res.status(400).json({ error: "Geçersiz düzenleme işlemi." });
    }

    const x = req.body?.point_x != null ? clamp(req.body.point_x, 0, 1) : null;
    const y = req.body?.point_y != null ? clamp(req.body.point_y, 0, 1) : null;
    const prompt = String(req.body?.prompt || "").trim();

    if (action === "remove_object" && (x == null || y == null)) {
      return res.status(400).json({ error: "Nesne konumu seçilmedi." });
    }
    if (action === "custom_prompt" && !prompt) {
      return res.status(400).json({ error: "Düzenleme tarifini yazmalısın." });
    }

    const output = await aiImageEdit(
      req.file.buffer,
      detectMimeType(req.file),
      action,
      { pointX: x, pointY: y, userPrompt: prompt },
    );

    res.setHeader("Content-Type", "image/jpeg");
    res.setHeader("X-Develop-Engine", `gpt-image-2-${action}`);
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
