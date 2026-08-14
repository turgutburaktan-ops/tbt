import '../models/photo_spot.dart';

/// Kültür ve Turizm Bakanlığı / GoTürkiye rota ve fotoğraf noktası içeriklerinden
/// seçilmiş, uygulamanın fotoğrafçılık katmanıyla zenginleştirilmiş çekim noktaları.
/// Kaynak bilgisi kullanıcı arayüzünde etiket olarak gösterilmez.
const curatedPhotoSpotsOfficialRoutes = <PhotoSpot>[
  PhotoSpot(
    id: 'aksaray-ihlara-vadisi',
    name: 'Ihlara Vadisi',
    city: 'Aksaray',
    latitude: 38.2575,
    longitude: 34.295278,
    rating: 4.9,
    bestTime: '07:00 - 10:00',
    angle:
        'Vadi tabanında Melendiz Çayı’nı yönlendirici çizgi olarak kullan; yüksek seyirlerde kıvrımı kadraja al',
    imageUrl: '',
    category: 'Doğa',
    description:
        'Kanyon duvarları, kaya oyma yapılar ve Melendiz Çayı ile geniş açı ve katmanlı doğa fotoğrafları için güçlü bir rota.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: ['Aksaray', 'Ihlara', 'Kanyon', 'Doğa', 'Tarih', 'Gün Doğumu'],
  ),
  PhotoSpot(
    id: 'aksaray-selime-katedrali',
    name: 'Selime Katedrali ve Peribacaları',
    city: 'Aksaray',
    latitude: 38.3012,
    longitude: 34.25943,
    rating: 4.9,
    bestTime: '07:00 - 09:30',
    angle:
        'Kaya oyma yapıları önde, vadiyi arkada bırakacak çapraz geniş açı kullan',
    imageUrl: '',
    category: 'Tarih',
    description:
        'Kaya oyma mimarisi ve Kapadokya benzeri jeolojik formasyonları aynı kadrajda birleştirebileceğin dramatik bir nokta.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: ['Aksaray', 'Selime', 'Tarih', 'Peribacaları', 'Kaya', 'Gün Doğumu'],
  ),
  PhotoSpot(
    id: 'aksaray-sultanhani',
    name: 'Sultanhanı Kervansarayı',
    city: 'Aksaray',
    latitude: 38.25,
    longitude: 33.55,
    rating: 4.8,
    bestTime: '08:00 - 10:30',
    angle:
        'Anıtsal taç kapıyı merkezleyip simetriyi koru; avluda gölge-ışık çizgilerini kullan',
    imageUrl: '',
    category: 'Mimari',
    description:
        'Selçuklu taş işçiliği, güçlü simetri ve büyük ölçekli mimari detaylar için öne çıkan tarihî çekim noktası.',
    recommendedLens: '16-35mm',
    tags: ['Aksaray', 'Sultanhanı', 'Mimari', 'Selçuklu', 'Tarih', 'Simetri'],
  ),
  PhotoSpot(
    id: 'isparta-akpinar-seyir',
    name: 'Akpınar Köyü Seyir Terası',
    city: 'Isparta',
    latitude: 37.845033,
    longitude: 30.851267,
    rating: 4.9,
    bestTime: '17:00 - 19:30',
    angle:
        'Eğirdir Gölü’nü geniş panorama olarak al; kıyı çizgisini diyagonal kullan',
    imageUrl: '',
    category: 'Manzara',
    description:
        'Eğirdir Gölü’nün büyük bölümünü yüksekten gören, gün batımı ve geniş panorama çekimleri için çok güçlü bir seyir noktası.',
    recommendedLens: '16-35mm',
    difficulty: 'Kolay',
    tags: ['Isparta', 'Eğirdir', 'Akpınar', 'Manzara', 'Göl', 'Gün Batımı'],
  ),
  PhotoSpot(
    id: 'isparta-kovada-golu',
    name: 'Kovada Gölü Milli Parkı',
    city: 'Isparta',
    latitude: 37.63394,
    longitude: 30.88353,
    rating: 4.8,
    bestTime: '06:30 - 09:00',
    angle: 'Kıyıdaki ağaçları doğal çerçeve yapıp göl yansımasını koru',
    imageUrl: '',
    category: 'Doğa',
    description:
        'Sakin göl yüzeyi, orman dokusu ve sabah yansımalarıyla doğa ve kuş fotoğrafçılığı için uygun.',
    recommendedLens: '24-70mm',
    difficulty: 'Kolay',
    tags: ['Isparta', 'Kovada', 'Göl', 'Doğa', 'Yansıma', 'Kuş'],
  ),
  PhotoSpot(
    id: 'elazig-harput-kalesi',
    name: 'Harput Kalesi',
    city: 'Elazığ',
    latitude: 38.703389,
    longitude: 39.257389,
    rating: 4.9,
    bestTime: '16:30 - 19:00',
    angle: 'Kale duvarlarını ön plan yapıp Elazığ ovasını arkada katmanla',
    imageUrl: '',
    category: 'Tarih',
    description:
        'Harput’un tarihî dokusu ile geniş Elazığ manzarasını aynı karede birleştirebileceğin yüksek konumlu çekim noktası.',
    recommendedLens: '24-70mm',
    difficulty: 'Orta',
    tags: ['Elazığ', 'Harput', 'Kale', 'Tarih', 'Manzara', 'Gün Batımı'],
  ),
  PhotoSpot(
    id: 'istanbul-pierre-loti',
    name: 'Pierre Loti Tepesi',
    city: 'İstanbul',
    latitude: 41.054167,
    longitude: 28.935833,
    rating: 4.8,
    bestTime: '17:00 - 19:30',
    angle:
        'Haliç kıvrımını tele lensle sıkıştır; minare ve şehir katmanlarını üst üste getir',
    imageUrl: '',
    category: 'Manzara',
    description:
        'Haliç, tarihî yarımada ve şehir katmanlarını yüksek açıdan fotoğraflamak için klasik İstanbul noktalarından biri.',
    recommendedLens: '70-200mm',
    tags: ['İstanbul', 'Haliç', 'Pierre Loti', 'Manzara', 'Gün Batımı'],
  ),
  PhotoSpot(
    id: 'istanbul-ataturk-arboretumu',
    name: 'Atatürk Arboretumu',
    city: 'İstanbul',
    latitude: 41.175,
    longitude: 28.989722,
    rating: 4.8,
    bestTime: '08:00 - 11:00',
    angle:
        'Göl yansımasını ve ağaç tünellerini simetrik ya da merkez dışı kompozisyonla kullan',
    imageUrl: '',
    category: 'Doğa',
    description:
        'Mevsim renkleri, gölet yansımaları ve yoğun ağaç dokusuyla özellikle sonbahar ve portre çekimleri için güçlü.',
    recommendedLens: '35-85mm',
    difficulty: 'Kolay',
    tags: [
      'İstanbul',
      'Sarıyer',
      'Arboretum',
      'Doğa',
      'Sonbahar',
      'Portre',
      'Yansıma'
    ],
  ),
  PhotoSpot(
    id: 'istanbul-rumeli-hisari',
    name: 'Rumeli Hisarı',
    city: 'İstanbul',
    latitude: 41.1,
    longitude: 29.1333,
    rating: 4.9,
    bestTime: '06:30 - 09:00',
    angle:
        'Hisarı Boğaz ve Fatih Sultan Mehmet Köprüsü ile aynı eksende katmanla',
    imageUrl: '',
    category: 'Mimari',
    description:
        'Hisar duvarları, Boğaz ve köprü katmanlarını bir araya getirerek güçlü tarih-şehir kompozisyonları sunar.',
    recommendedLens: '24-70mm',
    difficulty: 'Kolay',
    tags: [
      'İstanbul',
      'Boğaz',
      'Rumeli Hisarı',
      'Mimari',
      'Tarih',
      'Gün Doğumu'
    ],
  ),
];
