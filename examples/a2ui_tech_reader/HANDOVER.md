# Handover: A2UI Tech Reader + GenUI Touch

Állapot: 2026-11-13. A használati útmutató a [README.md](README.md), a feltárt dokumentációs és környezeti hibák az [INTEGRATION_NOTES.md](INTEGRATION_NOTES.md) fájlban vannak.

## Mai átadás: demó felület

- A `Touch demo` panel az oldal tetején nyitva indul. Benne van a **User** és az **Occasion** választó, a **Touch**, a **Debug**, valamint Tenant editor esetén a **Save occasion** gomb. A User menü mind a négy személy nevét és angol leírását mutatja; a kiválasztott személy leírása a mezők alatt is látszik.
- A **Live RSS stories · rendered by A2UI** felirat az AppBar címe. A külön Settings művelettel párbeszédablakban érhető el az RSS preset, a politikai szűrő, az egyéni RSS/Atom URL és a Load gomb. A keresés, a külön Flutter főcím és a feed fölötti vezérlősor megszűnt.
- A Touch demo panel belső felső térköze 16 px, hogy a **User** és az **Occasion** mezők lebegő felirata ne vágódjon le. Ez a legutóbbi, még commitolatlan kódmódosítás.
- A mai commitok: `15d49b6` (Touch színválasztó és típus alapértékek), `731ed02` (User választó és Studio finomítások), `48b1d1f` (occasion konfiguráció és felhasználófüggő mentés). A jelenlegi munkafában a panel térközének javítása és ez a handover-frissítés maradt.

## Új konfigurációs mentés

- Az occasion választó a remote konfigurációt azonosítja; `auto` esetén a feloldott occasion rekordja töltődik be. A Tenant editor ezt szerkeszti. Joe, Fred és Emily külön local profilt kapnak; a local megjelenés a remote után érvényesül.
- A remote rekordban a Touch profil mellett az occasion neve, a Flutter shell stílusa, az A2UI paletta, a csoportosítás és feliratok kompozíciója, valamint Ask AI esetén a generált elrendezés és prompt is mentődik. A `Save occasion` a teljes rekordot menti akkor is, ha a Touch mezők nem változtak.
- A csomag `TouchConfigurationStore` és `TouchLocalConfigurationStore` API-kat ad, alapértelmezett helyi tárolókkal. Az egyprofilos `TouchStorage` kompatibilitási út megmaradt. A régi reader profil az Everyday remote rekord kiinduló profilja, amíg nincs új formátumú mentés.
- User vagy occasion váltáskor a reader a nem mentett Touch változások mentését, eldobását vagy a váltás megszakítását kínálja.
- A nyitva induló Touch demo panel három local mintarekordot hoz létre az első használatkor: Joe fehér oldalhátteret, nagyobb szöveget, erős kontrasztot és egysávos hírfolyamot kap; Emily rózsaszín oldalhátteret és komponenseket; Fred felülírás nélkül az occasion remote megjelenését látja. Régebbi mintarekordok egyszer kapják meg az új oldalhátteret; a korábbi szerkesztéseik megmaradnak.

## Feladathatár és jelenlegi működés

- A Flutter kezeli az alkalmazás keretét: RSS-forrás, keresés, alkalomválasztás, szűrés, navigáció és JSON-nézet. Az A2UI 1.0 hírfolyamot (`NewsSection`, `NewsStory`, `NewsGrid`, illetve a betöltési, üres és hibaállapotok) a hivatalos `MessageProcessor` és `A2uiSurface` jeleníti meg.
- Az `RssService` RSS/Atom híreket olvas. A `NewsA2uiBuilder.build` a választott alkalom és a szűrt cikkek alapján állítja össze az A2UI üzeneteket. A cikkek címe, sorrendje, linkje és tartalma Touch-sal nem szerkeszthető.
- Az **Ask AI** be van kötve. Gemini API-kulccsal a felhasználó prompt alapján megjelenést kérhet; kulcs nélkül a funkció le van tiltva. A modell a megjelenést választja, nem írja át a híreket. A kulcs és a webes használat korlátait a README írja le.
- A **Hide politics & war** kapcsoló alapból aktív. A címek és kategóriák alapján heurisztikusan szűr.

## Touch integráció

