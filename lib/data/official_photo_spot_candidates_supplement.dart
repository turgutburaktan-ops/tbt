import 'official_photo_spot_candidates.dart';

/// Resmî kaynaklarda yer alıp ilk toplu içe aktarmada eksik kalan adaylar.
/// Kullanıcıya doğrudan gösterilmez; doğrulama kuyruğuna katılır.
const officialPhotoSpotCandidatesSupplement = <OfficialSpotCandidate>[
  // Aksaray İl Kültür ve Turizm Müdürlüğü – eksik doğal/tarihi noktalar
  OfficialSpotCandidate(
    id: 'aks-balikli-golu-full',
    name: 'Balıklı Gölü',
    city: 'Aksaray',
    sourceName: 'Aksaray İl Kültür ve Turizm Müdürlüğü',
    sourcePage:
        'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',
    mapUrl: 'https://goo.gl/maps/1jMRf5CQnTJbt4Wu5',
    suggestedCategory: 'Doğa',
  ),
  OfficialSpotCandidate(
    id: 'aks-kayi-golu-full',
    name: 'Kayı Gölü',
    city: 'Aksaray',
    sourceName: 'Aksaray İl Kültür ve Turizm Müdürlüğü',
    sourcePage:
        'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',
    mapUrl: 'https://goo.gl/maps/9ns4KmPEtY7DiXfe9',
    suggestedCategory: 'Doğa',
  ),
  OfficialSpotCandidate(
    id: 'aks-mamasin-full',
    name: 'Mamasın Baraj Gölü',
    city: 'Aksaray',
    sourceName: 'Aksaray İl Kültür ve Turizm Müdürlüğü',
    sourcePage:
        'https://aksaray.ktb.gov.tr/TR-170580/fotograf-cekim-noktalari.html',
    mapUrl: 'https://goo.gl/maps/indfPHnFQNsgQxpdA',
    suggestedCategory: 'Manzara',
  ),

  // GoTürkiye – İstanbul fotoğraf rehberindeki ilk pakette eksik kalanların tamamlayıcısı
  OfficialSpotCandidate(
    id: 'ist-emirgan',
    name: 'Emirgan Korusu',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Doğa',
  ),
  OfficialSpotCandidate(
    id: 'ist-arnavutkoy',
    name: 'Arnavutköy Sahili',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Şehir',
  ),
  OfficialSpotCandidate(
    id: 'ist-bebek',
    name: 'Bebek Sahili',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Şehir',
  ),
  OfficialSpotCandidate(
    id: 'ist-beykoz',
    name: 'Beykoz Boğaz Kıyıları',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Manzara',
  ),
  OfficialSpotCandidate(
    id: 'ist-beyoglu',
    name: 'Beyoğlu Tarihi Sokakları',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-istiklal',
    name: 'İstiklal Caddesi ve Tarihi Tramvay',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-rainbow-stairs',
    name: 'Gökkuşağı Merdivenleri',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-sultanahmet',
    name: 'Sultanahmet Camii',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Mimari',
  ),
  OfficialSpotCandidate(
    id: 'ist-ortakoy',
    name: 'Ortaköy Camii',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Mimari',
  ),
  OfficialSpotCandidate(
    id: 'ist-tiled-kiosk',
    name: 'Çinili Köşk',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Mimari',
  ),
  OfficialSpotCandidate(
    id: 'ist-balat',
    name: 'Balat Renkli Sokakları',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-heybeliada',
    name: 'Heybeliada',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-burgazada',
    name: 'Burgazada',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'ist-kinaliada',
    name: 'Kınalıada',
    city: 'İstanbul',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/blog/best-photography-spots-in-istanbul',
    suggestedCategory: 'Sokak',
  ),

  // GoTürkiye – Elazığ iki resmî rotasındaki ilk pakette eksik kalanlar
  OfficialSpotCandidate(
    id: 'elz-bugday-ambari',
    name: 'Buğday Ambarı',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'elz-kapalicarsi',
    name: 'Kapalıçarşı',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Sokak',
  ),
  OfficialSpotCandidate(
    id: 'elz-eski-hukumet',
    name: 'Eski Hükûmet Konağı',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Mimari',
  ),
  OfficialSpotCandidate(
    id: 'elz-kultur-park',
    name: 'Kültür Park',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Doğa',
  ),
  OfficialSpotCandidate(
    id: 'elz-alacali-cami',
    name: 'Alacalı Camii',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Mimari',
  ),
  OfficialSpotCandidate(
    id: 'elz-palu-kilise',
    name: 'Palu Kilisesi',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Tarih',
  ),
  OfficialSpotCandidate(
    id: 'elz-hastek-kalesi',
    name: 'Hastek Kalesi',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Tarih',
  ),
  OfficialSpotCandidate(
    id: 'elz-golan',
    name: 'Golan Kaplıcaları',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Doğa',
  ),
  OfficialSpotCandidate(
    id: 'elz-ispir-konagi',
    name: 'İspir Konağı',
    city: 'Elazığ',
    sourceName: 'GoTürkiye',
    sourcePage: 'https://goturkiye.com/tr/elazig/elazig-rotalari',
    suggestedCategory: 'Mimari',
  ),
];

List<OfficialSpotCandidate> get allOfficialPhotoSpotCandidates {
  final byKey = <String, OfficialSpotCandidate>{};
  for (final item in [
    ...officialPhotoSpotCandidates,
    ...officialPhotoSpotCandidatesSupplement,
  ]) {
    final key = '${item.city.toLowerCase()}|${item.name.toLowerCase()}';
    byKey.putIfAbsent(key, () => item);
  }
  return List.unmodifiable(byKey.values);
}
