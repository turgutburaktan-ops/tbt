import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/theme/app_theme.dart';
import '../lib/widgets/app_page_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      // Explicit component text styles inherit the test font; provide its real glyphs too.
      final fallback = FontLoader('Ahem');
      fallback.addFont(
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await fallback.load();
      final font = FontLoader('Roboto');
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        final f = File('$flutterRoot/bin/cache/artifacts/material_fonts/$name');
        if (await f.exists())
          font.addFont(
            Future.value(ByteData.sublistView(await f.readAsBytes())),
          );
      }
      await font.load();
      final icon = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icon.exists())
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(await icon.readAsBytes())),
            ))
            .load();
    }
  });

  testWidgets(
    'heading action and tabs remain usable with large text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppPageHeading(
                      title: 'Rotalar',
                      action: FilledButton(
                        onPressed: () => calls++,
                        child: const Text('Rota oluştur'),
                      ),
                    ),
                    AppSectionTabs(
                      labels: const ['Rotalarım', 'Keşfet'],
                      selected: 0,
                      onChanged: (i) => selected = i,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rota oluştur'));
      await tester.tap(find.text('Keşfet'));
      expect(calls, 1);
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('render shared visual language with illustrative content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark.copyWith(
          textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: _PreviewPage(index: i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/design-preview').create(recursive: true);
      await File('build/design-preview/tbt-visual-system.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'TBT  /  TASARIM ÖNİZLEMESİ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            AppPageHeading(
              title: ['TBT', 'Mekânlar', 'Rotalar'][index],
              subtitle: index == 1
                  ? 'Lezzet, kahve, konaklama ve gezilecek yerler.'
                  : null,
              action: index == 0
                  ? IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none),
                    )
                  : index == 1
                  ? OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Harita'),
                    )
                  : FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('Rota oluştur'),
                    ),
            ),
            const SizedBox(height: 16),
            if (index == 0) ...[
              AppSectionTabs(
                labels: const ['Ana Sayfa', 'Keşfet'],
                selected: 0,
                onChanged: (_) {},
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final name in ['Sen', 'Deniz', 'Ece', 'TBT'])
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.surfaceStrong,
                          child: Icon(
                            name == 'Sen' ? Icons.add : Icons.person_outline,
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(name),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppSectionTabs(
                labels: const ['Sana Özel', 'Takip'],
                selected: 0,
                onChanged: (_) {},
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text('TBT Rehber'),
                      subtitle: Text('Nevşehir'),
                    ),
                    Image.asset(
                      'assets/spots/auto-route-goreme.jpg',
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.favorite_border),
                              SizedBox(width: 20),
                              Icon(Icons.chat_bubble_outline),
                              SizedBox(width: 20),
                              Icon(Icons.send_outlined),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text('Yeni yerler, yeni hikâyeler.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (index == 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in [
                    'Gezilecek Yerler',
                    'Lezzet',
                    'Kafeler',
                    'Oteller',
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: label == 'Gezilecek Yerler',
                      onSelected: (_) {},
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.location_city_outlined,
                    color: AppColors.cyan,
                  ),
                  title: const Text('Elazığ'),
                  subtitle: const Text('Şehir değiştirmek için dokun'),
                  trailing: const Icon(Icons.expand_more),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Gezilecek yerlerde ara',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Popüler'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  ChoiceChip(
                    label: const Text('En yakın'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final title in ['Harput', 'Palu Kalesi'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const Icon(
                        Icons.landscape_outlined,
                        color: AppColors.cyan,
                        size: 36,
                      ),
                      title: Text(title),
                      subtitle: const Text('Elazığ · Kültür mirası'),
                      trailing: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ),
                ),
            ] else ...[
              AppSectionTabs(
                labels: const ['Rotalarım', 'Keşfet'],
                selected: 0,
                onChanged: (_) {},
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final label in ['Yaklaşan', 'Tamamlanan', 'Kaydedilen'])
                    ChoiceChip(
                      label: Text(label),
                      selected: label == 'Yaklaşan',
                      onSelected: (_) {},
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'YAKLAŞAN GEZİN',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/spots/auto-route-goreme.jpg',
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hafta sonu Kapadokya',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text('19 Eylül · 09.00'),
                          const SizedBox(height: 8),
                          const Text('Araç · 4 durak · 3 kişi'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Rotayı aç'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Örnek içerik • Ortak tema ve bileşenler',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            label: 'Mekânlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: 'Rota',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            label: 'Çevrende',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    ],
  );
}
