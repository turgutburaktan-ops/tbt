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
    let imagePath = null;

    try {
      if (!req.file) {
        return res.status(400).json({
          error: "Fotoğraf gönderilmedi.",
        });
      }

      imagePath = req.file.path;

      const imageBuffer = fs.readFileSync(imagePath);
      const base64Image = imageBuffer.toString("base64");
      let mimeType = req.file.mimetype;

if (
  !mimeType ||
  mimeType === "application/octet-stream"
) {
  const fileName = req.file.originalname.toLowerCase();

  if (
    fileName.endsWith(".jpg") ||
    fileName.endsWith(".jpeg")
  ) {
    mimeType = "image/jpeg";
  } else if (fileName.endsWith(".png")) {
    mimeType = "image/png";
  } else if (fileName.endsWith(".webp")) {
    mimeType = "image/webp";
  } else {
    mimeType = "image/jpeg";
  }
}
      const response = await openai.responses.create({
        model: "gpt-5-mini",
        input: [
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text:
                  "Bu fotoğrafı profesyonel bir fotoğraf eğitmeni gibi analiz et. " +
                  "Kompozisyon, ışık, perspektif, netlik, konu yerleşimi, ufuk, " +
                  "dikkat dağıtan unsurlar ve çekim açısını değerlendir. " +
                  "Her fotoğrafa özel, uygulanabilir öneriler ver. " +
                  "Yanıt dili Türkçe olsun. " +
                  "SADECE geçerli JSON döndür. JSON biçimi: " +
                  '{"score":0,"composition":0,"lighting":0,"perspective":0,' +
                  '"sharpness":0,"summary":"","suggestions":["","",""]}. ' +
                  "score 0-100, diğer puanlar 0-10 arası tam sayı olsun. " +
                  "suggestions 3 ile 5 öneri içersin.",
              },
              {
                type: "input_image",
                image_url:
                  "data:" +
                  mimeType +
                  ";base64," +
                  base64Image,
              },
            ],
          },
        ],
      });

      const raw = response.output_text;

const cleaned = String(raw)
  .replaceAll("json", "")
  .replaceAll("", "")
  .trim();

      const parsedResult = JSON.parse(cleaned);
      
      return res.json(parsedresult);
    } catch (error) {
      console.error("Analyze error:", error);

      return res.status(500).json({
        error: "Fotoğraf analizi başarısız.",
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
    "AI backend " + port + " portunda çalışıyor."
  );
});
