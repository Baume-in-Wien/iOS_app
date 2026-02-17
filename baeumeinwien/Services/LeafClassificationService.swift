import Foundation
import UIKit
import CoreML
import Vision

struct LeafClassificationResult: Identifiable {
    let id = UUID()
    let speciesGerman: String
    let speciesLatin: String
    let confidence: Double
    let label: String

    var confidencePercent: Int {
        Int(confidence * 100)
    }

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.7...: return .high
        case 0.4...: return .medium
        default: return .low
        }
    }

    enum ConfidenceLevel {
        case high, medium, low

        var description: String {
            switch self {
            case .high: return "Hohe Sicherheit"
            case .medium: return "Mittlere Sicherheit"
            case .low: return "Niedrige Sicherheit"
            }
        }

        var icon: String {
            switch self {
            case .high: return "checkmark.seal.fill"
            case .medium: return "questionmark.circle.fill"
            case .low: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "orange"
            case .low: return "red"
            }
        }
    }
}

@Observable
final class LeafClassificationService {
    static let shared = LeafClassificationService()

    var isClassifying = false
    var lastResults: [LeafClassificationResult] = []
    var lastImage: UIImage?
    var errorMessage: String?

    private var classificationRequest: VNCoreMLRequest?
    private var isModelLoaded = false

