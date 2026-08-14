/// Türkiye geneli toplu çekim noktası kaynak kataloğu.
/// Bu katman şehir şehir manuel paketleme yerine ulusal tarama için kullanılır.
/// Kullanıcı arayüzünde kaynak etiketi gösterilmez.
class NationwideSpotSource {
  final String city;
  final String sourcePage;
  final List<String> places;
  const NationwideSpotSource(this.city, this.sourcePage, this.places);
}

const nationwideSpotSources = <NationwideSpotSource>[
  NationwideSpotSource('Ankara','https://goturkiye.com/tr/ankara/ankara-rotalari',[
    'Anıtkabir','Ankara Kalesi','Hamamönü','Hacı Bayram Veli Camii ve Augustus Tapınağı','Roma Hamamı','Julianus Sütunu','Beypazarı','Hıdırlık Tepesi','İnözü Vadisi','Nallıhan Kuş Cenneti','Gordion','Kızılcahamam Soğuksu Milli Parkı'
  ]),
  NationwideSpotSource('İzmir','https://goturkiye.com/tr/izmir/routes',[
    'Saat Kulesi','Kemeraltı Çarşısı','Kızlarağası Hanı','Agora','Kadifekale','Pasaport İskelesi','Efes','Şirince','Sığacık Kaleiçi','Teos','Klazomenai','Erythrai','Alaçatı'
  ]),
  NationwideSpotSource('Bolu','https://goturkiye.com/tr/bolu/bolu-rotalari',[
    'Gölcük Tabiat Parkı','Aladağ Yaylaları','Seben Gölü','Seben Kaya Evleri','Yedigöller Milli Parkı','Yeniçağa Gölü Kuş Cenneti','Akkaya Travertenleri','Mudurnu','Sülüklü Göl Tabiat Parkı','Abant Gölü','Sünnet Gölü'
  ]),
  NationwideSpotSource('Ordu','https://goturkiye.com/tr/ordu/ordu-rotalari',[
    'Boztepe','Kurul Kalesi','Yoroz Kent Ormanı','Ordu Sahili','Perşembe Yaylası ve Menderesler','Gelin Kayası','Budak Kanyonu','Gaga Gölü','Yason Burnu','Hoynat Adası','Ünye Kalesi','Çakırtepe'
  ]),
  NationwideSpotSource('Iğdır','https://goturkiye.com/tr/igdir/igdir-rotalari',[
    'İrem Bağları','Tekelti Dağı','Ağrı Dağı Milli Parkı','Tuz Mağarası','Üçkaya Vadisi','Üçkaya Gölü','Gökkuşağı Tepeleri','Aras Nehri Kuş Cenneti','Tuzluca Tuz Mağaraları'
  ]),
  NationwideSpotSource('Uşak','https://goturkiye.com/tr/usak/usak-rotalari',[
    'Blaundus','Akmonia','Sebaste','Pepouza','Tarihi Uşak Evleri','Lavanta Bahçeleri','Ulubey Kanyonları','Clandıras Köprüsü','Taşyaran Vadisi'
  ]),
  NationwideSpotSource('Bursa','https://goturkiye.com/tr/bursa/rotalar',[
    'Koza Han','Cumalıkızık','Uludağ','Saitabat Şelalesi','Oylat Mağarası','Suuçtu Şelalesi'
  ]),
  NationwideSpotSource('Isparta','https://isparta.ktb.gov.tr/Eklenti/80725%2Cegirdirbrosurpdf.pdf?0=',[
    'Akpınar Köyü Seyir Terası','Boyalı Koyu','Kovada Gölü Milli Parkı','Altınkum Plajı'
  ]),
];

/// Ulusal tarama sırasında tüm şehirler bu sırayla ele alınır; kaynakta rota
/// bulunmayan şehirler İl Kültür ve Turizm Müdürlüğü/Kültür Portalı ile tamamlanır.
const turkiye81Cities = <String>[
  'Adana','Adıyaman','Afyonkarahisar','Ağrı','Aksaray','Amasya','Ankara','Antalya','Ardahan','Artvin','Aydın','Balıkesir','Bartın','Batman','Bayburt','Bilecik','Bingöl','Bitlis','Bolu','Burdur','Bursa','Çanakkale','Çankırı','Çorum','Denizli','Diyarbakır','Düzce','Edirne','Elazığ','Erzincan','Erzurum','Eskişehir','Gaziantep','Giresun','Gümüşhane','Hakkari','Hatay','Iğdır','Isparta','İstanbul','İzmir','Kahramanmaraş','Karabük','Karaman','Kars','Kastamonu','Kayseri','Kırıkkale','Kırklareli','Kırşehir','Kilis','Kocaeli','Konya','Kütahya','Malatya','Manisa','Mardin','Mersin','Muğla','Muş','Nevşehir','Niğde','Ordu','Osmaniye','Rize','Sakarya','Samsun','Siirt','Sinop','Sivas','Şanlıurfa','Şırnak','Tekirdağ','Tokat','Trabzon','Tunceli','Uşak','Van','Yalova','Yozgat','Zonguldak'
];
