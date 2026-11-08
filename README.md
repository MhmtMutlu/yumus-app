# Yumuş web sitesi

Yumuş'un (çocuklar için reklamsız, aboneliksiz, veri toplamayan slime ve rahatlama uygulaması) tanıtım, gizlilik ve destek sayfaları. Statik HTML + CSS; tek JavaScript dosyası ana sayfadaki slime'ı dokunmaya ve sürüklemeye tepki verir hale getirir (`assets/js/slime.js`, yay simülasyonu, "hareketi azalt" ayarına uyar). Çerez, analitik ve üçüncü taraf istek yok. GitHub Pages ile `main` dalının kökünden yayınlanır.

## App Store Connect adresleri

| Alan | Adres |
| --- | --- |
| Gizlilik politikası (TR) | https://yumus.mm-apps.com/gizlilik/ |
| Gizlilik politikası (EN) | https://yumus.mm-apps.com/en/privacy/ |
| Destek | https://yumus.mm-apps.com/destek/ (EN: https://yumus.mm-apps.com/en/support/) |
| Pazarlama | https://yumus.mm-apps.com/ (EN: https://yumus.mm-apps.com/en/) |

Bu yolları değiştirmeyin; App Store Connect bunlara bağlanır.

## Ne nerede

| Yol | İçerik |
| --- | --- |
| `index.html`, `en/index.html` | Tanıtım sayfası (TR varsayılan, EN `/en/` altında) |
| `gizlilik/`, `en/privacy/` | Gizlilik politikası |
| `destek/`, `en/support/` | Sık sorulanlar ve iletişim |
| `404.html`, `robots.txt`, `sitemap.xml` | GitHub Pages hata sayfası, tarayıcı dosyaları |
| `favicon.svg`, `favicon.png`, `apple-touch-icon.png` | Simgeler |
| `assets/css/site.css` | Tüm stiller; renk ve yüzey token'ları `yumus-handoff/docs/01` ile aynı |
| `assets/fonts/` | Fredoka ve Nunito (SIL OFL 1.1, lisans dosyaları yanında), siteden sunulur |
| `assets/img/layers/` | Uygulamanın render katmanları (slime, şişe, pop it, mıknatıs…), WebP |
| `assets/img/shots/` | iPhone 17 Pro simülatöründen ekran görüntüleri, WebP |
| `assets/img/og-image-tr.png`, `og-image-en.png` | Paylaşım görselleri (1200×630) |
| `src/` | Sayfa şablonları ve `site.json` (adlar, metinler, sayfa listesi) |
| `tools/build.py` | `src/`'den sayfaları üretir (yalnızca Python standart kütüphanesi) |
| `tools/og-image.swift` | Paylaşım görsellerini katmanlardan ve fontlardan üretir (macOS) |

**Kök dizindeki HTML dosyaları üretilmiş dosyalardır; elle düzenlemeyin.** Değişiklikleri `src/` altında yapıp derleyin.

## Ad değişikliği (marka kararı)

Uygulama adı ("Yumuş") ve "Pop It" / "Kinetik Kum" adları henüz yer tutucu. Her dil için tek yerde durur: `src/site.json` → `strings.tr` ve `strings.en` içindeki `app`, `plus`, `pop_it`, `kinetic_sand`. Değiştirdikten sonra:

```bash
python3 -I tools/build.py        # sayfaları, sitemap ve robots dosyalarını yeniden üretir
swift tools/og-image.swift       # paylaşım görsellerini yeni adla yeniden çizer
```

`site.json` içindeki metinler HTML'e olduğu gibi girer; `&`, `<` ve `"` kullanırsanız HTML karşılıklarını yazın. Türkçe metinlerde ada ek getirilmedi ("Yumuş'ta" gibi), yeni ad hangi ünlüyle biterse bitsin cümleler bozulmaz. Uygulama içi ekran görüntülerindeki ad ve sabun üstündeki kabartma yazı yeni yapıdan yeniden alınmalı.

## Yerelde önizleme

```bash
python3 -I tools/build.py --check   # üretilmiş dosyalar güncel mi
python3 -m http.server 8000         # depo kökünde
```

Tarayıcıda http://localhost:8000/ açın. `404.html`, özel alan adında (`yumus.mm-apps.com`, kök) çalışacak şekilde ayarlıdır: http://localhost:8000/404.html.

iPhone görünümü için simülatörde: `xcrun simctl openurl booted http://localhost:8000/`.

## GitHub Pages'i açma

1. Depoyu GitHub'a gönderin (`git push -u origin main`).
2. GitHub → depo → **Settings → Pages**.
3. **Build and deployment → Source: Deploy from a branch**, **Branch: `main`**, klasör **`/ (root)`** → **Save**.
4. Birkaç dakika sonra site https://yumus.mm-apps.com/ adresinde yayında olur. `.nojekyll` dosyası Jekyll işlemesini kapatır.

## Özel alan adı eklenirse

1. `src/site.json`: `base_url` → `https://alanadi/`, `base_path` → `/`.
2. `python3 -I tools/build.py` (canonical, hreflang, og:image, sitemap, robots ve 404 sayfasının `<base>` etiketi güncellenir).
3. Settings → Pages → Custom domain; GitHub'ın oluşturduğu `CNAME` dosyasını depoda tutun, **Enforce HTTPS**'i açın.
4. App Store Connect'teki gizlilik, destek ve pazarlama adreslerini yeni alan adıyla güncelleyin.

Not: site özel alan adının kökünde (`yumus.mm-apps.com`) yayınlandığı için `robots.txt` ve `sitemap.xml` doğrudan geçerlidir.

## App Store'a çıkış günü

- `src/pages/*/index.html` içindeki "Yakında App Store'da" kutusunu App Store bağlantısına çevirin (Apple'ın resmî rozetini kullanacaksanız Apple Marketing Resources'tan indirip `assets/img/` altına koyun, siteden sunun).
- Destek sayfasındaki "Ne zaman çıkıyor?" cevabını ve iki dildeki "TestFlight'ta test ediliyor" notlarını güncelleyin.
- Fiyatı sitede yazmak isterseniz Plus bölümündeki "Fiyat App Store'da görünecek" notunu değiştirin.

## Kurallar

- Üçüncü taraf istek yok: font, görsel ve stil bu depodan gelir. CSP (`default-src 'self'`) satır içi stil ve betiğe izin vermez; `style=""` ve `<script>` eklemeyin.
- Gizlilik metni `yumus-handoff/docs/11` §4 taslağına dayanır; uygulamanın veri davranışı değişirse (ağ, analitik, yeni izin) bu sayfa da aynı gün güncellenmeli ve "Son güncelleme" tarihi `src/pages/*/gizlilik.html` / `privacy.html` içinde değiştirilmeli.
- Ücretsiz/Plus tablosu `docs/06` ile aynı tutulur; yapılmamış öğeler (docs/06'da `*` ile işaretli) listelenmez.
- Renkler `docs/01` token'larıdır; metin kontrastı süt zemin ve oyun kartlarında ≥ 4.5:1.
