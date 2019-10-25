//
//  UIImage+Helper.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

extension UIImage {

    // MARK: Custom UI

    convenience init(color: UIColor, size: CGSize) {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)

        defer {
            UIGraphicsEndImageContext()
        }

        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        guard let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else {
            self.init()
            return
        }

        self.init(cgImage: cgImage)
    }
}
