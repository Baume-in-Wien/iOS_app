import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

struct QRCodeService {

    static func generateQRCode(for rally: Rally) -> UIImage? {
        generateQRCode(from: rally.qrCodeString)
    }

    static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale: CGFloat = 10
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    static func parseRallyCode(from string: String) -> String? {

        guard string.hasPrefix("baumkataster://rally/") else { return nil }
        let code = String(string.dropFirst("baumkataster://rally/".count))
        return code.count == 6 ? code : nil
    }
}
