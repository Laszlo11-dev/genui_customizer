# Handover: A2UI Tech Reader + GenUI Touch

Állapot: 2026-11-13. Ez az aktuális átadás; a korábbi, Touch és Ask AI előtti handover elavult volt. A használati útmutató a [README.md](README.md), a feltárt dokumentációs és környezeti hibák az [INTEGRATION_NOTES.md](INTEGRATION_NOTES.md) fájlban vannak.

## Feladathatár és jelenlegi működés

- A Flutter kezeli az alkalmazás keretét: RSS-forrás, keresés, alkalomválasztás, szűrés, navigáció és JSON-nézet. Az A2UI 1.0 hírfolyamot (`NewsSection`, `NewsStory`, `NewsGrid`, illetve a betöltési, üres és hibaállapotok) a hivatalos `MessageProcessor` és `A2uiSurface` jeleníti meg.
- Az `RssService` RSS/Atom híreket olvas. A `NewsA2uiBuilder.build` a választott alkalom és a szűrt cikkek alapján állítja össze az A2UI üzeneteket. A cikkek címe, sorrendje, linkje és tartalma Touch-sal nem szerkeszthető.
- Az **Ask AI** be van kötve. Gemini API-kulccsal a felhasználó prompt alapján megjelenést kérhet; kulcs nélkül a funkció le van tiltva. A modell a megjelenést választja, nem írja át a híreket. A kulcs és a webes használat korlátait a README írja le.
- A **Hide politics & war** kapcsoló alapból aktív. A címek és kategóriák alapján heurisztikusan szűr.

## Touch integráció

- A reader egy `GenUiTouchController` példányt és egy tartós `MessageProcessor` példányt tart fenn. Az első felület létrehozása előtt betölti a profilt; minden új A2UI üzenet a `processAgentMessages` útvonalon érkezik. Frissítéskor csak a felület törlődik és épül újra.
- A `newsGalleryCatalog` dekorált, így az app sávjának Touch gombja mellett az asztali **triplaklikk** és az érintéses **hosszan nyomás** is megnyitja a Studiot. A megérintett komponens típusa lesz kiválasztva. A Story Gridbe ágyazva is helyesen működik.
- A Studio `galleryOnly` módban nyílik. Csak a **NewsSection, NewsStory és NewsGrid típust** szerkeszti, nincs külön kártyánkénti szerkesztés vagy kijelölési keret. Egy módosítás az aktuális felület minden azonos típusú elemén rögtön megjelenik, és a későbbi felületfrissítésekre is érvényes.
- A színekhez saját, 16 színű választó van. A mező megmutatja a tényleges színt; a palettán kívüli korábban mentett szín is látható, de új választás csak a palettáról történik.
- A módosított mező melletti reset ikon, a színválasztó **Use original** gombja és a **Restore original [type] appearance** törli a megfelelő típus alapérték-felülírását. Így az aktuális alkalom vagy AI-elrendezés által generált érték tér vissza. A **Discard unsaved defaults** más művelet: a legutóbb mentett profilt állítja vissza.
- A **Save profile** a típusalapértékeket és a visszaállításokat `shared_preferences` tárolóba menti, helyben, ezen az alkalmazástelepítésen. Régi profilok típusalapértékei megmaradnak; régi, egyedi elemekhez kötött role override-ok betöltéskor kimaradnak.

## Fontos fájlok

- `lib/main.dart`: host életciklus, Touch-bekötés, felület újraépítése, Ask AI és cikkakciók.
- `lib/news_touch.dart`: Touch szerződések és `ReaderTouchStorage`.
- `lib/news_gallery.dart`, `lib/a2ui_builder.dart`: A2UI komponensek és az alkalmi kompozíciók.
- `../../lib/src/touch.dart`: típuspreferenciák, egy mező vagy teljes típus felülírásának törlése, triplaklikk.
- `../../lib/src/studio.dart`, `../../lib/src/color_field.dart`: típusszintű szerkesztő, visszaállító gombok és színválasztó.
- `test/news_touch_test.dart`: triplaklikk, típusalapértékek, mentés, visszaállítás és régi profil ellenőrzése.
- `../../skills/genui-customizer-integration/SKILL.md`: általános Touch integrációs lépések.

## Ellenőrzés

- A projekt `.fvm/flutter_sdk` SDK-jával a csomag és a reader `flutter analyze --no-pub` ellenőrzése hibamentes.
- A csomag tesztjei és a reader teljes tesztkészlete sikeresek (reader: 29 teszt).
- A reader Windows Release buildje a legutóbbi visszaállítási módosítás után sikeres. A web build a triplaklikk visszaállítása után sikeres volt; a legutóbbi reset módosítás után külön web build nem futott.
- Élő RSS-forrással végzett interaktív Windows vagy böngészős próbát nem végeztünk. Böngészőben a publikus feedek CORS-szabályai befolyásolják a működést. A web build korábban nem blokkoló CupertinoIcons font figyelmeztetést adott.

## Nyitott korlátok és folytatás

- A profil helyi, nincs felhasználói fiókhoz kötés vagy szinkron.
- A `hasUnsavedProfileChanges` jelenleg profilobjektum-azonosságot vizsgál. Ha egy felülírást kézzel pontosan a mentett értékre állítanak vissza, a Mentés gomb akkor is aktív maradhat. A mentés tartalma ettől helyes, de a dirty jelzés pontosítható mély összehasonlítással.
- A jelenlegi változtatások nincsenek commitolva; a munkafájlokat és a korábbi módosításokat meg kell őrizni.
