# Handover: A2UI Tech Reader + GenUI Touch

Állapotfelmérés: **2026-11-16**. A használati útmutató a [README.md](README.md), a kiadás menete a [release guide](../doc/RELEASING.md), a változáslista a [CHANGELOG.md](../CHANGELOG.md). Ez a fájl karbantartói átadás; nem kiadási jegyzet és nem kerül a pub.dev archívumba.

## Jelenlegi felépítés

- A fő minta az `example/` alatti RSS/Atom reader. A chat minta az `examples/a2ui_flutter_chat/` alatt található. Mindkettő része a publikálandó csomagnak.
- `lib/main.dart` csak a kulcs feloldását és az alkalmazás indítását végzi. A host életciklusa, a konfigurációváltás, az Ask AI és a cikkakciók a `lib/reader_app.dart` fájlban vannak.
- A Flutter kezeli a keretet, a Settings ablakot, a Remote és Local választókat, a szűrést, a navigációt és a JSON-nézetet. Nincs külön keresőmező.
- A híroldalt a hivatalos A2UI 1.0 renderer jeleníti meg: `NewsPage`, `NewsSection`, `NewsStory`, `NewsGrid`, valamint a betöltési, üres és hibaállapotok. Egy tartós `MessageProcessor` és egy hozzákapcsolt `GenUiTouchController` működik; újrageneráláskor a felület cserélődik.
- A Debug ablak a builder üzeneteit mutatja, a Touch megjelenési rétegeinek alkalmazása előtt.

## Demó és tárolás

- A nyitva induló Touch demo panelen a Remote választó az occasiont, a Local választó a demó szereplőt jelöli. Tenant editor, Joe, Fred és Emily nem valódi fiókok. Minden rekord a jelenlegi telepítésen vagy böngésző-origin alatt tárolódik.
- A remote occasion rekord a profilt és a teljes hostadatot tartalmazza: shell stílus, paletta, kompozíció, opcionális AI-layout és prompt. A Save occasion a teljes rekordot menti. A Save profile az éppen szerkesztett réteget menti.
- A local profil a remote után érvényesül. Joe nagyobb, kontrasztos szöveget és egyoszlopos feedet kap; Emily rózsaszín megjelenést és 12 árnyalatú saját színpalettát; Fred nem írja felül a kapott occasiont. A kezdeti rekordok egyszer jönnek létre, a későbbi mentéseket nem állítja vissza az indulás.
- A Gallery-only Studio típusalapértékeket szerkeszt. Megnyitható Touch gombbal, tripla kattintással vagy hosszú nyomással. A NewsPage az egész oldal hátterét állítja. Az eredeti érték visszaállítása a generált értéket engedi látszani; a Discard a legutóbb mentett profilt tölti vissza.
- A régi reader profil típusalapértékei az Everyday kezdeti profiljaként megmaradnak; az elemekhez kötött régi role szabályok kimaradnak. Ez különbözik a megszűnt 0.1.x csomag API-jának migrációjától.

## Feed, tour és AI

- A Settings forrásválasztójában a Demo feed beépített RSS-pillanatképet tölt be. A forráslinkek és a kiadói képek hálózatot használnak. A pillanatkép nem frissül automatikusan.
- Az 1-min demo öt jelenetben mutatja az Everyday, Christmas és Winter Games megjelenést, Joe és Emily profilját, majd egy ideiglenes gombszín-szerkesztést. A narráció szövegként jelenik meg; nincs beépített hang. Bezáráskor az előző kontextus visszaáll, a szkriptelt módosítás nem mentődik.
- A Hide politics & war heurisztikus szűrő alapból aktív. A reader legfeljebb 24 szűrt cikket mutat. A hálózati letöltési korlát 15 másodperc és 2 MiB; weben a méretellenőrzés a böngészős pufferelés után történik.
- Az Ask AI külön HTTP klienssel megjelenési értékeket kér Geminitől, nem a chat kliensét használja. Új generáláshoz kulcs kell; egy mentett AI-occasion kulcs nélkül is betölthető. A kódban rögzített modellek és a retry/timeout működés a README-ben szerepelnek.
- A publikus Pages build nem tartalmaz Gemini-kulcsot. A CORS, a kiadói képek és az élő AI szolgáltatás elérhetősége külső feltétel.

## Ellenőrzés és kiadás

A friss ellenőrzési eredményeket és a kiadás előtti teendőket a [release guide](../doc/RELEASING.md) rögzíti. A korábbi, 36 tesztre és még nem commitolt paneltérközre vonatkozó megjegyzések történetiek voltak, nem a jelenlegi állapotot írták le.

A teljes reader teszt során előkerült a Touch nyers kattintási eseményeinek beágyazási hibája: a szülő komponens megszakította a belső komponens tripla kattintásszámlálását. Egy pointereseményt most a legbelső dekorált komponens kezel; a gombakciók továbbra is működnek.

Ismert korlát: a `hasUnsavedProfileChanges` objektumazonosságot vizsgál. Egy érték kézi visszaállítása a mentett értékre továbbra is aktívan hagyhatja a mentés jelzését. A tárolási és más aszinkron műveletek állapotváltásait tesztek ellenőrzik.
