# Baumkataster Rallye-Map: Markierung und Hervorhebung von Rallye-Bäumen

## Ziel

Alle Bäume, die Teil einer Rallye sind, sollen auf der Karte besonders hervorgehoben werden. Die Markierung soll deutlich größer und farblich auffällig sein, damit Rallye-Teilnehmer ihre Ziele sofort erkennen.

---

## Technische Umsetzung (iOS, Swift, MapKit)

### 1. Datenfluss & Architektur

- **RallyPlayView**: Enthält die Logik und UI für die laufende Rallye. Hier werden die Ziel-Bäume (z.B. als `Set<String>` mit Baum-IDs) bestimmt.
- **TreeMapView**: Die Haupt-Kartenansicht. Sie erhält eine Liste aller Bäume und zusätzlich eine Liste/Set der Rallye-Baum-IDs, die hervorgehoben werden sollen.
- **TreeMapViewWrapper**: Das UIKit-Bridge-Objekt, das die MapKit-Logik kapselt. Es erhält die Bäume, Cluster und das Set der hervorgehobenen IDs.
- **TreeMarkerAnnotationView**: Die Annotation-View für einzelne Bäume. Hier wird geprüft, ob ein Baum hervorgehoben werden soll und das Aussehen entsprechend angepasst.

### 2. Property-Flow

- **RallyPlayView**
  - Ermittelt die Ziel-Baum-IDs der aktuellen Rallye (z.B. `let rallyTreeIDs: Set<String>`)
  - Übergibt diese an `TreeMapView(highlightedTreeIDs: rallyTreeIDs)`

- **TreeMapView**
  - Nimmt das Set `highlightedTreeIDs` entgegen und gibt es an `TreeMapViewWrapper` weiter

- **TreeMapViewWrapper**
  - Reicht das Set an die Annotation-Views weiter (z.B. via Referenz oder als Property)

- **TreeMarkerAnnotationView**
  - Prüft in `configure()`, ob der aktuelle Baum in `highlightedTreeIDs` enthalten ist
  - Wenn ja: Marker wird größer, gelb, mit Stern und ggf. zusätzlichem Rand
  - Wenn nein: Standard-Marker (kleiner, grün, normales Icon)

### 3. Beispiel-Code (Ausschnitt)

```swift
// In RallyPlayView:
TreeMapView(
    highlightedTreeIDs: Set(rally.trees.map { $0.id })
)

// In TreeMapView:
struct TreeMapView: View {
    ...
    @State private var highlightedTreeIDs: Set<String> = []
    ...
    TreeMapViewWrapper(
        trees: appState.trees,
        clusters: clusters,
        highlightedTreeIDs: highlightedTreeIDs,
        ...
    )
}

// In TreeMapViewWrapper:
struct TreeMapViewWrapper: UIViewRepresentable {
    ...
    var highlightedTreeIDs: Set<String>
    ...
}

// In TreeMarkerAnnotationView:
override func configure() {
    guard let treeAnnotation = annotation as? TreeAnnotation else { return }
    let tree = treeAnnotation.tree
    if let wrapper = superview?.superview as? TreeMapViewWrapper, wrapper.highlightedTreeIDs.contains(tree.id) {
        markerTintColor = .systemYellow
        glyphImage = UIImage(systemName: "star.fill")
        displayPriority = .required
        layer.borderWidth = 3
        layer.borderColor = UIColor.systemBlue.cgColor
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
    } else {
        markerTintColor = colorForSpecies(tree.speciesColor)
        glyphImage = UIImage(systemName: tree.speciesIcon)
        displayPriority = .defaultLow
        layer.borderWidth = 0
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
    }
}
```

### 4. Hinweise & Best Practices

- **Performance:** Das Set der hervorgehobenen IDs sollte nicht zu groß sein (max. 100-200 IDs empfohlen), da sonst die Marker-Logik langsam werden kann.
- **UI/UX:** Die Hervorhebung sollte klar, aber nicht störend sein. Große Marker, gelbe Farbe und ein Stern-Icon sind bewährt.
- **Fallback:** Wenn keine Rallye läuft, ist das Set leer und alle Marker werden normal angezeigt.
- **Testen:** Unbedingt auf echten Geräten testen, da MapKit-Rendering auf Simulator und Device unterschiedlich sein kann.

---

## Erweiterungsideen

- **Animation:** Marker könnten beim Erreichen eines Rallye-Baums animiert werden (z.B. Pulsieren).
- **Cluster-Highlighting:** Wenn mehrere Rallye-Bäume nahe beieinander liegen, könnte ein spezieller Cluster-Marker verwendet werden.
- **Accessibility:** Für Farbenblinde sollte der Unterschied auch durch Form oder Icon erkennbar sein.

---

## Fazit

Mit dieser Architektur werden Rallye-Bäume auf der Karte klar und auffällig hervorgehoben. Die Lösung ist performant, flexibel und lässt sich einfach auf andere MapKit-Projekte übertragen.
