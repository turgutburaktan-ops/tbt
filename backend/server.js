import express from "express";
import cors from "cors";
import multer from "multer";
import OpenAI from "openai";

const app = express();
const port = process.env.PORT || 10000;

app.use(cors());
app.use(express.json({ limit: "2mb" }));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 12 * 1024 * 1024,
  },
});

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

function detectMimeType(file) {
  let mimeType = file?.mimetype || "";

  if (
    !mimeType ||
    mimeType === "application/octet-stream"
  ) {
    const fileName = String(
      file?.originalname || ""
    ).toLowerCase();

    if (fileName.endsWith(".png")) {
      mimeType = "image/png";
    } else if (fileName.endsWith(".webp")) {
      mimeType = "image/webp";
    } else {
      mimeType = "image/jpeg";
    }
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

// =====================================================
// TEST
// =====================================================

app.get("/", (req, res) => {
  res.json({
    status: "ok",
    service: "En Iyi Cekim Noktasi AI Backend",
  });
});

// =====================================================
// DETAYLI FOTOĞRAF ANALİZİ
// =====================================================

app.post(
  "/analyze",
  upload.single("image"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: "Fotoğraf gönderilmedi.",
        });
      }

      if (!process.env.OPENAI_API_KEY) {
        return res.status(500).json({
          error: "OPENAI_API_KEY tanımlı değil.",
        });
      }

      const mimeType = detectMimeType(
        req.file
      );

      const base64Image =
        req.file.buffer.toString(
          "base64"
        );

      const response =
        await openai.responses.create({
          model: "gpt-5-mini",

          input: [
            {
              role: "user",

              content: [
                {
                  type: "input_text",

                  text: `
Bu fotoğrafı profesyonel bir fotoğrafçı gibi analiz et.

SADECE geçerli JSON döndür.
Markdown kullanma.

Şu JSON formatını kullan:

{
  "score": 0,
  "composition": 0,
  "lighting": 0,
  "perspective": 0,
  "sharpness": 0,
  "summary": "",
  "suggestions": []
}

Kurallar:

- score 0-100 arasında tam sayı olsun.
- composition 0-10 arasında olsun.
- lighting 0-10 arasında olsun.
- perspective 0-10 arasında olsun.
- sharpness 0-10 arasında olsun.

- summary Türkçe olsun.
- summary bu fotoğrafa özel olsun.
- Fotoğrafta gerçekten gördüğün şeyleri değerlendir.

- suggestions alanında 3-5 öneri ver.
- Öneriler kısa ve uygulanabilir olsun.
- Her fotoğrafa aynı önerileri verme.

Örnek öneriler:

"Konuyu biraz sağ üçte bire taşı."
"Telefonu biraz aşağı indir."
"Arka plandaki parlak alanı kadrajdan çıkar."
"Telefonu sabit tut."
"Güneşi doğrudan kadraja alma."

Görmediğin şeyleri uydurma.
                  `.trim(),
                },

                {
                  type: "input_image",

                  image_url:
                    `data:${mimeType};base64,${base64Image}`,

                  detail: "auto",
                },
              ],
            },
          ],
        });

      const parsedResult =
        parseModelJson(
          response.output_text
        );

      return res.json(
        parsedResult
      );
    } catch (error) {
      console.error(
        "Analyze error:",
        error
      );

      return res.status(500).json({
        error:
          "Fotoğraf analizi başarısız.",
      });
    }
  }
);

// =====================================================
// CANLI AI KADRAJ ANALİZİ
// =====================================================

app.post(
  "/live-analyze",
  upload.single("image"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: "Kamera karesi gönderilmedi.",
        });
      }

      const mimeType = detectMimeType(req.file);
      const base64Image =
        req.file.buffer.toString("base64");

      const mode = String(
        req.body?.mode || "Normal"
      );

      const response =
        await openai.responses.create({
          model: "gpt-5-mini",

          input: [
            {
              role: "user",

              content: [
                {
                  type: "input_text",

                  text: `
Sen gerçek zamanlı fotoğraf çekim asistanısın.

Seçili çekim modu:
${mode}

Kullanıcı deklanşöre basmadan hemen önce kısa yönlendirme ver.

SADECE geçerli JSON döndür.

{
  "status": "adjust",
  "main_tip": "",
  "composition_tip": "",
  "light_tip": ""
}

Kurallar:

- status sadece:
  "good"
  "adjust"
  "warning"

- Tüm öneriler Türkçe olsun.

- Her öneri EN FAZLA 6-8 kelime olsun.

- Uzun açıklama yazma.

- Aynı şeyi iki kez söyleme.

- Görmediğin şeyi uydurma.

- En önemli öneriyi main_tip alanına yaz.

- İkinci önemli öneriyi composition_tip alanına yaz.

- Gerekirse üçüncü öneriyi light_tip alanına yaz.

- Görüntü zaten iyiyse:

status = "good"
main_tip = "Kadraj hazır — çekebilirsin."
composition_tip = ""
light_tip = ""

Örnek:

{
  "status": "adjust",
  "main_tip": "Telefonu biraz yukarı kaldır.",
  "composition_tip": "Konuyu sağ üçte bire taşı.",
  "light_tip": "Ekran parlaklığını biraz azalt."
}

Gereksiz ayrıntı verme.
                  `.trim(),
                },

                {
                  type: "input_image",

                  image_url:
                    `data:${mimeType};base64,${base64Image}`,

                  detail: "low",
                },
              ],
            },
          ],
        });

      const parsedResult =
        parseModelJson(
          response.output_text
        );

      return res.json({
        status: String(
          parsedResult.status ||
            "adjust"
        ),

        main_tip: String(
          parsedResult.main_tip || ""
        ),

        composition_tip: String(
          parsedResult.composition_tip ||
            ""
        ),

        light_tip: String(
          parsedResult.light_tip || ""
        ),

        subject_tip: "",
      });
    } catch (error) {
      console.error(
        "Live analyze error:",
        error
      );

      return res.status(500).json({
        error:
          "Canlı kadraj analizi başarısız.",
      });
    }
  }
);
const PORT = Number(process.env.PORT) || 10000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`AI backend ${PORT} portunda çalışıyor.`);
});
