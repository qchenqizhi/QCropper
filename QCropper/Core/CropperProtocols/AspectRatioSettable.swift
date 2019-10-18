//
//  AspectRatioSettable.swift
//
//  Created by Spike on 2019/10/18.
//

import UIKit

public protocol AspectRatioSettable {
    func setAspectRatio(_ aspectRatio: AspectRatio)
    func setAspectRatioValue(_ aspectRatioValue: CGFloat)
}

extension AspectRatioSettable where Self: CropperViewController {
    public func setAspectRatio(_ aspectRatio: AspectRatio) {
        currentAspectRatio = aspectRatio
        switch aspectRatio {
        case .original:
            setAspectRatioValue(originalImage.size.width / originalImage.size.height)
            aspectRatioLocked = true
        case .freeForm:
            aspectRatioLocked = false
        case .square:
            setAspectRatioValue(1)
            aspectRatioLocked = true
        case let .ratio(width, height):
            setAspectRatioValue(CGFloat(width) / CGFloat(height))
            aspectRatioLocked = true
        }
    }

    public func setAspectRatioValue(_ aspectRatioValue: CGFloat) {
        guard aspectRatioValue > 0 else { return }

        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
        aspectRatioLocked = true
        currentAspectRatioValue = aspectRatioValue

        var targetCropBoxFrame: CGRect
        let height: CGFloat = maxCropRegion.size.width / aspectRatioValue
        if height <= maxCropRegion.size.height {
            targetCropBoxFrame = CGRect(center: defaultCropBoxCenter, size: CGSize(width: maxCropRegion.size.width, height: height))
        } else {
            let width = maxCropRegion.size.height * aspectRatioValue
            targetCropBoxFrame = CGRect(center: defaultCropBoxCenter, size: CGSize(width: width, height: maxCropRegion.size.height))
        }
        targetCropBoxFrame = safeCropBoxFrame(targetCropBoxFrame)

        let currentCropBoxFrame = overlay.cropBoxFrame

        /// The content of the image is getting bigger and bigger when switching the aspect ratio.
        /// Make a fake cropBoxFrame to help calculate how much the image should be scaled.
        var contentBiggerThanCurrentTargetCropBoxFrame: CGRect
        if currentCropBoxFrame.size.width / currentCropBoxFrame.size.height > aspectRatioValue {
            contentBiggerThanCurrentTargetCropBoxFrame = CGRect(center: defaultCropBoxCenter, size: CGSize(width: currentCropBoxFrame.size.width, height: currentCropBoxFrame.size.width / aspectRatioValue))
        } else {
            contentBiggerThanCurrentTargetCropBoxFrame = CGRect(center: defaultCropBoxCenter, size: CGSize(width: currentCropBoxFrame.size.height * aspectRatioValue, height: currentCropBoxFrame.size.height))
        }
        let extraZoomScale = max(targetCropBoxFrame.size.width / contentBiggerThanCurrentTargetCropBoxFrame.size.width, targetCropBoxFrame.size.height / contentBiggerThanCurrentTargetCropBoxFrame.size.height)

        overlay.gridLinesAlpha = 0

        matchScrollViewAndCropView(animated: true, targetCropBoxFrame: targetCropBoxFrame, extraZoomScale: extraZoomScale, blurLayerAnimated: true, animations: nil, completion: {
            self.topBar.isUserInteractionEnabled = true
            self.bottomView.isUserInteractionEnabled = true
            self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
        })
    }
}
