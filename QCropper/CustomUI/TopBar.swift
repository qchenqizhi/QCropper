//
//  TopBar.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

class TopBar: UIView {
    lazy var flipButton: UIButton = {
        let button = self.iconButton(iconName: "flip.horizontal.fill")
        button.left = 0
        button.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        return button
    }()

    lazy var rotateButton: UIButton = {
        let button = self.iconButton(iconName: "rotate.right.fill")
        button.left = self.flipButton.right
        button.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        return button
    }()

    lazy var aspectRationButton: UIButton = {
        let button = self.iconButton(iconName: "aspectratio.fill")
        button.right = self.width
        button.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        return button
    }()

    lazy var blurBackgroundView: UIVisualEffectView = {
        let vev = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        vev.alpha = 0.3
        vev.backgroundColor = .clear
        vev.frame = self.bounds
        vev.isUserInteractionEnabled = false
        vev.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin, .flexibleHeight, .flexibleWidth]
        return vev
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(blurBackgroundView)
        addSubview(flipButton)
        addSubview(rotateButton)
        addSubview(aspectRationButton)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func iconButton(iconName: String) -> UIButton {
        let button = UIButton(frame: CGRect(center: .zero, size: CGSize(width: 44, height: 44)))
        button.setImage(UIImage(systemNameOrColorIfNotAvailable: iconName), for: .normal)
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemNameOrColorIfNotAvailable: iconName)?.withTintColor(highlightColor), for: .selected)
        }
        button.tintColor = UIColor(white: 0.725, alpha: 1)
        button.bottom = height
        return button
    }
}
