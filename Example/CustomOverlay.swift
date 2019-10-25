//
//  CustomOverlay.swift
//
//  Created by Chen Qizhi on 2019/10/25.
//

import QCropper

class CustomOverlay: Overlay {

    lazy var borderLayer: CAShapeLayer = {
        let bl = CAShapeLayer()
        bl.strokeColor = UIColor.white.cgColor
        bl.fillColor = UIColor.clear.cgColor
        return bl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        cropBox.isHidden = true
        layer.addSublayer(borderLayer)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateMask(animated: Bool) {
        var maskLayer: CAShapeLayer
        if let ml = translucentMaskView.layer.mask as? CAShapeLayer {
            maskLayer = ml
        } else {
            maskLayer = CAShapeLayer()
            translucentMaskView.layer.mask = maskLayer
        }

        let bezierPath = UIBezierPath(rect: translucentMaskView.bounds)
        let center = UIBezierPath(roundedRect: cropBox.frame, byRoundingCorners: [.topRight, .bottomLeft], cornerRadii: CGSize(width: 50, height: 50))
        bezierPath.append(center)

        maskLayer.fillRule = .evenOdd
        bezierPath.usesEvenOddFillRule = true

        borderLayer.path = center.cgPath
        borderLayer.lineWidth = free ? 1.0 : 2.0

        if animated {
            let animation = CABasicAnimation(keyPath: "path")
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            maskLayer.path = bezierPath.cgPath
            animation.duration = 0.25
            maskLayer.add(animation, forKey: animation.keyPath)
        } else {
            maskLayer.path = bezierPath.cgPath
        }
    }
}