    private let speciesMapping: [String: (german: String, latin: String)] = [
        "Ahorn (Acer spec.)": ("Ahorn", "Acer spec."),
        "Ahorn 'Norwegian Sunset' (Acer truncatum 'Norwegian Sunset')": ("Ahorn 'Norwegian Sunset'", "Acer truncatum 'Norwegian Sunset'"),
        "Ahornblättrige Platane (Platanus x acerifolia)": ("Ahornblättrige Platane", "Platanus x acerifolia"),
        "Amberbaum (Liquidambar styraciflua)": ("Amberbaum", "Liquidambar styraciflua"),
        "Amerik. Felsenahorn (Acer glabrum)": ("Amerik. Felsenahorn", "Acer glabrum"),
        "Amerikanische Zitterpappel (Populus tremuloides)": ("Amerikanische Zitterpappel", "Populus tremuloides"),
        "Amur-Korkbaum (Phellodendron amurense)": ("Amur-Korkbaum", "Phellodendron amurense"),
        "Amur-Traubenkirsche (Prunus maackii)": ("Amur-Traubenkirsche", "Prunus maackii"),
        "Andentanne (Araucaria araucana)": ("Andentanne", "Araucaria araucana"),
        "Apfelbaum (Malus spec.)": ("Apfelbaum", "Malus spec."),
        "Arizonazypresse (Cupressus arizonica 'Fastigiata')": ("Arizonazypresse", "Cupressus arizonica 'Fastigiata'"),
        "Atlaszeder (Cedrus atlantica)": ("Atlaszeder", "Cedrus atlantica"),
        "Balkan-Ahorn (Acer hyrcanum)": ("Balkan-Ahorn", "Acer hyrcanum"),
        "Balsam-Pappel (Populus balsamifera)": ("Balsam-Pappel", "Populus balsamifera"),
        "Baumhasel (Corylus colurna)": ("Baumhasel", "Corylus colurna"),
        "Baummagnolie (Magnolia kobus)": ("Baummagnolie", "Magnolia kobus"),
        "Baumwacholder (Juniperus virginiana)": ("Baumwacholder", "Juniperus virginiana"),
        "Bergahorn (Acer pseudoplatanus)": ("Bergahorn", "Acer pseudoplatanus"),
        "Bergahorn 'Purpurascens' (Acer pseudoplatanus 'Purpurascens')": ("Bergahorn 'Purpurascens'", "Acer pseudoplatanus 'Purpurascens'"),
        "Biegsame Kiefer (Pinus flexilis)": ("Biegsame Kiefer", "Pinus flexilis"),
        "Birke (Betula spec.)": ("Birke", "Betula spec."),
        "Birkenpappel (Populus simonii)": ("Birkenpappel", "Populus simonii"),
        "Bitternuss (Carya cordiformis)": ("Bitternuss", "Carya cordiformis"),
        "Bl.Scheinzypr. (Chamaecyparis lawsoniana 'Triomf van Boskoop')": ("Bl.Scheinzypr.", "Chamaecyparis lawsoniana 'Triomf van Boskoop'"),
        "Blasenbaum (Koelreuteria spec.)": ("Blasenbaum", "Koelreuteria spec."),
        "Blaue Arizonazypresse (Cupressus arizonica 'Glauca')": ("Blaue Arizonazypresse", "Cupressus arizonica 'Glauca'"),
        "Blaue Atlaszeder (Cedrus atlantica 'Glauca')": ("Blaue Atlaszeder", "Cedrus atlantica 'Glauca'"),
        "Blaufichte (Picea pungens 'Glauca')": ("Blaufichte", "Picea pungens 'Glauca'"),
        "Blaufichte, Silberfichte (Picea pungens 'Koster')": ("Blaufichte, Silberfichte", "Picea pungens 'Koster'"),
        "Blauglockenbaum (Paulownia tomentosa)": ("Blauglockenbaum", "Paulownia tomentosa"),
        "Blaugrüne Spanische Tanne (Abies pinsapo 'Glauca')": ("Blaugrüne Spanische Tanne", "Abies pinsapo 'Glauca'"),
        "Blumen-Esche 'Arie Peters' (Fraxinus ornus 'Arie Peters')": ("Blumen-Esche 'Arie Peters'", "Fraxinus ornus 'Arie Peters'"),
        "Blumen-Esche 'Louisa Lady' (Fraxinus ornus 'Louisa Lady')": ("Blumen-Esche 'Louisa Lady'", "Fraxinus ornus 'Louisa Lady'"),
        "Blumenesche (Fraxinus ornus)": ("Blumenesche", "Fraxinus ornus"),
        "Blut-Trompetenbaum (Catalpa erubescens 'Purpurea')": ("Blut-Trompetenbaum", "Catalpa erubescens 'Purpurea'"),
        "Blutahorn (Acer platanoides 'Crimson King')": ("Blutahorn", "Acer platanoides 'Crimson King'"),
        "Blutbirke (Betula pendula 'Purpurea')": ("Blutbirke", "Betula pendula 'Purpurea'"),
        "Blutbuche (Fagus sylvatica 'Atropurpurea')": ("Blutbuche", "Fagus sylvatica 'Atropurpurea'"),
        "Blutlederhülsenbaum (Gleditsia triacanthos 'Ruby Lace')": ("Blutlederhülsenbaum", "Gleditsia triacanthos 'Ruby Lace'"),
        "Blutpflaume (Prunus cerasifera 'Nigra')": ("Blutpflaume", "Prunus cerasifera 'Nigra'"),
        "Blutroter Fächerahorn (Acer palmatum 'Bloodgood')": ("Blutroter Fächerahorn", "Acer palmatum 'Bloodgood'"),
        "Blutroter Hartriegel (Cornus sanguinea)": ("Blutroter Hartriegel", "Cornus sanguinea"),
        "Breitkegelförmiger Bergahorn (Acer pseudoplatanus 'Rotterdam')": ("Breitkegelförmiger Bergahorn", "Acer pseudoplatanus 'Rotterdam'"),
        "Buche (Fagus spec.)": ("Buche", "Fagus spec."),
        "Buntblättrige Buche (Fagus sylvatica 'Roseomarginata')": ("Buntblättrige Buche", "Fagus sylvatica 'Roseomarginata'"),
        "Buntlaubige Rot-Buche (Fagus sylvatica 'Albomarginata')": ("Buntlaubige Rot-Buche", "Fagus sylvatica 'Albomarginata'"),
        "Carolina-Rosskastanie (Aesculus x neglecta)": ("Carolina-Rosskastanie", "Aesculus x neglecta"),
        "Chinesischer Wacholder (Juniperus chinensis)": ("Chinesischer Wacholder", "Juniperus chinensis"),
        "Cissusblättriger Ahorn (Acer cissifolium)": ("Cissusblättriger Ahorn", "Acer cissifolium"),
        "Colorado-Tanne (Abies concolor)": ("Colorado-Tanne", "Abies concolor"),
        "Davids-Ahorn (Acer davidii)": ("Davids-Ahorn", "Acer davidii"),
        "Dirndlstrauch (Cornus mas)": ("Dirndlstrauch", "Cornus mas"),
        "Dorn (Crataegus spec.)": ("Dorn", "Crataegus spec."),
        "Dornenloser Lederhülsenbaum (Gleditsia triacanthos 'Inermis')": ("Dornenloser Lederhülsenbaum", "Gleditsia triacanthos 'Inermis'"),
        "Dreilappiger Apfel (Malus trilobata)": ("Dreilappiger Apfel", "Malus trilobata"),
        "Dreizähniger Ahorn (Acer buergerianum)": ("Dreizähniger Ahorn", "Acer buergerianum"),
        "Echte Hängebirke (Betula pendula 'Youngii')": ("Echte Hängebirke", "Betula pendula 'Youngii'"),
        "Echte Mispel (Mespilus germanica)": ("Echte Mispel", "Mespilus germanica"),
        "Echte Zypresse (Cupressus sempervierens 'Pyramidalis')": ("Echte Zypresse", "Cupressus sempervierens 'Pyramidalis'"),
        "Edelkastanie (Castanea sativa)": ("Edelkastanie", "Castanea sativa"),
        "Eibisch (Hibiscus syriacus)": ("Eibisch", "Hibiscus syriacus"),
        "Eichenblättrige Blutbuche (Fagus sylvatica 'Quercifolia')": ("Eichenblättrige Blutbuche", "Fagus sylvatica 'Quercifolia'"),
        "Einblättrige Esche (Fraxinus excelsior 'Diversifolia')": ("Einblättrige Esche", "Fraxinus excelsior 'Diversifolia'"),
        "Eisenholzbaum (Parrotia persica)": ("Eisenholzbaum", "Parrotia persica"),
        "Eisenhutblättriger Japan-Ahorn (Acer japonicum 'Aconitifolium')": ("Eisenhutblättriger Japan-Ahorn", "Acer japonicum 'Aconitifolium'"),
        "Erle (Alnus spec.)": ("Erle", "Alnus spec."),
        "Esche (Fraxinus spec.)": ("Esche", "Fraxinus spec."),
        "Eschenahorn (Acer negundo)": ("Eschenahorn", "Acer negundo"),
        "Essbare Felsenbirne (Amelanchier laevis 'Ballerina')": ("Essbare Felsenbirne", "Amelanchier laevis 'Ballerina'"),
        "Europäische Lärche (Larix decidua)": ("Europäische Lärche", "Larix decidua"),
        "Fadenzypresse (Chamaecyparis pisifera)": ("Fadenzypresse", "Chamaecyparis pisifera"),
        "Feldahorn (Acer campestre)": ("Feldahorn", "Acer campestre"),
        "Feldahorn 'Royal Ruby' (Acer campestre 'Royal Ruby')": ("Feldahorn 'Royal Ruby'", "Acer campestre 'Royal Ruby'"),
        "Felsen-Walnuss (Juglans microcarpa)": ("Felsen-Walnuss", "Juglans microcarpa"),
        "Felsenbirne (Amelanchier spec.)": ("Felsenbirne", "Amelanchier spec."),
        "Feuerahorn (Acer tataricum)": ("Feuerahorn", "Acer tataricum"),
        "Fichte (Picea spec.)": ("Fichte", "Picea spec."),
        "Fiederblatt-Rotbuche (Fagus sylvatica 'Laciniata')": ("Fiederblatt-Rotbuche", "Fagus sylvatica 'Laciniata'"),
        "Flaumige Felsenbirne (Amelanchier arborea 'Robin Hill')": ("Flaumige Felsenbirne", "Amelanchier arborea 'Robin Hill'"),
        "Fontanesie (Fontanesia phillyreoides)": ("Fontanesie", "Fontanesia phillyreoides"),
        "Französischer Ahorn (Acer monspessulanum)": ("Französischer Ahorn", "Acer monspessulanum"),
        "Freemanii-Ahorn (Acer x freemanii 'Armstrong')": ("Freemanii-Ahorn", "Acer x freemanii 'Armstrong'"),
        "Fruchloser Weißer Maulbeerbaum (Morus alba 'Fruitless')": ("Fruchloser Weißer Maulbeerbaum", "Morus alba 'Fruitless'"),
        "Fudji-Kirsche (Prunus incisa 'February Pink')": ("Fudji-Kirsche", "Prunus incisa 'February Pink'"),
        "Fächerahorn (Acer palmatum)": ("Fächerahorn", "Acer palmatum"),
        "Fächerahorn 'Hessei' (Acer palmatum 'Hessei')": ("Fächerahorn 'Hessei'", "Acer palmatum 'Hessei'"),
        "Fächerblattbaum (Ginkgo biloba)": ("Fächerblattbaum", "Ginkgo biloba"),
        "Garteneibisch (Hibiscus syriacus 'White Chiffon')": ("Garteneibisch", "Hibiscus syriacus 'White Chiffon'"),
        "Gefülltblühende Kastanie (Aesculus hippocastanum 'Baumannii')": ("Gefülltblühende Kastanie", "Aesculus hippocastanum 'Baumannii'"),
        "Gefülltblühende Kirsche (Prunus avium 'Flore Plena')": ("Gefülltblühende Kirsche", "Prunus avium 'Flore Plena'"),
        "Gefülltblühende Vogelkirsche (Prunus avium 'Plena')": ("Gefülltblühende Vogelkirsche", "Prunus avium 'Plena'"),
        "Gefülltblühende Zier-Sauerkirsche (Prunus cerasus 'Rhexii')": ("Gefülltblühende Zier-Sauerkirsche", "Prunus cerasus 'Rhexii'"),
        "Geisterfichte (Picea abies 'Inversa')": ("Geisterfichte", "Picea abies 'Inversa'"),
        "Gelbbunte Buche (Fagus sylvatica 'Bicolor Sartinii')": ("Gelbbunte Buche", "Fagus sylvatica 'Bicolor Sartinii'"),
        "Gelbe Kastanie (Aesculus flava)": ("Gelbe Kastanie", "Aesculus flava"),
        "Gelbe Sternmagnolie (Magnolia 'Goldstar')": ("Gelbe Sternmagnolie", "Magnolia 'Goldstar'"),
        "Gelber Lederhülsenbaum (Gleditsia triacanthos 'Sunburst')": ("Gelber Lederhülsenbaum", "Gleditsia triacanthos 'Sunburst'"),
        "Gelber Perückenstrauch (Cotinus coggyria 'Golden Spirit')": ("Gelber Perückenstrauch", "Cotinus coggyria 'Golden Spirit'"),
        "Gelbgerandete Stechpalme (Ilex aquifolium 'Aurea Marginata')": ("Gelbgerandete Stechpalme", "Ilex aquifolium 'Aurea Marginata'"),
        "Gelbholz (Cladrastis lutea)": ("Gelbholz", "Cladrastis lutea"),
        "Gelbkiefer (Pinus ponderosa)": ("Gelbkiefer", "Pinus ponderosa"),
        "Gemeine Esche (Fraxinus excelsior)": ("Gemeine Esche", "Fraxinus excelsior"),
        "Gemeine Fichte (Picea abies)": ("Gemeine Fichte", "Picea abies"),
        "Gemeine Hasel (Corylus avellana)": ("Gemeine Hasel", "Corylus avellana"),
        "Gemeine Kiefer (Pinus sylvestris)": ("Gemeine Kiefer", "Pinus sylvestris"),
        "Gemeiner Goldregen (Laburnum anagyroides)": ("Gemeiner Goldregen", "Laburnum anagyroides"),
        "Geschlitztblättrige Buche (Fagus sylvatica 'Asplenifolia')": ("Geschlitztblättrige Buche", "Fagus sylvatica 'Asplenifolia'"),
        "Geschlitztblättrige Schwarzerle (Alnus glutinosa 'Imperialis')": ("Geschlitztblättrige Schwarzerle", "Alnus glutinosa 'Imperialis'"),
        "Geschlitzter Silber-Ahorn (Acer saccharinum 'Wieri')": ("Geschlitzter Silber-Ahorn", "Acer saccharinum 'Wieri'"),
        "Geschlitzter Silberahorn (Acer saccharinum 'Born's Gracious')": ("Geschlitzter Silberahorn", "Acer saccharinum 'Born's Gracious'"),
        "Geweihbaum (Gymnocladus dioicus)": ("Geweihbaum", "Gymnocladus dioicus"),
        "Gewöhnliche Felsenbirne (Amelanchier ovalis)": ("Gewöhnliche Felsenbirne", "Amelanchier ovalis"),
        "Gewöhnlicher Buchsbaum (Buxus sempervirens)": ("Gewöhnlicher Buchsbaum", "Buxus sempervirens"),
        "Gewöhnlicher Wacholder (Juniperus communis)": ("Gewöhnlicher Wacholder", "Juniperus communis"),
        "Glanzmispel (Photinia x fraseri)": ("Glanzmispel", "Photinia x fraseri"),
        "Gold-Birke (Betula ermanii)": ("Gold-Birke", "Betula ermanii"),
        "Goldregen (Laburnum spec.)": ("Goldregen", "Laburnum spec."),
        "Goldzypresse (Chamaecyparis lawsoniana 'Stewartii')": ("Goldzypresse", "Chamaecyparis lawsoniana 'Stewartii'"),
        "Grannen-Kiefer (Pinus aristata)": ("Grannen-Kiefer", "Pinus aristata"),
        "Grauerle (Alnus incana)": ("Grauerle", "Alnus incana"),
        "Graupappel (Populus x canescens)": ("Graupappel", "Populus x canescens"),
        "Griechische Tanne (Abies cephalonica)": ("Griechische Tanne", "Abies cephalonica"),
        "Grossers Ahorn (Acer davidii subsp. grosseri)": ("Grossers Ahorn", "Acer davidii subsp. grosseri"),
        "Götterbaum (Ailanthus spec.)": ("Götterbaum", "Ailanthus spec."),
        "Hafer-Pflaume (Prunus domestica subsp. insititia)": ("Hafer-Pflaume", "Prunus domestica subsp. insititia"),
        "Hahnendorn (Crataegus x lavallei)": ("Hahnendorn", "Crataegus x lavallei"),
        "Hainbuche (Carpinus spec.)": ("Hainbuche", "Carpinus spec."),
        "Haken-Kiefer (Pinus uncinata)": ("Haken-Kiefer", "Pinus uncinata"),
        "Harlequin-Rotbuche (Fagus sylvatica 'Purpurea Tricolor')": ("Harlequin-Rotbuche", "Fagus sylvatica 'Purpurea Tricolor'"),
        "Harringtons Kopfeibe (Cephalotaxus harringtonia)": ("Harringtons Kopfeibe", "Cephalotaxus harringtonia"),
        "Hartriegel (Cornus spec.)": ("Hartriegel", "Cornus spec."),
        "Haselnuss (Corylus spec.)": ("Haselnuss", "Corylus spec."),
        "Hellroter Spitzahorn (Acer platanoides 'Deborah')": ("Hellroter Spitzahorn", "Acer platanoides 'Deborah'"),
        "Himalajazeder (Cedrus deodara)": ("Himalajazeder", "Cedrus deodara"),
        "Himalaya-Birke (Betula utilis var. utilis)": ("Himalaya-Birke", "Betula utilis var. utilis"),
        "Holzapfel (Malus sylvestris)": ("Holzapfel", "Malus sylvestris"),
        "Hopfenbuche (Ostrya carpinifolia)": ("Hopfenbuche", "Ostrya carpinifolia"),
        "Hängebaumhasel (Corylus colurna 'pendula')": ("Hängebaumhasel", "Corylus colurna 'pendula'"),
        "Hängebirke 'Laciniata' (Betula pendula 'Laciniata')": ("Hängebirke 'Laciniata'", "Betula pendula 'Laciniata'"),
        "Hängeblutbuche (Fagus sylvatica 'Purpurea Pendula')": ("Hängeblutbuche", "Fagus sylvatica 'Purpurea Pendula'"),
        "Hängeesche (Fraxinus excelsior 'Pendula')": ("Hängeesche", "Fraxinus excelsior 'Pendula'"),
        "Hängehimalajazeder (Cedrus deodara 'Pendula')": ("Hängehimalajazeder", "Cedrus deodara 'Pendula'"),
        "Hängemaulbeere (Morus alba 'Pendula')": ("Hängemaulbeere", "Morus alba 'Pendula'"),
        "Hängerotbuche (Fagus sylvatica 'Pendula')": ("Hängerotbuche", "Fagus sylvatica 'Pendula'"),
        "Hängezypresse (Chamaecyparis nootkatensis 'Pendula')": ("Hängezypresse", "Chamaecyparis nootkatensis 'Pendula'"),
        "Immergrüne Magnolie (Magnolia grandiflora)": ("Immergrüne Magnolie", "Magnolia grandiflora"),
        "Indische Rosskastanie (Aesculus indica)": ("Indische Rosskastanie", "Aesculus indica"),
        "Italienische Erle (Alnus cordata)": ("Italienische Erle", "Alnus cordata"),
        "Italienischer Ahorn (Acer opalus)": ("Italienischer Ahorn", "Acer opalus"),
        "Japanische Lärche (Larix kaempferi)": ("Japanische Lärche", "Larix kaempferi"),
        "Japanische Sicheltanne (Cryptomeria japonica)": ("Japanische Sicheltanne", "Cryptomeria japonica"),
        "Japanischer Blumen-Hartriegel (Cornus kousa)": ("Japanischer Blumen-Hartriegel", "Cornus kousa"),
        "Japanischer Kräuselahorn (Acer palmatum 'Shishigashira')": ("Japanischer Kräuselahorn", "Acer palmatum 'Shishigashira'"),
        "Japanischer Losbaum (Clerodendrum trichotomun)": ("Japanischer Losbaum", "Clerodendrum trichotomun"),
        "Japanischer Rosinenbaum (Hovenia dulcis)": ("Japanischer Rosinenbaum", "Hovenia dulcis"),
        "Judasbaum (Cercis siliquastrum)": ("Judasbaum", "Cercis siliquastrum"),
        "Kahle Felsenbirne (Amelanchier laevis)": ("Kahle Felsenbirne", "Amelanchier laevis"),
        "Kalifornische Flusszeder (Calocedrus decurrens)": ("Kalifornische Flusszeder", "Calocedrus decurrens"),
        "Kanadische Pappel (Populus x canadensis)": ("Kanadische Pappel", "Populus x canadensis"),
        "Kanadischer Judasbaum (Cercis canadensis)": ("Kanadischer Judasbaum", "Cercis canadensis"),
        "Kastanie (Aesculus spec.)": ("Kastanie", "Aesculus spec."),
        "Katsurabaum (Cercidiphyllum japonicum)": ("Katsurabaum", "Cercidiphyllum japonicum"),
        "Kaukasus-Fichte (Picea orientalis)": ("Kaukasus-Fichte", "Picea orientalis"),
        "Kegelförmiger Bergahorn (Acer pseudoplatanus 'Negenia')": ("Kegelförmiger Bergahorn", "Acer pseudoplatanus 'Negenia'"),
        "Kegelförmiger Spitzahorn (Acer platanoides 'Emerald Queen')": ("Kegelförmiger Spitzahorn", "Acer platanoides 'Emerald Queen'"),
        "Kiefer, Föhre (Pinus spec.)": ("Kiefer, Föhre", "Pinus spec."),
        "Kirschlorbeer (Prunus laurocerasus)": ("Kirschlorbeer", "Prunus laurocerasus"),
        "Kirschpflaume (Prunus cerasifera)": ("Kirschpflaume", "Prunus cerasifera"),
        "Kleinblütiger Trompetenbaum (Catalpa ovata)": ("Kleinblütiger Trompetenbaum", "Catalpa ovata"),
        "Kolchischer Ahorn (Acer cappadocicum)": ("Kolchischer Ahorn", "Acer cappadocicum"),
        "Kopfeibe (Cephalotaxus spec.)": ("Kopfeibe", "Cephalotaxus spec."),
        "Korea-Tanne (Abies koreana)": ("Korea-Tanne", "Abies koreana"),
        "Korsische Kiefer (Pinus nigra laricio)": ("Korsische Kiefer", "Pinus nigra laricio"),
        "Kugel-Fächerblattbaum (Ginkgo biloba 'Globosa')": ("Kugel-Fächerblattbaum", "Ginkgo biloba 'Globosa'"),
        "Kugelblumenesche (Fraxinus ornus 'Meczek')": ("Kugelblumenesche", "Fraxinus ornus 'Meczek'"),
        "Kugelesche (Fraxinus excelsior 'Nana')": ("Kugelesche", "Fraxinus excelsior 'Nana'"),
        "Kugelfeldahorn (Acer campestre 'Nanum')": ("Kugelfeldahorn", "Acer campestre 'Nanum'"),
        "Kugelförmiger Maulbeerbaum (Morus alba 'Globosa')": ("Kugelförmiger Maulbeerbaum", "Morus alba 'Globosa'"),
        "Kugelkirsche (Prunus fruticosa 'Globosa‘)": ("Kugelkirsche", "Prunus fruticosa 'Globosa‘"),
        "Kugelplatane (Platanus x acerifolia 'Alphens Globe')": ("Kugelplatane", "Platanus x acerifolia 'Alphens Globe'"),
        "Kugelspitzahorn (Acer platanoides 'Globosum')": ("Kugelspitzahorn", "Acer platanoides 'Globosum'"),
        "Kultur-Apfel (Malus domestica)": ("Kultur-Apfel", "Malus domestica"),
        "Kupfer-Felsenbirne (Amelanchier lamarckii)": ("Kupfer-Felsenbirne", "Amelanchier lamarckii"),
        "Küsten Tanne (Abies grandis)": ("Küsten Tanne", "Abies grandis"),
        "Lederhülsenbaum (Gleditsia triacanthos)": ("Lederhülsenbaum", "Gleditsia triacanthos"),
        "Libanonzeder (Cedrus libani)": ("Libanonzeder", "Cedrus libani"),
        "Lärche (Larix spec.)": ("Lärche", "Larix spec."),
        "Magnolie (Magnolia spec.)": ("Magnolie", "Magnolia spec."),
        "Mandelbaum (Prunus dulcis)": ("Mandelbaum", "Prunus dulcis"),
        "Marille (Prunus armeniaca)": ("Marille", "Prunus armeniaca"),
        "Maulbeerbaum (Morus spec.)": ("Maulbeerbaum", "Morus spec."),
        "Moor-Birke (Betula pubescens)": ("Moor-Birke", "Betula pubescens"),
        "Morgenländischer Lebensbaum (Platycladus orientalis)": ("Morgenländischer Lebensbaum", "Platycladus orientalis"),
        "Mostgummi-Eukalyptus (Eucalyptus gunnii)": ("Mostgummi-Eukalyptus", "Eucalyptus gunnii"),
        "Muschelzypresse (Chamaecyparis obtusa)": ("Muschelzypresse", "Chamaecyparis obtusa"),
        "Mädchen-Kiefer (Pinus parviflora)": ("Mädchen-Kiefer", "Pinus parviflora"),
        "Mädchenkiefer (Pinus parviflora 'Negishi')": ("Mädchenkiefer", "Pinus parviflora 'Negishi'"),
        "Netznerviger Zürgelbaum (Celtis reticulata)": ("Netznerviger Zürgelbaum", "Celtis reticulata"),
        "Nordmannstanne (Abies nordmanniana)": ("Nordmannstanne", "Abies nordmanniana"),
        "Nutka-Scheinzypresse (Chamaecyparis nootkatensis)": ("Nutka-Scheinzypresse", "Chamaecyparis nootkatensis"),
        "Orientalische Platane (Platanus orientalis)": ("Orientalische Platane", "Platanus orientalis"),
        "Orientalische Säulenplatane (Platanus orientalis 'Minaret')": ("Orientalische Säulenplatane", "Platanus orientalis 'Minaret'"),
        "Osagedorn (Maclura pomifera)": ("Osagedorn", "Maclura pomifera"),
        "Papierbirke (Betula papyrifera)": ("Papierbirke", "Betula papyrifera"),
        "Papiermaulbeere (Broussonetia papyrifera)": ("Papiermaulbeere", "Broussonetia papyrifera"),
        "Pappel (Populus spec.)": ("Pappel", "Populus spec."),
        "Pavie (Aesculus pavia)": ("Pavie", "Aesculus pavia"),
        "Pazifischer Ahorn (Acer truncatum 'Pacific Sunset')": ("Pazifischer Ahorn", "Acer truncatum 'Pacific Sunset'"),
        "Pekannuss (Carya illinoinensis)": ("Pekannuss", "Carya illinoinensis"),
        "Perückenstrauch (Cotinus coggygria)": ("Perückenstrauch", "Cotinus coggygria"),
        "Pfarrerkapperl (Euonymus europaeus)": ("Pfarrerkapperl", "Euonymus europaeus"),
        "Pflaume (Prunus domestica)": ("Pflaume", "Prunus domestica"),
        "Platane (Platanus spec.)": ("Platane", "Platanus spec."),
        "Pracht-Apfel (Malus spectabilis)": ("Pracht-Apfel", "Malus spectabilis"),
        "Purpur-Erle (Alnus x spaethii 'Spaeth‘)": ("Purpur-Erle", "Alnus x spaethii 'Spaeth‘"),
        "Purpur-Magnolie (Magnolia liliiflora 'Nigra')": ("Purpur-Magnolie", "Magnolia liliiflora 'Nigra'"),
        "Purpur-Magnolie 'Susan' (Magnolia liliiflora 'Susan')": ("Purpur-Magnolie 'Susan'", "Magnolia liliiflora 'Susan'"),
        "Purpurner Bergahorn (Acer pseudoplatanus 'Atropurpureum')": ("Purpurner Bergahorn", "Acer pseudoplatanus 'Atropurpureum'"),
        "Pyramidaler Silberahorn (Acer saccharinum 'Pyramidalis')": ("Pyramidaler Silberahorn", "Acer saccharinum 'Pyramidalis'"),
        "Pyramidenhainbuche (Carpinus betulus 'Columnaris')": ("Pyramidenhainbuche", "Carpinus betulus 'Columnaris'"),
        "Pyramidenkastanie (Aesculus hippocastanum 'Pyramidalis')": ("Pyramidenkastanie", "Aesculus hippocastanum 'Pyramidalis'"),
        "Pyramidenmaulbeere (Morus alba 'Pyramidalis')": ("Pyramidenmaulbeere", "Morus alba 'Pyramidalis'"),
        "Pyramidenpappel (Populus nigra 'Italica')": ("Pyramidenpappel", "Populus nigra 'Italica'"),
        "Quitte (Cydonia oblonga)": ("Quitte", "Cydonia oblonga"),
        "Raketen-Wacholder (Juniperus scopulorum 'Skyrocket')": ("Raketen-Wacholder", "Juniperus scopulorum 'Skyrocket'"),
        "Rauchzypresse (Calocedrus decurrens 'Aureovariegata')": ("Rauchzypresse", "Calocedrus decurrens 'Aureovariegata'"),
        "Riesenzypresse (Cupressocyparis leylandii)": ("Riesenzypresse", "Cupressocyparis leylandii"),
        "Rosa Sternmagnolie (Magnolia stellata 'Rosea')": ("Rosa Sternmagnolie", "Magnolia stellata 'Rosea'"),
        "Rosskastanie (Aesculus hippocastanum)": ("Rosskastanie", "Aesculus hippocastanum"),
        "Rot-Ahorn (Acer x freemanii)": ("Rot-Ahorn", "Acer x freemanii"),
        "Rot-Ahorn 'Autumn Blaze' (Acer x freemanii 'Autumn Blaze')": ("Rot-Ahorn 'Autumn Blaze'", "Acer x freemanii 'Autumn Blaze'"),
        "Rot-Ahorn 'Celzam' (Acer x freemanii 'Celzam')": ("Rot-Ahorn 'Celzam'", "Acer x freemanii 'Celzam'"),
        "Rot-Ahorn 'Marmo' (Acer x freemanii 'Marmo')": ("Rot-Ahorn 'Marmo'", "Acer x freemanii 'Marmo'"),
        "Rotahorn (Acer rubrum)": ("Rotahorn", "Acer rubrum"),
        "Rotblättrige Baumhasel (Corylus colurna 'Granat')": ("Rotblättrige Baumhasel", "Corylus colurna 'Granat'"),
        "Rotblättrige Säulenblutbuche (Fagus sylvatica 'Dawyk Purple')": ("Rotblättrige Säulenblutbuche", "Fagus sylvatica 'Dawyk Purple'"),
        "Rotblättrige Traubenkirsche (Prunus virginiana 'Shubert')": ("Rotblättrige Traubenkirsche", "Prunus virginiana 'Shubert'"),
        "Rotblättriger Judasbaum (Cercis canadensis 'Forest Pansy')": ("Rotblättriger Judasbaum", "Cercis canadensis 'Forest Pansy'"),
        "Rotblättriger Spitzahorn (Acer platanoides 'Schwedleri')": ("Rotblättriger Spitzahorn", "Acer platanoides 'Schwedleri'"),
        "Rotblühende Kastanie (Aesculus x carnea)": ("Rotblühende Kastanie", "Aesculus x carnea"),
        "Rotblühende Rosskastanie (Aesculus x carnea 'Plantierensis')": ("Rotblühende Rosskastanie", "Aesculus x carnea 'Plantierensis'"),
        "Rotbuche (Fagus sylvatica)": ("Rotbuche", "Fagus sylvatica"),
        "Rotdorn (Crataegus laevigata 'Pauls Scarlet')": ("Rotdorn", "Crataegus laevigata 'Pauls Scarlet'"),
        "Roter Fächerahorn (Acer palmatum 'Atropurpureum')": ("Roter Fächerahorn", "Acer palmatum 'Atropurpureum'"),
        "Roter Judasblattbaum (Cercidiphyllum japonicum 'Rotfuchs')": ("Roter Judasblattbaum", "Cercidiphyllum japonicum 'Rotfuchs'"),
        "Roter Kugelahorn (Acer platanoides 'Crimson Sentry')": ("Roter Kugelahorn", "Acer platanoides 'Crimson Sentry'"),
        "Roter Perückenstrauch (Cotinus coggygria 'Royal Purple')": ("Roter Perückenstrauch", "Cotinus coggygria 'Royal Purple'"),
        "Roter Schlangenhaut-Ahorn (Acer capillipes)": ("Roter Schlangenhaut-Ahorn", "Acer capillipes"),
        "Roter Spitzahorn 'Royal Red' (Acer platanoides 'Royal Red')": ("Roter Spitzahorn 'Royal Red'", "Acer platanoides 'Royal Red'"),
        "Rotesche (Fraxinus pennsylvanica)": ("Rotesche", "Fraxinus pennsylvanica"),
        "Rotfichte (Picea rubens)": ("Rotfichte", "Picea rubens"),
        "Rotlaubiger Zierapfel (Malus 'Scarlet')": ("Rotlaubiger Zierapfel", "Malus 'Scarlet'"),
        "Rumelische Kiefer (Pinus peuce)": ("Rumelische Kiefer", "Pinus peuce"),
        "Sauerkirsche (Prunus cerasus)": ("Sauerkirsche", "Prunus cerasus"),
        "Scharlachkastanie (Aesculus x carnea 'Briotii')": ("Scharlachkastanie", "Aesculus x carnea 'Briotii'"),
        "Scheinzypresse (Chamaecyparis spec.)": ("Scheinzypresse", "Chamaecyparis spec."),
        "Schirm-Ginkgo (Ginkgo biloba 'Horizontalis')": ("Schirm-Ginkgo", "Ginkgo biloba 'Horizontalis'"),
        "Schirm-Seidenakazie (Albizia julibrissin 'Ombrella')": ("Schirm-Seidenakazie", "Albizia julibrissin 'Ombrella'"),
        "Schirmgleditschie (Gleditsia triacanthos 'Shademaster')": ("Schirmgleditschie", "Gleditsia triacanthos 'Shademaster'"),
        "Schlangenhautkiefer (Pinus leucodermis)": ("Schlangenhautkiefer", "Pinus leucodermis"),
        "Schlanke Säulenhainbuche (Carpinus betulus 'Frans Fontaine')": ("Schlanke Säulenhainbuche", "Carpinus betulus 'Frans Fontaine'"),
        "Schlitzblättrige Schwarzerle (Alnus glutinosa 'Luciniata')": ("Schlitzblättrige Schwarzerle", "Alnus glutinosa 'Luciniata'"),
        "Schmalblättrige Esche (Fraxinus angustifolia)": ("Schmalblättrige Esche", "Fraxinus angustifolia"),
        "Schmalblättrige Kastanie (Aesculus hippocastanum 'Laciniata')": ("Schmalblättrige Kastanie", "Aesculus hippocastanum 'Laciniata'"),
        "Schmalkronige Platane (Platanus x acerifolia 'Tremonia')": ("Schmalkronige Platane", "Platanus x acerifolia 'Tremonia'"),
        "Schmalkroniger Bergahorn (Acer pseudoplatanus 'Erectum')": ("Schmalkroniger Bergahorn", "Acer pseudoplatanus 'Erectum'"),
        "Schottische Waldkiefer (Pinus sylvestris 'Scotica')": ("Schottische Waldkiefer", "Pinus sylvestris 'Scotica'"),
        "Schwarz-Erle 'Pyramidalis' (Alnus glutinosa 'Pyramidalis')": ("Schwarz-Erle 'Pyramidalis'", "Alnus glutinosa 'Pyramidalis'"),
        "Schwarzbirke (Betula nigra)": ("Schwarzbirke", "Betula nigra"),
        "Schwarzer Maulbeerbaum (Morus nigra)": ("Schwarzer Maulbeerbaum", "Morus nigra"),
        "Schwarzerle (Alnus glutinosa)": ("Schwarzerle", "Alnus glutinosa"),
        "Schwarzkiefer, Schwarzföhre (Pinus nigra)": ("Schwarzkiefer, Schwarzföhre", "Pinus nigra"),
        "Schwarznussbaum (Juglans nigra)": ("Schwarznussbaum", "Juglans nigra"),
        "Schwarzpappel (Populus nigra)": ("Schwarzpappel", "Populus nigra"),
        "Seidenakazie (Albizia julibrissin)": ("Seidenakazie", "Albizia julibrissin"),
        "Serbische Fichte (Picea omorika)": ("Serbische Fichte", "Picea omorika"),
        "Sieben Söhne des Himmels Strauch (Heptacodium miconioides)": ("Sieben Söhne des Himmels Strauch", "Heptacodium miconioides"),
        "Silber-Eschenahorn (Acer negundo 'Variegatum')": ("Silber-Eschenahorn", "Acer negundo 'Variegatum'"),
        "Silberahorn (Acer saccharinum)": ("Silberahorn", "Acer saccharinum"),
        "Silberpappel (Populus alba)": ("Silberpappel", "Populus alba"),
        "Silberpyramidenpappel (Populus alba 'Raket')": ("Silberpyramidenpappel", "Populus alba 'Raket'"),
        "Siskiyou-Fichte (Picea breweriana)": ("Siskiyou-Fichte", "Picea breweriana"),
        "Spanische Tanne (Abies pinsapo)": ("Spanische Tanne", "Abies pinsapo"),
        "Spitz-Ahorn (Acer platanoides 'Norwegian Sunset')": ("Spitz-Ahorn", "Acer platanoides 'Norwegian Sunset'"),
        "Spitzahorn (Acer platanoides)": ("Spitzahorn", "Acer platanoides"),
        "Stechpalme (Ilex aquifolium)": ("Stechpalme", "Ilex aquifolium"),
        "Stechpalme 'Alaska' (Ilex aquifolium 'Alaska')": ("Stechpalme 'Alaska'", "Ilex aquifolium 'Alaska'"),
        "Steinweichsel (Prunus mahaleb)": ("Steinweichsel", "Prunus mahaleb"),
        "Sternmagnolie (Magnolia stellata)": ("Sternmagnolie", "Magnolia stellata"),
        "Strauchkastanie (Aesculus parviflora)": ("Strauchkastanie", "Aesculus parviflora"),
        "Streifen-Ahorn (Acer pensylvanicum)": ("Streifen-Ahorn", "Acer pensylvanicum"),
        "Syrischer Wacholder (Juniperus drupacea)": ("Syrischer Wacholder", "Juniperus drupacea"),
        "Sämlings Blutbuche (Fagus sylvatica 'Atropunicea')": ("Sämlings Blutbuche", "Fagus sylvatica 'Atropunicea'"),
        "Säulen-Feldahorn (Acer campestre 'Green Column')": ("Säulen-Feldahorn", "Acer campestre 'Green Column'"),
        "Säulen-Felsenbirne (Amelanchier alnifolia 'Obelisk')": ("Säulen-Felsenbirne", "Amelanchier alnifolia 'Obelisk'"),
        "Säulen-Purpurpappel (Populus deltoides 'Purple Tower')": ("Säulen-Purpurpappel", "Populus deltoides 'Purple Tower'"),
        "Säulen-Traubenkirsche (Prunus padus 'Obelisk')": ("Säulen-Traubenkirsche", "Prunus padus 'Obelisk'"),
        "Säulenahorn (Acer platanoides 'Columnare')": ("Säulenahorn", "Acer platanoides 'Columnare'"),
        "Säulenbirke (Betula pendula 'Fastigiata')": ("Säulenbirke", "Betula pendula 'Fastigiata'"),
        "Säulenblumenesche (Fraxinus ornus 'Obelisk')": ("Säulenblumenesche", "Fraxinus ornus 'Obelisk'"),
        "Säulenblutbuche (Fagus sylvatica 'Rohan Obelisk')": ("Säulenblutbuche", "Fagus sylvatica 'Rohan Obelisk'"),
        "Säulenfichte (Picea abies 'Cupressina')": ("Säulenfichte", "Picea abies 'Cupressina'"),
        "Säulenfächerblattbaum (Ginkgo biloba 'Fastigiata Blagon')": ("Säulenfächerblattbaum", "Ginkgo biloba 'Fastigiata Blagon'"),
        "Säulenginkgo (Ginkgo biloba 'Tremonia')": ("Säulenginkgo", "Ginkgo biloba 'Tremonia'"),
        "Säulengleditschie (Gleditsia triacanthos 'Skyline')": ("Säulengleditschie", "Gleditsia triacanthos 'Skyline'"),
        "Säulenhainbuche (Carpinus betulus 'Fastigiata')": ("Säulenhainbuche", "Carpinus betulus 'Fastigiata'"),
        "Säulenlederhülsenbaum (Gleditsia triacanthos 'Elegantissima')": ("Säulenlederhülsenbaum", "Gleditsia triacanthos 'Elegantissima'"),
        "Säulenmaulbeere (Morus alba 'Fastigiata')": ("Säulenmaulbeere", "Morus alba 'Fastigiata'"),
        "Säulenpappel (Populus simonii 'Fastigiata')": ("Säulenpappel", "Populus simonii 'Fastigiata'"),
        "Säulenrotbuche (Fagus sylvatica 'Fastigiata')": ("Säulenrotbuche", "Fagus sylvatica 'Fastigiata'"),
        "Säulenscheinzypresse (Chamaecyparis lawsoniana 'Alumii')": ("Säulenscheinzypresse", "Chamaecyparis lawsoniana 'Alumii'"),
        "Säulenschwarzkiefer (Pinus nigra 'Pyramidalis')": ("Säulenschwarzkiefer", "Pinus nigra 'Pyramidalis'"),
        "Säulenspitzahorn (Acer platanoides 'Olmstedt')": ("Säulenspitzahorn", "Acer platanoides 'Olmstedt'"),
        "Säulentulpenbaum (Liriodendron tulipifera 'Fastigiatum')": ("Säulentulpenbaum", "Liriodendron tulipifera 'Fastigiatum'"),
        "Säulenweißdorn (Crataegus monogyna 'Stricta')": ("Säulenweißdorn", "Crataegus monogyna 'Stricta'"),
        "Säulenzitterpappel (Populus tremula 'Erecta')": ("Säulenzitterpappel", "Populus tremula 'Erecta'"),
        "Südlicher Zürgelbaum (Celtis australis)": ("Südlicher Zürgelbaum", "Celtis australis"),
        "Süßkirsche (Prunus avium 'Sunburst')": ("Süßkirsche", "Prunus avium 'Sunburst'"),
        "Tafelapfel (Malus domestica 'Winter Goldpermäne')": ("Tafelapfel", "Malus domestica 'Winter Goldpermäne'"),
        "Tanne (Abies spec.)": ("Tanne", "Abies spec."),
        "Taubenbaum (Davidia involucrata)": ("Taubenbaum", "Davidia involucrata"),
        "Toringo-Apfel (Malus toringo)": ("Toringo-Apfel", "Malus toringo"),
        "Tourneforts Zürgelbaum (Celtis tournefortii)": ("Tourneforts Zürgelbaum", "Celtis tournefortii"),
        "Traubenkirsche (Prunus padus)": ("Traubenkirsche", "Prunus padus"),
        "Tränenkiefer (Pinus wallichiana)": ("Tränenkiefer", "Pinus wallichiana"),
        "Tulpen-Magnolie (Magnolia x soulangeana 'Lennei')": ("Tulpen-Magnolie", "Magnolia x soulangeana 'Lennei'"),
        "Tulpenbaum (Liriodendron tulipifera)": ("Tulpenbaum", "Liriodendron tulipifera"),
        "Tulpenmagnolie (Magnolia x soulangiana)": ("Tulpenmagnolie", "Magnolia x soulangiana"),
        "Türkische Kiefer (Pinus brutia)": ("Türkische Kiefer", "Pinus brutia"),
        "Urweltmammutbaum (Metasequoia glyptostroboides)": ("Urweltmammutbaum", "Metasequoia glyptostroboides"),
        "Veitchs Tanne (Abies veitchii)": ("Veitchs Tanne", "Abies veitchii"),
        "Vielblütiger Apfel (Malus floribunda)": ("Vielblütiger Apfel", "Malus floribunda"),
        "Vilmorins Tanne (Abies x vilmorinii)": ("Vilmorins Tanne", "Abies x vilmorinii"),
        "Virginischer Baumwacholder (Juniperus virginiana 'Canaertii')": ("Virginischer Baumwacholder", "Juniperus virginiana 'Canaertii'"),
        "Vogelkirsche (Prunus avium)": ("Vogelkirsche", "Prunus avium"),
        "Wald-Tupelobaum (Nyssa sylvatica)": ("Wald-Tupelobaum", "Nyssa sylvatica"),
        "Walnussbaum (Juglans spec.)": ("Walnussbaum", "Juglans spec."),
        "Weinblättriger Japan-Ahorn (Acer japonicum 'Vitifolium')": ("Weinblättriger Japan-Ahorn", "Acer japonicum 'Vitifolium'"),
        "Weiß-Esche (Fraxinus americana)": ("Weiß-Esche", "Fraxinus americana"),
        "Weiß-Esche 'Autumn Purple' (Fraxinus americana 'Autumn Purple')": ("Weiß-Esche 'Autumn Purple'", "Fraxinus americana 'Autumn Purple'"),
        "Weißbirke (Betula pendula)": ("Weißbirke", "Betula pendula"),
        "Weißbunte Edelkastanie (Castanea sativa 'Albomarginata')": ("Weißbunte Edelkastanie", "Castanea sativa 'Albomarginata'"),
        "Weißbunte Rotbuche (Fagus sylvatica 'Albovariegata')": ("Weißbunte Rotbuche", "Fagus sylvatica 'Albovariegata'"),
        "Weißbunter Eschenahorn (Acer negundo 'Flamingo')": ("Weißbunter Eschenahorn", "Acer negundo 'Flamingo'"),
        "Weißdorn (Crataegus monogyna)": ("Weißdorn", "Crataegus monogyna"),
        "Weißdorn 'Plena' (Crataegus laevigata 'Plena')": ("Weißdorn 'Plena'", "Crataegus laevigata 'Plena'"),
        "Weiße Scheinzypresse (Chamaecyparis thyoides)": ("Weiße Scheinzypresse", "Chamaecyparis thyoides"),
        "Weißer Maulbeerbaum (Morus alba)": ("Weißer Maulbeerbaum", "Morus alba"),
        "Weißgerandeter  Spitzahorn (Acer platanoides 'Drummondii')": ("Weißgerandeter  Spitzahorn", "Acer platanoides 'Drummondii'"),
        "Weißtanne (Abies alba)": ("Weißtanne", "Abies alba"),
        "Westlicher Zürgelbaum (Celtis occidentalis)": ("Westlicher Zürgelbaum", "Celtis occidentalis"),
        "Weymouthskiefer (Pinus strobus)": ("Weymouthskiefer", "Pinus strobus"),
        "Worplesdon-Amberbaum (Liquidambar styraciflua 'Worplesdon')": ("Worplesdon-Amberbaum", "Liquidambar styraciflua 'Worplesdon'"),
        "Yulan-Magnolie (Magnolia denudata)": ("Yulan-Magnolie", "Magnolia denudata"),
        "Zierapfel (Malus x purpurea)": ("Zierapfel", "Malus x purpurea"),
        "Zierapfel Royal Beauty (Malus 'Royal Beauty')": ("Zierapfel Royal Beauty", "Malus 'Royal Beauty'"),
        "Zimtahorn (Acer griseum)": ("Zimtahorn", "Acer griseum"),
        "Zirbel-Kiefer (Pinus cembra)": ("Zirbel-Kiefer", "Pinus cembra"),
        "Zitterpappel (Populus tremula)": ("Zitterpappel", "Populus tremula"),
        "Zucker-Ahorn (Acer saccharum)": ("Zucker-Ahorn", "Acer saccharum"),
        "Zwerg-Libanonzeder (Cedrus libani 'Nana')": ("Zwerg-Libanonzeder", "Cedrus libani 'Nana'"),
        "Zypressen-Wacholder 'Ketele.' (Juniperus chinensis 'Keteleeri')": ("Zypressen-Wacholder 'Ketele.'", "Juniperus chinensis 'Keteleeri'"),
        "Zöschener Ahorn (Acer x zoeschense 'Annae')": ("Zöschener Ahorn", "Acer x zoeschense 'Annae'"),
        "Zürgelbaum (Celtis spec.)": ("Zürgelbaum", "Celtis spec."),
        "Ölweide (Elaeagnus angustifolia)": ("Ölweide", "Elaeagnus angustifolia"),
        "Österreichische Schwarzkiefer (Pinus nigra nigra)": ("Österreichische Schwarzkiefer", "Pinus nigra nigra"),
    ]

