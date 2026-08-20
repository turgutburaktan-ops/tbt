import 'spot_image_registry.dart';

/// Gezilecek yer çekirdek kataloğu için elle doğrulanmış görseller.
/// Bu kayıtlar otomatik görsel aramasından ve eski katalogdan daha yüksek
/// önceliğe sahiptir. Kaynak sayfası + yazar + lisans birlikte tutulur.
const verifiedTravelImageRegistry = <String, SpotImageInfo>{
  'ankara-kale': SpotImageInfo(
    assetPath: 'assets/spots/ankara-kale.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Ankara_Castle.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Bernard Gagnon',
    license: 'CC BY-SA 3.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Ankara_Castle.jpg',
  ),
  'safranbolu': SpotImageInfo(
    assetPath: 'assets/spots/safranbolu.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Safranbolu_06609_20070130130656.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Nevit Dilmen',
    license: 'CC BY-SA 3.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Safranbolu_06609_20070130130656.jpg',
  ),
  'assos': SpotImageInfo(
    assetPath: 'assets/spots/assos.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Assos_%281995%29_19_%287902773580%29.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Carl Campbell',
    license: 'CC BY 2.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Assos_(1995)_19_(7902773580).jpg',
  ),
  'bodrum-kale': SpotImageInfo(
    assetPath: 'assets/spots/bodrum-kale.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/TurkeyBodrumCastle.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Horvat',
    license: 'Public domain',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:TurkeyBodrumCastle.jpg',
  ),
  'salda': SpotImageInfo(
    assetPath: 'assets/spots/salda.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Lake_Salda_Nature_Park_1.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Shanti Alex',
    license: 'CC BY-SA 4.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Lake_Salda_Nature_Park_1.jpg',
  ),
  'konya-mevlana': SpotImageInfo(
    assetPath: 'assets/spots/konya-mevlana.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Molavi1.JPG?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'دانقولا',
    license: 'CC0 1.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Molavi1.JPG',
  ),
  'goreme-acik-hava': SpotImageInfo(
    assetPath: 'assets/spots/goreme-acik-hava.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Churches_in_G%C3%B6reme_11.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Antoine Taveneaux',
    license: 'CC BY-SA 3.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Churches_in_G%C3%B6reme_11.jpg',
  ),
  'harput-kalesi': SpotImageInfo(
    assetPath: 'assets/spots/harput-kalesi.jpg',
    networkUrl:
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Festung_Harput.jpg?width=1280',
    sourceName: 'Wikimedia Commons',
    author: 'Ingeborg Simon',
    license: 'CC BY-SA 3.0',
    sourcePage:
        'https://commons.wikimedia.org/wiki/File:Festung_Harput.jpg',
  ),
};
