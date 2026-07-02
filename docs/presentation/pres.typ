#import "@preview/polylux:0.4.0": *

#let accent = rgb("#16a34a")
#let bg-color = rgb("#ffffff")
#let text-color = rgb("#111827")
#let muted = rgb("#4b5563")

#set page(
  paper: "presentation-16-9",
  background: rect(fill: bg-color, width: 100%, height: 100%),
  margin: (top: 1.6cm, bottom: 1.2cm, left: 2cm, right: 2cm),
)

#set text(size: 20pt, font: "New Computer Modern", fill: text-color)

#show heading.where(level: 1): it => {
  set text(size: 13pt, weight: "regular", fill: muted, tracking: 1.5pt)
  upper(it.body)
}

#show heading.where(level: 2): it => {
  set text(size: 22pt, weight: "bold", fill: accent)
  block[
    #it.body
  ]
}

#show list.item: it => {
  set text(size: 18pt, fill: text-color)
  it
}

#slide[
  #align(center + horizon)[
    #block(width: 80%)[
      #text(size: 28pt, weight: "bold", fill: accent)[
        Mikroszolgáltatások dinamikus kompozíciója az edge-cloud kontinuumban
      ]
    ]
    #v(10%)
    #grid(
      columns: (auto, auto),
      column-gutter: 1.0cm,
      row-gutter: 0.4cm,
      align: (left, left),
      text(fill: muted)[Készítette:], text(weight: "bold")[Morvai Barnabás],
      text(fill: muted)[Neptun-kód:], text(weight: "bold")[E0HB0N],
      text(fill: muted)[Konzulens:], text(weight: "bold")[Czentye János],
    )
  ]
]

#slide[
  = Témakidolgozás
  == Többen dolgoztunk ezen a témán
  #v(6%)

  - Kubernetes
  - Fordított programzási nyelvű kompozíció
  - Bash alapú kompozíció
  - Python, Lambda és Terraform...
]

#slide[
  = Felhő költségek
  == A serverless alkalmazás futási költsége a lefoglalt memória és végrehajtási idő szorzata, a kommunikáció külön overhead
  #v(6%)

  - Milliszekundum pontosságú számlázás
  - Minden függvényhívás önálló számlázási egység
  - Külső tárolórétegen átmenő adatáramlás extra késleltetést jelent
  - Cold start inicializációs idő minden hívásnál
]

#slide[
  = Problémafelvetés
  == Az alkalmazás függvényeit külön Lambda egységekbe szervezni pazarló
  #v(6%)

  - Minden függvényhívás önálló számlázási egység
  - Cold start overhead minden egységnél
  - Hálózati kommunikáció explicit és implicit költségei a Lamba szemszögéből
  - Explicit: Ki- és beolvasás művelet elvégzésének ideje
  - Implicit: A művelet elvégzése
  - Implicit: Köztes állapot külső tárban való tárolása
]

#slide[
  = Megoldás
  == Több önálló serverless egység egyetlen kompozit csoportba
  #v(6%)

  - Függvények közötti adatáramlás kizárólag memórián belül
  - Párhuzamos végrehajtás csökkenti a futási időt
  - Párhuzamos végrahajtás nem igényel új serverless egységet
  - Kiküszöböli a hálózati késleltetést
  - Eltérő forgalmi mintákhoz, árakhoz más csoportosítás lehet optimális
  - Dinamikus csoportosítással alkalmazkodni a változó körülményekhez
]

#slide[
  = DEFINÍCIÓ
  == Atomi függvény
  #v(6%)

  A végrehajtás legkisebb oszthatatlan és állapotmentes egysége. Egyetlen jól körülhatárolható üzleti logikát vagy adatfeldolgozási lépést valósít meg.
]

#slide[
  = DEFINÍCIÓ
  == Kompozit függvény
  #v(6%)

  Több atomi függvény költség- és teljesítményoptimalizált csoportosítása egyetlen, közösen futtatható AWS Lambda egységbe.
]

#slide[
  = Keretrendszer
  == Pipeline: az optimalizáló JSON kimenete alapján automatikusan áll elő az infrastruktúra
  #v(6%)

  - Az optimalizáló meghatározza az atomi függvények csoportosítását
  - Orkesztrátor generátor előállítja a belépési pontokat
  - Összeállítja a telepíthető Lambda függvények könyvtárait
  - Előállítja a Lambda függvényeket orkesztráló állapotgépet
  - Terraform deployolja az AWS infrastruktúrát
  - Emberi beavatkozás nélkül összeáll és települ a rendszer AWS környzetben
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-full-flow.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-optimizer-output.pdf")
  ]
]

#slide[
  = Bemeneti konfiguráció
  == Lista írja le az egyes kompozit Lambda egységeket és a bennük szereplő atomi modulokat
  #v(6%)

  - Szándékosan lapos, egyszerű struktúra
  - Minden kompozit elem egy functions listát tartalmaz
  - Végrehajtási sorrend a listaelemek sorrendjéből következik
  - Fa topológia nem explicit, a rendezés határozza meg az adatáramlást
]