    private init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU

            let model = try LeafClassifier(configuration: config)
            let visionModel = try VNCoreMLModel(for: model.model)

            classificationRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.processClassificationResults(request: request, error: error)
            }

            classificationRequest?.imageCropAndScaleOption = .centerCrop
            isModelLoaded = true
            print("LeafClassifier model loaded successfully")
        } catch {
            print("Failed to load LeafClassifier model: \(error)")
            errorMessage = "Modell konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    func classify(image: UIImage) {
        guard isModelLoaded, let request = classificationRequest else {
            errorMessage = "Modell nicht geladen"
            return
        }

        guard let cgImage = image.cgImage else {
            errorMessage = "Bild konnte nicht verarbeitet werden"
            return
        }

        isClassifying = true
        errorMessage = nil
        lastImage = image

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgImageOrientation(from: image), options: [:])

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self?.isClassifying = false
                    self?.errorMessage = "Klassifizierung fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }

    private func processClassificationResults(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isClassifying = false

            if let error = error {
                self.errorMessage = "Fehler: \(error.localizedDescription)"
                return
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                self.errorMessage = "Keine Ergebnisse"
                return
            }

            self.lastResults = observations.prefix(5).compactMap { observation in
                let label = observation.identifier
                let species = self.speciesMapping[label]
                return LeafClassificationResult(
                    speciesGerman: species?.german ?? label,
                    speciesLatin: species?.latin ?? "",
                    confidence: Double(observation.confidence),
                    label: label
                )
            }
        }
    }

    private func cgImageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    func reset() {
        lastResults = []
        lastImage = nil
        errorMessage = nil
        isClassifying = false
    }
}
