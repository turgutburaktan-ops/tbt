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
    assetPath: 'assets/spots/ayasofya.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Ayasofya%2C_%C4%B0stanbul%2C_T%C3%BCrkiye.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Mertaydintr',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Ayasofya,_İstanbul,_Türkiye.jpg',
  ),
  'kiz-kulesi': SpotImageInfo(
    assetPath: 'assets/spots/kiz-kulesi.jpg',
    networkUrl:
        'https://upload.wikimedia.org/wikipedia/commons/f/fa/Maiden%27s_Tower_in_Istanbul.jpg',
    sourceName: 'Wikimedia Commons',
    author: 'İlke.bahceci',
    license: 'CC0 1.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Maiden%27s_Tower_in_Istanbul.jpg',
  ),
  'kapadokya': SpotImageInfo(
    assetPath: 'assets/spots/kapadokya.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Cappadocia_Goreme_hot_air_balloon.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'L1tr1z',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Cappadocia_Goreme_hot_air_balloon.jpg',
  ),
  'galata': SpotImageInfo(
    assetPath: 'assets/spots/galata.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Galata-Tower.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Mohemedşebir Farook',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Galata-Tower.jpg',
  ),
  'efes': SpotImageInfo(
    assetPath: 'assets/spots/efes.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Library_of_Celsus.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Carl Campbell',
    license: 'CC BY 2.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Library_of_Celsus.jpg',
  ),
  'pamukkale': SpotImageInfo(
    assetPath: 'assets/spots/pamukkale.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Pamukkale_travertenleri.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Cobija',
    license: 'CC0 1.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Pamukkale_travertenleri.jpg',
  ),
  'sumela': SpotImageInfo(
    assetPath: 'assets/spots/sumela.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Monastere_Sumela.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Vol de nuit',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Monastere_Sumela.jpg',
  ),
  'nemrut': SpotImageInfo(
    assetPath: 'assets/spots/nemrut.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Mount_nemrut_in_Turkey.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Mkrc85',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Mount_nemrut_in_Turkey.jpg',
  ),
  'mardin-eski': SpotImageInfo(
    assetPath: 'assets/spots/mardin-eski.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Mardin_old_city.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Radosław Botev',
    license: 'CC BY 3.0 PL',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Mardin_old_city.jpg',
  ),
  'oludeniz': SpotImageInfo(
    assetPath: 'assets/spots/oludeniz.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/%C3%96l%C3%BCdeniz_on_the_Turquoise_Coast%2C_Turkey.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Sevtap Ön',
    license: 'CC BY 3.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:%C3%96l%C3%BCdeniz_on_the_Turquoise_Coast%2C_Turkey.jpg',
  ),
  'anitkabir': SpotImageInfo(
    assetPath: 'assets/spots/anitkabir.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Anitkabir_Ankara.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Lethiciasouza',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Anitkabir_Ankara.jpg',
  ),
  'alacati': SpotImageInfo(
    assetPath: 'assets/spots/alacati.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Alacati_Streets.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Write it Right UAE',
    license: 'CC BY-SA 4.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Alacati_Streets.jpg',
  ),
  'bozcaada': SpotImageInfo(
    assetPath: 'assets/spots/bozcaada.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Polente_lighthouse_in_Bozcaada%2C_under_a_wind_turbine.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Raicem',
    license: 'CC0 1.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Polente_lighthouse_in_Bozcaada,_under_a_wind_turbine.jpg',
  ),
  'elazig-alacali-camii': SpotImageInfo(
    assetPath: 'assets/spots/elazig-alacali-camii.webp',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Harput_Alacal%C4%B1_Camii.webp?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Dkask',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Harput_Alacalı_Camii.webp',
  ),
  'elz-alacali-cami': SpotImageInfo(
    assetPath: 'assets/spots/elz-alacali-cami.webp',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Harput_Alacal%C4%B1_Camii.webp?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Dkask',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Harput_Alacalı_Camii.webp',
  ),
  'elazig-harput-ulu-camii': SpotImageInfo(
    assetPath: 'assets/spots/elazig-harput-ulu-camii.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Harput_Ulu_Camii_21.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Dkask',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Harput_Ulu_Camii_21.jpg',
  ),
  'elz-harput-ulu': SpotImageInfo(
    assetPath: 'assets/spots/elz-harput-ulu.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Harput_Ulu_Camii_21.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Dkask',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Harput_Ulu_Camii_21.jpg',
  ),
};