- A reader egy `GenUiTouchController` példányt és egy tartós `MessageProcessor` példányt tart fenn. Az első felület létrehozása előtt betölti a remote és local konfigurációt; minden új A2UI üzenet a `processAgentMessages` útvonalon érkezik. Frissítéskor csak a felület törlődik és épül újra.
- A `newsGalleryCatalog` dekorált, így az app sávjának Touch gombja mellett az asztali **triplaklikk** és az érintéses **hosszan nyomás** is megnyitja a Studiot. A megérintett komponens típusa lesz kiválasztva. A Story Gridbe ágyazva is helyesen működik.
- A Studio `galleryOnly` módban nyílik. A **NewsPage** az oldal teljes háttérszínét, a **NewsSection, NewsStory és NewsGrid** a komponensek megjelenését szerkeszti. Nincs külön kártyánkénti szerkesztés vagy kijelölési keret. Egy módosítás rögtön megjelenik, és a későbbi felületfrissítésekre is érvényes.
- A színekhez saját, 16 színű választó van. A mező megmutatja a tényleges színt; a palettán kívüli korábban mentett szín is látható, de új választás csak a palettáról történik.
- A módosított mező melletti reset ikon, a színválasztó **Use original** gombja és a **Restore original [type] appearance** törli a megfelelő típus alapérték-felülírását. Így az aktuális alkalom vagy AI-elrendezés által generált érték tér vissza. A **Discard unsaved defaults** más művelet: a legutóbb mentett profilt állítja vissza.
- A **Save profile** a jelenleg szerkesztett remote vagy local réteg típusalapértékeit menti `shared_preferences` tárolóba. Régi profilok típusalapértékei megmaradnak; régi, egyedi elemekhez kötött role override-ok betöltéskor kimaradnak.

## Fontos fájlok

- `lib/main.dart`: host életciklus, Touch-bekötés, felület újraépítése, Ask AI és cikkakciók.
- `lib/news_touch.dart`: Touch szerződések és `ReaderTouchStorage`.
- `lib/news_gallery.dart`, `lib/a2ui_builder.dart`: A2UI komponensek és az alkalmi kompozíciók.
- `../../lib/src/touch.dart`: típuspreferenciák, egy mező vagy teljes típus felülírásának törlése, triplaklikk.
- `../../lib/src/studio.dart`, `../../lib/src/color_field.dart`: típusszintű szerkesztő, visszaállító gombok és színválasztó.
- `test/news_touch_test.dart`: triplaklikk, típusalapértékek, occasion mentés, visszaállítás és régi profil ellenőrzése.
- `../../skills/genui-customizer-integration/SKILL.md`: általános Touch integrációs lépések.

## Ellenőrzés

- A projekt `.fvm/flutter_sdk` SDK-jával a csomag és a reader `flutter analyze --no-pub` ellenőrzése a korábbi teljes futásban hibamentes volt. A legutóbbi paneltérköz-módosítás után célzott `dart analyze lib/main.dart` futott, hibamentesen.
- A csomag tesztjei és a reader teljes tesztkészlete a korábbi futásban sikeresek voltak (reader: 36 teszt). A legutóbbi UI igazítás után nem futott új teljes tesztkészlet.
- A reader Windows Release buildje a korábbi visszaállítási módosítás után sikeres volt. A web build a triplaklikk visszaállítása után sikeres volt; a legutóbbi panelmódosítás után külön build nem futott.
- A felhasználó Windows képernyőképeken jelezte a panel elhelyezését és a levágott mezőfeliratokat. Az utolsó térközjavításról még nincs új képernyőkép. Böngészőben a publikus feedek CORS-szabályai befolyásolják a működést. A web build korábban nem blokkoló CupertinoIcons font figyelmeztetést adott.

## Nyitott korlátok és folytatás

- A rekordok helyiek; a demó user választói nem valódi fiókok, és nincs szinkron.
- A `hasUnsavedProfileChanges` jelenleg profilobjektum-azonosságot vizsgál. Ha egy felülírást kézzel pontosan a mentett értékre állítanak vissza, a Mentés gomb akkor is aktív maradhat. A mentés tartalma ettől helyes, de a dirty jelzés pontosítható mély összehasonlítással.
- A panel belső térközének utolsó javítása és ez a handover-frissítés még nincs commitolva.
