import express from "express";
import multer from "multer";
import OpenAI from "openai";
import fs from "fs";

const app = express();
const upload = multer({
  dest: "uploads/",
  limits: {
    fileSize: 12 * 1024 * 1024,
  },
});

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.get("/", (req, res) => {
  res.json({
    status: "ok",
    service: "En Iyi Cekim Noktasi AI Backend",
  });
});

app.post(
  "/analyze",
  upload.single("image"),
  async (req, res) => {
    let imagePath;

    try {
      if (!req.file) {
        return res.status(400).json({
          error: "Fotoğraf gönderilmedi.",
        });
      }

      imagePath = req.file.path;

      const imageBuffer = fs.readFileSync(imagePath);
      const base64Image = imageBuffer.toString("base64");

      const mimeType =
        req.file.mimetype || "image/jpeg";

      const response = await openai.responses.create({
        model: "gpt-5-mini",
        input: [
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: `
Bu fotoğrafı profesyonel bir fotoğraf eğitmeni gibi analiz et.

Amacın kullanıcının bir sonraki çekimini belirgin şekilde iyileştirmek.

Şunları değerlendir:
- kompozisyon
- ışık
- perspektif
- netlik
- konu yerleşimi
- ufuk
- dikkat dağıtan unsurlar
- çekim açısı

Her fotoğrafı kendi görüntüsüne göre değerlendir.
Genel ve sürekli aynı önerileri verme.

Öneriler mümkün olduğunca uygulanabilir olsun.
Örneğin:
- "Kamerayı yaklaşık 5 derece sola çevir."
- "Ana konuyu sağ üçte birlik kesişime taşı."
- "Bir adım geri git."
- "Gökyüzünün kadrajdaki oranını azalt."

SADECE aşağıdaki yapıda geçerli JSON döndür:

{
  "score": 0,
  "composition": 0,
  "lighting": 0,
  "perspective": 0,
  "sharpness": 0,
  "summary": "",
  "suggestions": [
    "",
    "",
    ""
  ]
}

score 0-100 arası tam sayı olmalı.
Diğer puanlar 0-10 arası tam sayı olmalı.
suggestions 3 ile 5 öneri içermeli.
Yanıt dili Türkçe olmalı.
`,
              },
              {
                type: "input_image",
                image_url:
                  data:${mimeType};base64,${base64Image}',
              },
            ],
          },
        ],
      });

      const raw = response.output_text;

      const cleaned = raw
        .replace(/json/g, "")
        .replace(//g, "")
        .trim();

      const result = JSON.parse(cleaned);

      res.json(result);
    } catch (error) {
      console.error(error);

      res.status(500).json({
        error: "Fotoğraf analizi başarısız.",
        details:
          process.env.NODE_ENV === "development"
            ? error.message
            : undefined,
      });
    } finally {
      if (imagePath && fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
      }
    }
  }
);

const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(
    AI backend ${port} portunda çalışıyor.
  );
});
