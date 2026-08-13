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
  PhotoSpot(id:'galata',name:'Galata Kulesi',city:'İstanbul',latitude:41.0256,longitude:28.9744,rating:4.8,bestTime:'17:45 - 19:10',angle:'Karşı sokaktan, hafif alçak açı',imageUrl:'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',category:'Mimari',description:'Kuleyi çevredeki tarihi sokaklarla birlikte kadraja almak için güçlü bir şehir fotoğrafı noktası.',recommendedLens:'24-50mm',tags:['İstanbul','Mimari','Gün Batımı','Sokak','Kule']),
  PhotoSpot(id:'sultanahmet',name:'Sultanahmet Camii',city:'İstanbul',latitude:41.0054,longitude:28.9768,rating:4.7,bestTime:'18:00 - 19:20',angle:'Avlu tarafından geniş açı',imageUrl:'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?w=900',category:'Mimari',description:'Simetrik mimari ve minare kompozisyonları için güçlü bir İstanbul noktası.',recommendedLens:'16-35mm',tags:['İstanbul','Camii','Mimari','Gün Batımı','Tarih']),
  PhotoSpot(id:'ortakoy',name:'Ortaköy Camii ve Boğaz Köprüsü',city:'İstanbul',latitude:41.0472,longitude:29.0275,rating:4.9,bestTime:'06:00 - 07:30',angle:'Sahil tarafından camii ve köprüyü aynı kadraja al',imageUrl:'https://images.unsplash.com/photo-1527838832700-5059252407fa?w=900',category:'Şehir',description:'Camii, Boğaz ve köprü üçlüsünü aynı kompozisyonda kullanabileceğin ikonik İstanbul noktası.',recommendedLens:'24-70mm',tags:['İstanbul','Boğaz','Gün Doğumu','Mimari']),
  PhotoSpot(id:'kapadokya',name:'Göreme Gün Doğumu',city:'Nevşehir',latitude:38.6431,longitude:34.8289,rating:5.0,bestTime:'05:30 - 07:00',angle:'Yüksek noktadan vadilere doğru geniş açı',imageUrl:'https://images.unsplash.com/photo-1528181304800-259b08848526?w=900',category:'Doğa',description:'Balonların yükseldiği saatlerde geniş manzara ve katmanlı kompozisyonlar için ideal.',recommendedLens:'16-35mm',difficulty:'Orta',tags:['Kapadokya','Nevşehir','Balon','Gün Doğumu','Doğa']),
  PhotoSpot(id:'izmir-saat',name:'İzmir Saat Kulesi',city:'İzmir',latitude:38.4189,longitude:27.1287,rating:4.7,bestTime:'18:30 - 20:00',angle:'Konak Meydanı tarafından hafif çapraz açı',imageUrl:'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=900',category:'Mimari',description:'Meydan hareketliliğiyle birlikte klasik şehir fotoğrafı için uygun.',recommendedLens:'24-50mm',tags:['İzmir','Konak','Saat Kulesi','Gün Batımı']),
  PhotoSpot(id:'izmir-kordon',name:'Kordon',city:'İzmir',latitude:38.4320,longitude:27.1368,rating:4.8,bestTime:'18:30 - 20:15',angle:'Denizi çaprazdan al, güneşi kadraj kenarında tut',imageUrl:'https://images.unsplash.com/photo-1544986581-efac024faf62?w=900',category:'Gün Batımı',description:'Deniz, yürüyüş yolu ve gün batımı kombinasyonu için güçlü bir sahil noktası.',recommendedLens:'24-70mm',tags:['İzmir','Kordon','Deniz','Gün Batımı']),
  PhotoSpot(id:'efes',name:'Efes Antik Kenti',city:'İzmir',latitude:37.9390,longitude:27.3410,rating:4.9,bestTime:'07:00 - 09:00',angle:'Celsus Kütüphanesi önünden simetrik kadraj',imageUrl:'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',category:'Tarih',description:'Antik mimari, taş dokuları ve güçlü perspektif çizgileri için ideal.',recommendedLens:'16-35mm',difficulty:'Orta',tags:['İzmir','Selçuk','Efes','Tarih','Mimari']),
  PhotoSpot(id:'pamukkale',name:'Pamukkale Travertenleri',city:'Denizli',latitude:37.9137,longitude:29.1187,rating:4.9,bestTime:'17:30 - 19:00',angle:'Traverten çizgilerini ön plan olarak kullan',imageUrl:'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',category:'Doğa',description:'Beyaz traverten yüzeyleri ve sıcak gün batımı ışığı güçlü kontrast oluşturur.',recommendedLens:'16-35mm',difficulty:'Orta',tags:['Denizli','Pamukkale','Doğa','Gün Batımı']),
  PhotoSpot(id:'antalya-kaleici',name:'Kaleiçi',city:'Antalya',latitude:36.8841,longitude:30.7056,rating:4.8,bestTime:'17:45 - 19:30',angle:'Dar sokaklarda perspektif çizgilerini kullan',imageUrl:'https://images.unsplash.com/photo-1602002418082-a4443e081dd1?w=900',category:'Sokak',description:'Tarihi sokaklar, taş yapılar ve Akdeniz ışığı ile sokak fotoğrafçılığı için uygun.',recommendedLens:'24-35mm',tags:['Antalya','Kaleiçi','Sokak','Tarih']),
  PhotoSpot(id:'antalya-duden',name:'Düden Şelalesi',city:'Antalya',latitude:36.8510,longitude:30.7837,rating:4.7,bestTime:'08:00 - 10:00',angle:'Şelaleyi çaprazdan ve ön planla birlikte çek',imageUrl:'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=900',category:'Doğa',description:'Su hareketini, kayalıkları ve çevredeki yeşilliği aynı karede kullanmak için ideal.',recommendedLens:'16-35mm',difficulty:'Orta',tags:['Antalya','Şelale','Doğa','Uzun Pozlama']),
  PhotoSpot(id:'nemrut',name:'Nemrut Dağı',city:'Adıyaman',latitude:37.9800,longitude:38.7408,rating:4.9,bestTime:'05:15 - 06:45',angle:'Heykelleri ön plana, güneşi arka plana al',imageUrl:'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',category:'Manzara',description:'Gün doğumunda heykeller ve dağ siluetleri çok güçlü bir atmosfer oluşturur.',recommendedLens:'24-70mm',difficulty:'Zor',tags:['Adıyaman','Nemrut','Gün Doğumu','Manzara']),
  PhotoSpot(id:'uzungol',name:'Uzungöl',city:'Trabzon',latitude:40.6193,longitude:40.2923,rating:4.8,bestTime:'06:30 - 08:30',angle:'Yüksek seyir noktasından gölü merkeze almadan çek',imageUrl:'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=900',category:'Doğa',description:'Göl, dağ ve sis katmanlarını kullanarak derinlik oluşturabileceğin güçlü bir manzara noktası.',recommendedLens:'24-70mm',difficulty:'Orta',tags:['Trabzon','Uzungöl','Doğa','Manzara']),

  PhotoSpot(id:'ayasofya',name:'Ayasofya Meydanı',city:'İstanbul',latitude:41.0086,longitude:28.9802,rating:4.9,bestTime:'06:30 - 08:00',angle:'Meydanın kuzeyinden simetrik geniş açı',imageUrl:'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',category:'Mimari',description:'Kubbe, minare ve meydan katmanlarını birlikte kullanmak için güçlü bir klasik.',recommendedLens:'16-35mm',tags:['İstanbul','Mimari','Gün Doğumu','Tarih']),
  PhotoSpot(id:'kiz-kulesi',name:'Kız Kulesi - Salacak',city:'İstanbul',latitude:41.0211,longitude:29.0041,rating:4.9,bestTime:'17:30 - 19:30',angle:'Salacak sahilinden tele lens ile sıkıştırılmış kadraj',imageUrl:'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',category:'Gün Batımı',description:'Kız Kulesi ve tarihi yarımadayı arka planda birleştiren ikonik sahil açısı.',recommendedLens:'70-200mm',tags:['İstanbul','Boğaz','Gün Batımı','Manzara']),
  PhotoSpot(id:'balat',name:'Balat Renkli Evler',city:'İstanbul',latitude:41.0313,longitude:28.9484,rating:4.7,bestTime:'08:00 - 10:30',angle:'Yokuşu perspektif çizgisi olarak kullan',imageUrl:'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=900',category:'Sokak',description:'Renk, doku ve yokuş perspektifiyle portre ve sokak fotoğrafı için uygun.',recommendedLens:'24-50mm',tags:['İstanbul','Balat','Sokak','Portre']),
  PhotoSpot(id:'anitkabir',name:'Anıtkabir',city:'Ankara',latitude:39.9251,longitude:32.8369,rating:4.9,bestTime:'09:00 - 11:00',angle:'Aslanlı Yol ekseninde simetri',imageUrl:'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',category:'Mimari',description:'Güçlü simetri, anıtsal mimari ve geniş perspektif çizgileri sunar.',recommendedLens:'16-35mm',tags:['Ankara','Mimari','Tarih','Simetri']),
  PhotoSpot(id:'odunpazari',name:'Odunpazarı Evleri',city:'Eskişehir',latitude:39.7654,longitude:30.5256,rating:4.7,bestTime:'08:00 - 10:00',angle:'Dar sokak boyunca çapraz perspektif',imageUrl:'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=900',category:'Sokak',description:'Renkli tarihi evler ve taş sokaklarla portre/sokak çekimi için ideal.',recommendedLens:'24-50mm',tags:['Eskişehir','Sokak','Mimari','Portre']),
  PhotoSpot(id:'sumela',name:'Sümela Manastırı Seyir Noktası',city:'Trabzon',latitude:40.6901,longitude:39.6583,rating:4.9,bestTime:'08:00 - 11:00',angle:'Vadiden manastırı tele lens ile izole et',imageUrl:'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=900',category:'Manzara',description:'Kayalık yüzey, orman ve manastırın birlikte göründüğü dramatik kompozisyon.',recommendedLens:'70-200mm',difficulty:'Orta',tags:['Trabzon','Manzara','Tarih','Doğa']),
  PhotoSpot(id:'bozcaada',name:'Bozcaada Polente Feneri',city:'Çanakkale',latitude:39.8356,longitude:25.9637,rating:4.9,bestTime:'18:00 - 20:30',angle:'Feneri rüzgar gülleriyle aynı eksene getir',imageUrl:'https://images.unsplash.com/photo-1544986581-efac024faf62?w=900',category:'Gün Batımı',description:'Ege gün batımı ve siluet fotoğrafları için güçlü bir nokta.',recommendedLens:'24-70mm',tags:['Çanakkale','Bozcaada','Gün Batımı','Deniz']),
  PhotoSpot(id:'alacati',name:'Alaçatı Taş Sokakları',city:'İzmir',latitude:38.2823,longitude:26.3745,rating:4.8,bestTime:'07:30 - 10:00',angle:'Taş cepheleri ve begonvilleri çapraz kadrajla',imageUrl:'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=900',category:'Sokak',description:'Renkli cepheler, taş doku ve dar sokaklarla lifestyle çekimler için ideal.',recommendedLens:'35-50mm',tags:['İzmir','Alaçatı','Sokak','Portre']),
  PhotoSpot(id:'bodrum-kale',name:'Bodrum Kalesi',city:'Muğla',latitude:37.0319,longitude:27.4290,rating:4.9,bestTime:'17:30 - 20:00',angle:'Marina tarafından kale ve yansımaları birlikte al',imageUrl:'https://images.unsplash.com/photo-1544986581-efac024faf62?w=900',category:'Şehir',description:'Deniz, tekneler ve tarihi kale ile güçlü Ege şehir kompozisyonu.',recommendedLens:'24-70mm',tags:['Muğla','Bodrum','Deniz','Gün Batımı']),
  PhotoSpot(id:'mardin-eski',name:'Eski Mardin Sokakları',city:'Mardin',latitude:37.3128,longitude:40.7350,rating:4.9,bestTime:'07:00 - 10:00',angle:'Taş kemerleri çerçeve olarak kullan',imageUrl:'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',category:'Sokak',description:'Taş mimari, dar geçitler ve Mezopotamya ışığıyla karakterli çekimler.',recommendedLens:'24-50mm',tags:['Mardin','Sokak','Tarih','Mimari']),
  PhotoSpot(id:'harput',name:'Harput Kalesi',city:'Elazığ',latitude:38.7037,longitude:39.2531,rating:4.7,bestTime:'17:00 - 19:30',angle:'Kale duvarlarını şehir manzarasına ön plan yap',imageUrl:'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900',category:'Tarih',description:'Harput dokusu ve Elazığ manzarasını birlikte veren yüksek çekim noktası.',recommendedLens:'24-70mm',tags:['Elazığ','Harput','Tarih','Gün Batımı']),
];
