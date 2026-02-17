import SwiftUI
import UIKit

private let hgFamily = "Host Grotesk"

func registerHostGroteskAsDefault() {
    UIFont.swizzleSystemFont()
}

extension UIFont {

    static func swizzleSystemFont() {
        let swaps: [(Selector, Selector)] = [
            (#selector(UIFont.systemFont(ofSize:weight:)), #selector(UIFont.hg_systemFont(ofSize:weight:))),
            (#selector(UIFont.systemFont(ofSize:)),        #selector(UIFont.hg_systemFont(ofSize:))),
            (#selector(UIFont.boldSystemFont(ofSize:)),    #selector(UIFont.hg_boldSystemFont(ofSize:))),
            (#selector(UIFont.italicSystemFont(ofSize:)),  #selector(UIFont.hg_italicSystemFont(ofSize:))),
        ]
        for (orig, repl) in swaps {
            if let o = class_getClassMethod(UIFont.self, orig),
               let r = class_getClassMethod(UIFont.self, repl) {
                method_exchangeImplementations(o, r)
            }
        }
    }

    @objc class func hg_systemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        hostGrotesk(size: size, weight: weight)
    }

    @objc class func hg_systemFont(ofSize size: CGFloat) -> UIFont {
        hostGrotesk(size: size)
    }

    @objc class func hg_boldSystemFont(ofSize size: CGFloat) -> UIFont {
        hostGrotesk(size: size, weight: .bold)
    }

    @objc class func hg_italicSystemFont(ofSize size: CGFloat) -> UIFont {
        UIFont(name: "HostGrotesk-Italic", size: size)
            ?? hostGrotesk(size: size)
    }

    static func hostGrotesk(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light: name = "HostGrotesk-Light"
        case .regular:                   name = "HostGrotesk-Regular"
        case .medium:                    name = "HostGrotesk-Medium"
        case .semibold:                  name = "HostGrotesk-SemiBold"
        case .bold:                      name = "HostGrotesk-Bold"
        case .heavy, .black:             name = "HostGrotesk-ExtraBold"
        default:                         name = "HostGrotesk-Regular"
        }
        return UIFont(name: name, size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}

extension Font {

    static func hostGrotesk(_ style: TextStyle = .body) -> Font {
        .custom(hgFamily, size: styleSize(style), relativeTo: style)
    }

    static func hostGrotesk(size: CGFloat) -> Font {
        .custom(hgFamily, size: size)
    }

    static func hostGrotesk(_ style: TextStyle, weight: Weight) -> Font {
        .custom(hgFamily, size: styleSize(style), relativeTo: style).weight(weight)
    }

    static func hostGrotesk(size: CGFloat, weight: Weight) -> Font {
        .custom(hgFamily, size: size).weight(weight)
    }

    private static func styleSize(_ style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title:      return 28
        case .title2:     return 22
        case .title3:     return 20
        case .headline:   return 17
        case .body:       return 17
        case .callout:    return 16
        case .subheadline: return 15
        case .footnote:   return 13
        case .caption:    return 12
        case .caption2:   return 11
        @unknown default: return 17
        }
    }
}
