class SpotImageInfo {
  final String assetPath;
  final String networkUrl;
  final String sourceName;
  final String author;
  final String license;
  final String sourcePage;

  const SpotImageInfo({
    this.assetPath = '',
    this.networkUrl = '',
    required this.sourceName,
    required this.author,
    required this.license,
    required this.sourcePage,
  });
}

/// API anahtarı veya ücretli servis gerektirmeyen doğrulanmış gerçek fotoğraf kataloğu.
///
/// `assetPath` doluysa uygulama paketindeki yerel dosya kullanılır. Yerel dosya
/// henüz eklenmemişse `networkUrl` doğrudan lisanslı statik medya dosyasını
/// gösterir. Bu URL'ler API çağrısı değildir; anahtar/kota gerektirmez.
/// Her kayıt gerçekten ilgili çekim noktasını göstermeli ve lisans bilgisi
/// kaynak sayfasından doğrulanmalıdır.
const spotImageRegistry = <String, SpotImageInfo>{
  'ayasofya': SpotImageInfo(
    networkUrl: 'https://commons.wikimedia.org/wiki/Special:Redirect/file/Ayasofya%2C_%C4%B0stanbul%2C_T%C3%BCrkiye.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Mertaydintr',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Ayasofya,_İstanbul,_Türkiye.jpg',
  ),
  'kiz-kulesi': SpotImageInfo(
    networkUrl: 'https://upload.wikimedia.org/wikipedia/commons/f/fa/Maiden%27s_Tower_in_Istanbul.jpg',
    sourceName: 'Wikimedia Commons',
    author: 'İlke.bahceci',
    license: 'CC0 1.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Maiden%27s_Tower_in_Istanbul.jpg',
  ),
  'kapadokya': SpotImageInfo(
    networkUrl: 'https://commons.wikimedia.org/wiki/Special:Redirect/file/Cappadocia_Goreme_hot_air_balloon.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'L1tr1z',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Cappadocia_Goreme_hot_air_balloon.jpg',
  ),
};
