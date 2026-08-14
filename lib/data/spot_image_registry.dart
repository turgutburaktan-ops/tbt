class SpotImageInfo {
  final String assetPath;
  final String sourceName;
  final String author;
  final String license;
  final String sourcePage;

  const SpotImageInfo({
    required this.assetPath,
    required this.sourceName,
    required this.author,
    required this.license,
    required this.sourcePage,
  });
}

/// API'siz gerçek fotoğraf kataloğu.
///
/// Her fotoğraf uygulamanın `assets/spots/` klasöründe fiziksel olarak bulunur.
/// Bir görsel eklenmeden önce fotoğrafın gerçekten ilgili noktayı gösterdiği ve
/// dağıtım lisansının uygulama paketinde kullanıma izin verdiği doğrulanmalıdır.
/// Kaynak/lisans bilgisi bu registry'de fotoğrafla birlikte tutulur.
const spotImageRegistry = <String, SpotImageInfo>{
  // Örnek kayıt biçimi:
  // 'galata': SpotImageInfo(
  //   assetPath: 'assets/spots/istanbul/galata.webp',
  //   sourceName: 'Wikimedia Commons',
  //   author: 'Fotoğrafçı adı',
  //   license: 'CC BY-SA 4.0',
  //   sourcePage: 'Kaynak sayfa adresi',
  // ),
};
