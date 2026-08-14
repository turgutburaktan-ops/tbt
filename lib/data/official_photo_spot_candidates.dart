class OfficialSpotCandidate {
  final String id;
  final String name;
  final String city;
  final String sourceName;
  final String sourcePage;
  final String? mapUrl;
  final String suggestedCategory;

  const OfficialSpotCandidate({
    required this.id,
    required this.name,
    required this.city,
    required this.sourceName,
    required this.sourcePage,
    this.mapUrl,
    this.suggestedCategory = 'Genel',
  });
}

/// Ham, toplu kaynak kataloğu. Bu liste kullanıcıya doğrudan gösterilmez.
/// Noktalar koordinat, çekim açısı ve görsel doğrulaması tamamlandıktan sonra
/// üretim PhotoSpot kataloğuna aktarılır. Böylece yanlış pin üretmeyiz.
const officialPhotoSpotCandidates = <OfficialSpotCandidate>[
  // Aksaray İl Kültür ve Turizm Müdürlüğü – Fotoğraf Çekim Noktaları
  OfficialSpotCandidate(id:'aks-hasandagi',name:'Hasandağı ve Çevresi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/J9MSPjSyLE9jY1gQ8',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'aks-ihlara',name:'Ihlara Vadisi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/m7PjLSDPuvhm87Ds9',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-selime-peribacalari',name:'Selime Peribacaları',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/vdaftEu7WGBcLBL69',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-manastir-vadisi',name:'Manastır Vadisi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/sMukT5JrFZm3bhfP6',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-guzelyurt-goleti',name:'Güzelyurt Göleti',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/uCfdE6F2aBXPFqacA',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-narli-gol',name:'Narlı Göl',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/vbdcpz67RXnGKD3V7',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-balikli-golu',name:'Balıklı Gölü',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/1jMRf5CQnTJbt4Wu5',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-kayi-golu',name:'Kayı Gölü',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/9ns4KmPEtY7DiXfe9',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-tuz-golu',name:'Tuz Gölü',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/zkN9thFPNzcJ7YG19',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'aks-flamingo',name:'Tuz Gölü Flamingo Gözlem Noktası',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/jupvmnX4huybupAFA',suggestedCategory:'Yaban Hayatı'),
  OfficialSpotCandidate(id:'aks-mamasin',name:'Mamasın Baraj Gölü',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/indfPHnFQNsgQxpdA',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'aks-helvadere',name:'Helvadere Göleti',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/9QWjLkmaRtfzgymh7',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-yaprakhisar-panorama',name:'Yaprakhisar Panorama Noktası',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/KF6d4eWyCGsUKb8g6',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'aks-belisirma-panorama',name:'Belisırma Panorama Noktası',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/LUdcMAmwK1gpWzaw6',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'aks-guzelyurt-evleri',name:'Güzelyurt İlçe Merkezi Eski Evleri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/j9Jvh5DWPuT3dRtX7',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'aks-kilise-cami',name:'Güzelyurt Kilise Cami',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/Vuza43p46kncJWyz6',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'aks-sivisli-kilise',name:'Sivişli Kilise',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/CgmDkVbfv72YA1Zy7',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-kizil-kilise',name:'Kızıl Kilise',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/Sr9zSmSFzzraDWYw7',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-yuksek-kilise',name:'Yüksek Kilise',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/cAh9h8wYyrRrAzi68',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-ihlara-kiliseleri',name:'Ihlara Vadisi Kiliseleri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/5u7mv7hgrfCbK1Zn6',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-belisirma-eski',name:'Belisırma Eski Evleri ve Kiliseleri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/w2gvGCeXCRv4YW7a7',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'aks-selime-katedral',name:'Selime Katedrali ve Kaya Oyma Yapılar',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/g6eHcWbeT69JKzU47',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-yaprakhisar-kalesi',name:'Yaprakhisar Kalesi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/SsGAd5wzBWcD1vcC6',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-yaprakhisar-koprusu',name:'Yaprakhisar Köprüsü',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/iWyg99cBbWP8vY6W8',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-mokisos',name:'Viranşehir Mokisos',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/mtMEjjaFmimh7MLA6',suggestedCategory:'Arkeoloji'),
  OfficialSpotCandidate(id:'aks-ulucami',name:'Ulu Cami',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/FsG5EGn8VnZ2fWoF8',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'aks-egri-minare',name:'Eğri Minare',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/iSAh25Lkoi6Lv4Ds7',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'aks-sultanhani',name:'Sultanhanı Kervansarayı',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/Bfr5nxxDnDjSnT1H6',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-agzikarahan',name:'Ağzıkarahan Kervansarayı',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/ApnTWFWYPXU1uZe9A',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-tepesi-delik-han',name:'Tepesi Delik Han',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/PiCqL6vbhZNqMB8c8',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-demirci-sokaklari',name:'Demirci Kasabası Eski Sokakları',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/qJG9xtJ6AwmZHRMy7',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'aks-mercurius',name:'Saratlı Aziz Mercurius Yeraltı Şehri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/8q4E5jjNJyjnQPLY9',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-kirkgoz',name:'Saratlı Aziz Kırkgöz Yeraltı Şehri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/Ek1CRYcQXNmrnHPHA',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-guvercin-kayasi',name:'Güvercin Kayası',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/paw4Kg27MeXNLr2s5',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-gaziemir',name:'Gaziemir Yeraltı Şehri',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/ytPjSBoYXahPtaHw5',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'aks-sofular',name:'Sofular Vadisi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/5Z2K5FjN9jLCyNuK7',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'aks-somuncu-baba',name:'Somuncu Baba Külliyesi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/atv6DFEGDa9XJv9H7',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'aks-azmi-milli',name:'Azmi Millî Un Fabrikası',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/KsYfiWfLEgX2voSo6',suggestedCategory:'Endüstriyel'),
  OfficialSpotCandidate(id:'aks-zinciriye',name:'Zinciriye Medresesi',city:'Aksaray',sourceName:'Aksaray İl Kültür ve Turizm Müdürlüğü',sourcePage:'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',mapUrl:'https://goo.gl/maps/agtvpF3sbdX8nq1S7',suggestedCategory:'Mimari'),

  // GoTürkiye – İstanbul fotoğraf noktaları
  OfficialSpotCandidate(id:'ist-anadoluhisari',name:'Anadolu Hisarı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'ist-rumelihisari',name:'Rumeli Hisarı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'ist-cengelkoy',name:'Çengelköy Sahili',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Şehir'),
  OfficialSpotCandidate(id:'ist-kamondo',name:'Kamondo Merdivenleri',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'ist-ihlamur-kasri',name:'Ihlamur Kasrı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'ist-yildiz-park',name:'Yıldız Parkı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'ist-macka',name:'Maçka Demokrasi Parkı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'ist-gulhane',name:'Gülhane Parkı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'ist-ataturk-arboretum',name:'Atatürk Arboretumu',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'ist-belgrad',name:'Belgrad Ormanı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'ist-suleymaniye',name:'Süleymaniye Camii',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'ist-topkapi',name:'Topkapı Sarayı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'ist-misir-carsisi',name:'Mısır Çarşısı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'ist-kapali-carsi',name:'Kapalıçarşı',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'ist-pierre-loti',name:'Pierre Loti Tepesi',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'ist-buyukada',name:'Büyükada',city:'İstanbul',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/blog/best-photography-spots-in-istanbul',suggestedCategory:'Sokak'),

  // GoTürkiye – Elazığ rotaları
  OfficialSpotCandidate(id:'elz-bakircilar',name:'Bakırcılar Çarşısı',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'elz-kazim-efendi',name:'Kazım Efendi Sokağı',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'elz-harput-kalesi',name:'Harput Kalesi',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'elz-harput-ulu',name:'Harput Ulu Camii',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Mimari'),
  OfficialSpotCandidate(id:'elz-meryem-ana',name:'Meryem Ana Kilisesi',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'elz-buzluk',name:'Buzluk Mağarası',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'elz-kara-leylek',name:'Kara Leylek Kanyonu',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'elz-palu-kalesi',name:'Palu Kalesi ve Urartu Kaya Kitabesi',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'elz-palu-kopru',name:'Palu Taş Köprüsü',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Tarih'),
  OfficialSpotCandidate(id:'elz-bademli',name:'Bademli Kaya Mezarları',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Arkeoloji'),
  OfficialSpotCandidate(id:'elz-agin',name:'Ağın Tarihi Evleri',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Sokak'),
  OfficialSpotCandidate(id:'elz-saklikapi',name:'Saklıkapı Kanyonu',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'elz-circir',name:'Çırçır Şelalesi',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Doğa'),
  OfficialSpotCandidate(id:'elz-hazarbaba',name:'Hazarbaba',city:'Elazığ',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/tr/elazig/elazig-rotalari',suggestedCategory:'Manzara'),

  // GoTürkiye – 3 günlük fotoğraf rotası
  OfficialSpotCandidate(id:'route-nemrut',name:'Nemrut Dağı Milli Parkı',city:'Adıyaman',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/routes/3-day-photo-route-turkiye-national-parks',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'route-goreme',name:'Göreme Milli Parkı',city:'Nevşehir',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/routes/3-day-photo-route-turkiye-national-parks',suggestedCategory:'Manzara'),
  OfficialSpotCandidate(id:'route-koprulu',name:'Köprülü Kanyon Milli Parkı',city:'Antalya',sourceName:'GoTürkiye',sourcePage:'https://goturkiye.com/routes/3-day-photo-route-turkiye-national-parks',suggestedCategory:'Doğa'),
];
