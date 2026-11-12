# Handover: A2UI Tech Reader

## Mi a helyes feladathatár?

A felhasználó pontosítása: **a hírek a hírfolyamban legyenek A2UI-val megjelenítve; az alkalmazás kerete nem kell, hogy A2UI legyen.** A korábban mellékelt specifikáció e tekintetben hibás. A Flutter keretben maradhat a fejléc, az RSS-forrás választása, az alkalomválasztó, a kereső és a fejlesztői JSON-nézet. Touch most nem része a feladatnak.

## Jelenlegi állapot

- Az `RssService` HTTP-n letölti és feldolgozza az RSS/Atom feedet. A `NewsItem` tartalmazza a címet, linket, forrást, leírást, opcionális képet és dátumot.
- A Flutter keret szűri a híreket a kereső alapján, kezeli a forrás és az alkalom kiválasztását, majd meghívja a `NewsA2uiBuilder.build` metódust.
- A builder A2UI 1.0 `createSurface` és `updateComponents` üzeneteket készít a telepített `a2ui_flutter 0.3.0` / `a2ui_core 0.7.0` Basic Cataloghoz. A hivatalos `MessageProcessor` és `A2uiSurface` dolgozza fel és jeleníti meg a **hírfolyamot**.
- A hírkártyák, képek, források, dátumok, szekciók, olvasás gombok, valamint a betöltési, üres és hibaállapotok A2UI-komponensek. A cikk gombja A2UI actiont küld; a Flutter host a cikk eredeti URL-jét nyitja meg.
- Az app sávjában a `{ }` ikon az aktuálisan a processzornak átadott A2UI JSON-t mutatja.
- A Normal, Christmas, Winter Games és Easter hírfolyam eltérő A2UI komponensfát használ. Az alkalmi szekciók csak tényleges szöveges egyezésű hírekből épülnek, a hír tartalma nem módosul.
- A webes és Windows Flutter platformfájlok bekerültek a példába; Touch függőség nincs benne.

## Fontos: az AI jelenleg nincs bekötve

**Igen, az elrendezési szabályok előre meg vannak írva** a `lib/a2ui_builder.dart` fájlban. A feed tartalma változik, és ebből minden frissítéskor új A2UI JSON készül, de az elrendezést nem AI választja vagy generálja. Az A2UI itt protokoll és renderer, nem AI-szolgáltatás. A mellékelt eredeti specifikáció kifejezetten azt írta, hogy AI nem kell; a felhasználó később ezt megkérdőjelezte. Az AI kívánt szerepe **nyitott termékdöntés**. Mielőtt bárki modellt vagy promptot kötne be, tisztázni kell, hogy az AI a teljes hírfolyam A2UI fáját készítse-e, csak a hírkiemelést és csoportosítást válassza-e, vagy más feladata legyen. A jelenlegi determinisztikus működést nem szabad AI-demóként bemutatni.

## Fájlok

- `lib/main.dart`: Flutter keret, RSS-életciklus, keresés, alkalomválasztás, A2UI processor és action kezelés, JSON-nézet.
- `lib/a2ui_builder.dart`: a négy, jelenleg **kézzel meghatározott** A2UI hírfolyam-kompozíció.
- `lib/rss_service.dart`: RSS/Atom letöltés és XML-feldolgozás; ISO és gyakori RFC 822 dátumok támogatása.
- `lib/models.dart`: hírmodell, feed presetek, alkalom és Flutter keretstílus.
- `test/a2ui_render_test.dart`: mind a négy generált üzenetsor ellenőrzése a hivatalos rendererrel.

## Ellenőrzés és korlátok

A legutóbbi módosítások után sikeres volt a `flutter test --no-pub` (9 teszt), a `flutter analyze --no-pub`, a `flutter build web --no-pub --no-wasm-dry-run` és a `flutter build windows --no-pub`. Ez fordítás és widgetteszt; élő feedet megnyitó, interaktív webes vagy Windows felhasználói próbát nem végeztünk.

A böngésző CORS miatt több nyilvános feedet nem tud közvetlenül letölteni. Az app ezt A2UI hibaállapotként jelzi. Stabil publikus webdemóhoz CORS-t engedő feed vagy saját, azonos eredetű feed gateway kell. A kulcsszavas alkalmi csoportosítás egyszerű heurisztika: nem jelent tartalmi megértést. A jelenlegi módosítások nincsenek commitolva; a példa projekt munkafájljait meg kell őrizni.

## Következő egyeztetés

A következő fejlesztés előtt a felhasználóval az AI szerepét kell rögzíteni. A már tisztázott Flutter keret / A2UI hírfolyam határt és a Touch kihagyását tartsuk meg, hacsak a felhasználó másként nem kéri.
