class PhotoSpot {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final double rating;
  final String bestTime;
  final String angle;
  final String imageUrl;

  final String category;
  final String description;
  final String recommendedLens;
  final String difficulty;
  final List<String> tags;

  const PhotoSpot({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.bestTime,
    required this.angle,
    required this.imageUrl,

    this.category = 'Genel',
    this.description = '',
    this.recommendedLens = '24-70mm',
    this.difficulty = 'Kolay',
    this.tags = const [],
  });
}

const demoSpots = <PhotoSpot>[
  PhotoSpot(
    id: 'galata',
    name: 'Galata Kulesi',
    city: 'İstanbul',
    latitude: 41.0256,
    longitude: 28.9744,
    rating: 4.8,
    bestTime: '17:45 - 19:10',
    angle: 'Karşı sokaktan, hafif alçak açı',
    imageUrl:
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',
    category: 'Mimari',
    description:
        'Kuleyi çevredeki tarihi sokaklarla birlikte kadraja almak için güçlü bir şehir fotoğrafı noktası.',
    recommendedLens: '24-50mm',
    difficulty: 'Kolay',
    tags: [
      'İstanbul',
      'Mimari',
      'Gün Batımı',
      'Sokak',
      'Kule',
    ],
  ),

  PhotoSpot(
    id: 'sultanahmet',
    name: 'Sultanahmet Camii',
    city: 'İstanbul',
    latitude: 41.0054,
    longitude: 28.9768,
    rating: 4.7,
    bestTime: '18:00 - 19:20',
    angle: 'Avlu tarafından geniş açı',
    imageUrl:
        'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?w=900',
    category: 'Mimari',
    description:
        'Simetrik mimari ve minare kompozisyonları için İstanbul’un güçlü çekim noktalarından biri.',
    recommendedLens: '16-35mm',
    difficulty: 'Kolay',
    tags: [
      'İstanbul',
      'Camii',
      'Mimari',
      'Gün Batımı',
      'Tarih',
    ],
  ),

  PhotoSpot(
    id: 'ortakoy',
    name: 'Ortaköy Camii ve Boğaz Köprüsü',
    city: 'İstanbul',
    latitude: 41.0472,
    longitude: 29.0275,
    rating: 4.9,
    bestTime: '06:00 - 07:30',
    angle: 'Sahil tarafından camii ve köprüyü aynı kadraja al',
    imageUrl:
        'https://images.unsplash.com/photo-1527838832700-5059252407fa?w=900',
    category: 'Şehir',
    description:
        'Camii, Boğaz ve köprü üçlüsünü aynı kompozisyonda kullanabileceğin ikonik İstanbul noktası.',
    recommendedLens: '24-70mm',
    difficulty: 'Kolay',
    tags: [
      'İstanbul',
      'Boğaz',
      'Gün Doğumu',
      'Mimari',
    ],
  ),

  PhotoSpot(
    id: 'kapadokya',
    name: 'Göreme Gün Doğumu',
    city: 'Nevşehir',
    latitude: 38.6431,
    longitude: 34.8289,
    rating: 5.0,
    bestTime: '05:30 - 07:00',
    angle: 'Yüksek noktadan vadilere doğru geniş açı',
    imageUrl:
        'https://images.unsplash.com/photo-1528181304800-259b08848526?w=900',
    category: 'Doğa',
    description:
        'Balonların yükseldiği saatlerde geniş manzara ve katmanlı kompozisyonlar için ideal.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: [
      'Kapadokya',
      'Nevşehir',
      'Balon',
      'Gün Doğumu',
      'Doğa',
    ],
  ),

  PhotoSpot(
    id: 'izmir-saat',
    name: 'İzmir Saat Kulesi',
    city: 'İzmir',
    latitude: 38.4189,
    longitude: 27.1287,
    rating: 4.7,
    bestTime: '18:30 - 20:00',
    angle: 'Konak Meydanı tarafından hafif çapraz açı',
    imageUrl:
        'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=900',
    category: 'Mimari',
    description:
        'Meydan hareketliliğiyle birlikte klasik şehir fotoğrafı için uygun.',
    recommendedLens: '24-50mm',
    difficulty: 'Kolay',
    tags: [
      'İzmir',
      'Konak',
      'Saat Kulesi',
      'Gün Batımı',
    ],
  ),

  PhotoSpot(
    id: 'izmir-kordon',
    name: 'Kordon',
    city: 'İzmir',
    latitude: 38.4320,
    longitude: 27.1368,
    rating: 4.8,
    bestTime: '18:30 - 20:15',
    angle: 'Denizi çaprazdan al, güneşi kadraj kenarında tut',
    imageUrl:
        'https://images.unsplash.com/photo-1544986581-efac024faf62?w=900',
    category: 'Gün Batımı',
    description:
        'Deniz, yürüyüş yolu ve gün batımı kombinasyonu için güçlü bir sahil noktası.',
    recommendedLens: '24-70mm',
    difficulty: 'Kolay',
    tags: [
      'İzmir',
      'Kordon',
      'Deniz',
      'Gün Batımı',
    ],
  ),

  PhotoSpot(
    id: 'efes',
    name: 'Efes Antik Kenti',
    city: 'İzmir',
    latitude: 37.9390,
    longitude: 27.3410,
    rating: 4.9,
    bestTime: '07:00 - 09:00',
    angle: 'Celsus Kütüphanesi önünden simetrik kadraj',
    imageUrl:
        'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',
    category: 'Tarih',
    description:
        'Antik mimari, taş dokuları ve güçlü perspektif çizgileri için ideal.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: [
      'İzmir',
      'Selçuk',
      'Efes',
      'Tarih',
      'Mimari',
    ],
  ),

  PhotoSpot(
    id: 'pamukkale',
    name: 'Pamukkale Travertenleri',
    city: 'Denizli',
    latitude: 37.9137,
    longitude: 29.1187,
    rating: 4.9,
    bestTime: '17:30 - 19:00',
    angle: 'Traverten çizgilerini ön plan olarak kullan',
    imageUrl:
        'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',
    category: 'Doğa',
    description:
        'Beyaz traverten yüzeyleri ve sıcak gün batımı ışığı güçlü kontrast oluşturur.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: [
      'Denizli',
      'Pamukkale',
      'Doğa',
      'Gün Batımı',
    ],
  ),

  PhotoSpot(
    id: 'antalya-kaleici',
    name: 'Kaleiçi',
    city: 'Antalya',
    latitude: 36.8841,
    longitude: 30.7056,
    rating: 4.8,
    bestTime: '17:45 - 19:30',
    angle: 'Dar sokaklarda perspektif çizgilerini kullan',
    imageUrl:
        'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',
    category: 'Sokak',
    description:
        'Tarihi sokaklar, taş yapılar ve Akdeniz ışığı ile sokak fotoğrafçılığı için uygun.',
    recommendedLens: '24-35mm',
    difficulty: 'Kolay',
    tags: [
      'Antalya',
      'Kaleiçi',
      'Sokak',
      'Tarih',
    ],
  ),

  PhotoSpot(
    id: 'antalya-duden',
    name: 'Düden Şelalesi',
    city: 'Antalya',
    latitude: 36.8510,
    longitude: 30.7837,
    rating: 4.7,
    bestTime: '08:00 - 10:00',
    angle: 'Şelaleyi çaprazdan ve ön planla birlikte çek',
    imageUrl:
        'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=900',
    category: 'Doğa',
    description:
        'Su hareketini, kayalıkları ve çevredeki yeşilliği aynı karede kullanmak için ideal.',
    recommendedLens: '16-35mm',
    difficulty: 'Orta',
    tags: [
      'Antalya',
      'Şelale',
      'Doğa',
      'Uzun Pozlama',
    ],
  ),

  PhotoSpot(
    id: 'nemrut',
    name: 'Nemrut Dağı',
    city: 'Adıyaman',
    latitude: 37.9800,
    longitude: 38.7408,
    rating: 4.9,
    bestTime: '05:15 - 06:45',
    angle: 'Heykelleri ön plana, güneşi arka plana al',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',
    category: 'Manzara',
    description:
        'Gün doğumunda heykeller ve dağ siluetleri çok güçlü bir atmosfer oluşturur.',
    recommendedLens: '24-70mm',
    difficulty: 'Zor',
    tags: [
      'Adıyaman',
      'Nemrut',
      'Gün Doğumu',
      'Manzara',
    ],
  ),

  PhotoSpot(
    id: 'uzungol',
    name: 'Uzungöl',
    city: 'Trabzon',
    latitude: 40.6193,
    longitude: 40.2923,
    rating: 4.8,
    bestTime: '06:30 - 08:30',
    angle: 'Yüksek seyir noktasından gölü merkeze almadan çek',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=900',
    category: 'Doğa',
    description:
        'Göl, dağ ve sis katmanlarını kullanarak derinlik oluşturabileceğin güçlü bir manzara noktası.',
    recommendedLens: '24-70mm',
    difficulty: 'Orta',
    tags: [
      'Trabzon',
      'Uzungöl',
      'Doğa',
      'Manzara',
    ],
  ),
];