#slide[
  = Helyesség
  == Az adatfolyam helyességét topologikus rendezés garantálja az irányított körmentes gráfon
  #v(6%)

  - Minden hívási gráf DAG
  - Minden DAG rendelkezik topologikus rendezéssel
  - Szinkronizációs pontnál a bemeneti adatok biztosan rendelkezésre állnak
  - Visszamenő él körmentes gráfban definíció szerint lehetetlen
  - Atomi és kompozit esetben is működik
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-optimizer-output.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-orchestrators.pdf")
  ]
]

#slide[
  = Orkesztrátor
  == Az orkesztrátor vezényli az atomi függvények hívását, párhuzamosítását és állapotkezelését a kompozit függvényen belül
  #v(6%)

  - Minden atomi függvény standard, rögzített interfésszel rendelkezik
  - Interfész: bemeneti adat + context példány
  - Konfigurációvezérelt, modulok konkrét implementációjától független
  - Az orkesztrátor generátor ebből állítja elő a python belépési pontot
  - Tartalmazza a feldolgozandó adat beolvasását
  - Atomi függvények párhuzamos hívását
  - Kimenetek külső tárolóba írását
]

#slide[
  = Context osztály
  == A kompozit egységen belüli adatáramlás központi eleme, amely az atomi függvények között közvetíti a köztes eredményeket
  #v(6%)

  - Az atomi függvények bemenetként kapott példámyba regisztrálják a kimeneteiket
  - defaultdict(list) struktúra, kulcsai string típuscímkék
  - Természetesen kezeli a több kimenetű eseteket
  - Minden híváshoz egyedi futási azonosítóhoz kötött példány
  - Destruktív olvasás: a lekérdezés eltávolítja az adatot
]

#slide[
  #align(center + horizon)[
    #image("figures/composite/composite-read-cache.pdf", height: 125%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/composite/composite-register-root.pdf", height: 125%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/composite/composite-call-atomic.pdf", height: 125%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/composite/composite-register-output.pdf", height: 125%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/composite/composite-write-outputs.pdf", height: 125%)
  ]
]

#slide[
  = Állapotkezelés
  == Kompozit határon az adatok S3 bucket-en keresztül, pickle szerializációval kerülnek átadásra
  #v(6%)

  - Kiíró függvény: a context maradék kimenetei bináris formátumban S3-ba mentve
  - Elérési út: stepfunctions-cache/\<futási azonosító>/\<típuskulcs>/
  - Beolvasó függvény: bináris tartalom visszaalakulása, beregisztrálás context-be
  - Az atomi függvények szempontjából nincs különbség memória és S3 forrás között
]



#slide[
  = Párhuzamosítás
  == Atomi függvények külön szálon, kompozit függvények Step Functions Distributed Map segítségével külön Lambda példányban
  #v(6%)

  - parallel segédfüggvény: egy típuskulcs összes elemét külön szálban dolgozza fel
  - Lambda-ból Lambda hívása nem ajánlott
  - Step Functions natívan kezeli az állapotátmeneteket
  - Distributed Map: S3 könyvtár alapján dinamikusan indítja a párhuzamos Lambda példányokat
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-read.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-root.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-atomic-1.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-atomic-2.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-atomic-3.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-time.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/multithreading/multithreading-write.pdf", height: 70%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/paralell/multi-lambda.pdf", height: 80%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-orchestrators.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-state-machine.pdf")
  ]
]

#slide[
  = Step Functions
  == Az ASL állapotgép definíció automatikusan generálódik, a gyökér Task, a többi Distributed Map
  #v(6%)

  - Az első kompozit egyetlen Task állapot
  - A gyökér Lambda mindig egy példányban fut
  - A többi kompozit Distributed Map: S3 könyvtárból olvassa az azonosítókat
  - ASL definíció is az optimalizáló kimenetéből generálódik
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-state-machine.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-terraform-engine.pdf")
  ]
]

#slide[
  = Terraform deployment
  == A teljes AWS infrastruktúra automatikusan deployolható: Lambda függvények, S3 bucket, Step Functions állapotgép
  #v(6%)

  - Lambda forráskód feltöltése
  - Tartalmazza az atomi függvények forráskódját és a generált orkesztrátort
  - S3 bucket létrehozása cache-nek
  - Generált ASL fájl feltöltése állapotgépként
  - Bash script orkesztrálja a teljes pipeline-t a bemenettől a futásra kész alkalmazásig
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-terraform-engine.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/pipeline/pipeline-full-flow.pdf")
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/test/test.pdf", height: 90%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/test/test-expanded.pdf", height: 125%)
  ]
]

#slide[
  #align(center + horizon)[
    #image("figures/test/test-dynamic.pdf", height: 125%)
  ]
]

#slide[
  = Eredmények
  == Kevesebb, mint 20%-ra esett vissza a végrehajtás ideje
  #v(6%)

  - Minden atomi függvény külön Lambda egységbe: 16,07s
  - Két kompozit Lambda függvénybe csoportosítás: 2,93s
  - Drága állapotkezelés
]

#slide[
  = Kitekintés
  == Fejlesztési lehetőségek
  #v(6%)

  - S3 helyett gyorsabb cache (Redis)
  - Az állapotgép és függvények monitorozása
  - Az így kinyert adatok az optimalizálóba táplálása
  - Teljesen önálló, magát optimalizáló alkalmazás
]
