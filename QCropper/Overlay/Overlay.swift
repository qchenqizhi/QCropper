//
//  Overlay.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

/// All overlays, including grid, crop box, translucent blur mask
class Overlay: UIView {

    var cropBoxAlpha: CGFloat {
        get {
            return cropBox.alpha
        }
        set {
            cropBox.alpha = newValue
        }
    }

    var gridLinesAlpha: CGFloat {
        get {
            return cropBox.gridLinesAlpha
        }
        set {
            cropBox.gridLinesAlpha = newValue
        }
    }

    var gridLinesCount: UInt = 2 {
        didSet {
            cropBox.gridLinesView.horizontalLinesCount = gridLinesCount
            cropBox.gridLinesView.verticalLinesCount = gridLinesCount
        }
    }

    // TODO:
    var circular: Bool = false

    var blur: Bool = true {
        didSet {
            if blur {
                translucentMaskView.effect = UIBlurEffect(style: .dark)
                translucentMaskView.backgroundColor = .clear
            } else {
                translucentMaskView.effect = nil
                translucentMaskView.backgroundColor = maskColor
            }
        }
    }

    // Take effect when blur = false
    var maskColor: UIColor = UIColor(white: 0.1, alpha: 0.3) {
        didSet {
            if !blur {
                translucentMaskView.backgroundColor = maskColor
            }
        }
    }

    var free: Bool = true {
        didSet {
            if free {
                cropBox.layer.borderWidth = 1
            } else {
                cropBox.layer.borderWidth = 2
            }
        }
    }

    var cropBoxFrame: CGRect {
        get {
            return cropBox.frame
        }
        set(frame) {
            cropBox.frame = frame

            updateMask(animated: false)
        }
    }

    public func setCropBoxFrame(_ cropBoxFrame: CGRect, blurLayerAnimated: Bool) {
        cropBox.frame = cropBoxFrame

        updateMask(animated: blurLayerAnimated)
    }

    private var cropBox = CropBox(frame: .zero)

    private lazy var translucentMaskView: UIVisualEffectView = {
        let vev = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        vev.backgroundColor = .clear
        vev.frame = self.bounds
        vev.isUserInteractionEnabled = false
        vev.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin, .flexibleHeight, .flexibleWidth]
        return vev
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false

        addSubview(translucentMaskView)
        addSubview(cropBox)

        gridLinesAlpha = 0
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateMask(animated: Bool) {
        var maskLayer: CAShapeLayer
        if let ml = self.translucentMaskView.layer.mask as? CAShapeLayer {
            maskLayer = ml
        } else {
            maskLayer = CAShapeLayer()
            translucentMaskView.layer.mask = maskLayer
        }

        let path: CGMutablePath = CGMutablePath()
        // Left
        path.addRect(CGRect(x: 0, y: 0, width: cropBox.left, height: translucentMaskView.height))
        // Right
        path.addRect(CGRect(x: cropBox.right, y: 0, width: frame.size.width - cropBox.right, height: translucentMaskView.height))
        // Top
        path.addRect(CGRect(x: 0, y: 0, width: frame.size.width, height: cropBox.top))
        // Bottom
        path.addRect(CGRect(x: 0, y: cropBox.bottom, width: frame.size.width, height: translucentMaskView.height - cropBox.bottom))

        if animated {
            let animation = CABasicAnimation(keyPath: "path")
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            maskLayer.path = path
            animation.duration = 0.25
            maskLayer.add(animation, forKey: animation.keyPath)
        } else {
            maskLayer.path = path
        }
    }
}
