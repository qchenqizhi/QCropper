//
//  CropperViewController.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

enum CropBoxEdge: Int {
    case none
    case left
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
}

protocol CropperViewControllerDelegate: class {
    func cropperDidConfirm(_ cropper: CropperViewController, state: CropperState?)
    func cropperDidCancel(_ cropper: CropperViewController)
}

extension CropperViewControllerDelegate {
    func cropperDidCancel(_ cropper: CropperViewController) {
        cropper.dismiss(animated: true, completion: nil)
    }
}

class CropperViewController: UIViewController {
    let originalImage: UIImage
    var initialState: CropperState?

    init(originalImage: UIImage, initialState: CropperState? = nil) {
        self.originalImage = originalImage
        self.initialState = initialState
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public weak var delegate: CropperViewControllerDelegate?

    // if self not init with a state, return false
    public var isCurrentlyInInitialState: Bool {
        isCurrentlyInState(initialState)
    }

    public var aspectRatioLocked: Bool = false {
        didSet {
            overlay.free = !aspectRatioLocked
        }
    }

    public var currentAspectRatio: AspectRatio = .freeForm
    public var currentAspectRatioValue: CGFloat = 1.0

    private let cropBoxHotArea: CGFloat = 50
    private let cropBoxMinSize: CGFloat = 20
    private let barHeight: CGFloat = 44

    private var cropRegionInsets: UIEdgeInsets = .zero
    private var maxCropRegion: CGRect = .zero
    private var defaultCropBoxCenter: CGPoint = .zero
    private var defaultCropBoxSize: CGSize = .zero

    private var straightenAngle: CGFloat = 0.0
    private var rotationAngle: CGFloat = 0.0
    private var flipAngle: CGFloat = 0.0

    private var panBeginningPoint: CGPoint = .zero
    private var panBeginningCropBoxEdge: CropBoxEdge = .none
    private var panBeginningCropBoxFrame: CGRect = .zero

    private var manualZoomed: Bool = false

    private var needReload: Bool = false
    private var defaultCropperState: CropperState?
    private var stasisTimer: Timer?
    private var stasisThings: (() -> Void)?

    private var isCurrentlyInDefalutState: Bool {
        isCurrentlyInState(defaultCropperState)
    }

    private var totalAngle: CGFloat {
        return autoHorizontalOrVerticalAngle(straightenAngle + rotationAngle + flipAngle)
    }

    private lazy var scrollViewContainer: ScrollViewContainer = ScrollViewContainer(frame: self.view.bounds)

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.defaultCropBoxSize.width, height: self.defaultCropBoxSize.height))
        sv.delegate = self
        sv.center = self.backgroundView.convert(defaultCropBoxCenter, to: scrollViewContainer)
        sv.bounces = true
        sv.bouncesZoom = true
        sv.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sv.alwaysBounceVertical = true
        sv.alwaysBounceHorizontal = true
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 20
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.clipsToBounds = false
        sv.contentSize = self.defaultCropBoxSize
        //// debug
        // sv.layer.borderColor = UIColor.green.cgColor
        // sv.layer.borderWidth = 1
        // sv.showsVerticalScrollIndicator = true
        // sv.showsHorizontalScrollIndicator = true

        return sv
    }()

    private lazy var imageView: UIImageView = {
        let iv = UIImageView(image: self.originalImage)
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var cropBoxPanGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(cropBoxPan(_:)))
        pan.delegate = self
        return pan
    }()

    // MARK: Custom UI

    private lazy var backgroundView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        return view
    }()

    private lazy var bottomView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: self.view.height - 100, width: self.view.width, height: 100))
        view.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
        return view
    }()

    private lazy var topBar: TopBar = {
        let topBar = TopBar(frame: CGRect(x: 0, y: 0, width: self.view.width, height: self.view.safeAreaInsets.top + barHeight))
        topBar.flipButton.addTarget(self, action: #selector(flipButtonPressed(_:)), for: .touchUpInside)
        topBar.rotateButton.addTarget(self, action: #selector(rotateButtonPressed(_:)), for: .touchUpInside)
        topBar.aspectRationButton.addTarget(self, action: #selector(aspectRationButtonPressed(_:)), for: .touchUpInside)
        return topBar
    }()

    private lazy var toolbar: Toolbar = {
        let toolbar = Toolbar(frame: CGRect(x: 0, y: 0, width: self.view.width, height: view.safeAreaInsets.bottom + barHeight))
        toolbar.doneButton.addTarget(self, action: #selector(confirmButtonPressed(_:)), for: .touchUpInside)
        toolbar.cancelButton.addTarget(self, action: #selector(cancelButtonPressed(_:)), for: .touchUpInside)
        toolbar.resetButton.addTarget(self, action: #selector(resetButtonPressed(_:)), for: .touchUpInside)

        return toolbar
    }()

    private var allowedAspectRatios: [AspectRatio] = [
        .original,
        .freeForm,
        .square,
        .ratio(width: 9, height: 16),
        .ratio(width: 8, height: 10),
        .ratio(width: 5, height: 7),
        .ratio(width: 3, height: 4),
        .ratio(width: 3, height: 5),
        .ratio(width: 2, height: 3)
    ]

    private func showAspectRatioPicker() {
        let alert = UIAlertController(title: "Select aspect ratio", message: nil, preferredStyle: .actionSheet)
        for ar in allowedAspectRatios {
            alert.addAction(UIAlertAction(title: ar.description, style: .default, handler: { _ in
                self.setAspectRatio(ar)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private lazy var aspectRatioPicker: UIView = UIView()

    private lazy var overlay: Overlay = Overlay(frame: self.view.bounds)

    private var hasSetAspectRatioAfterLayout: Bool = false
    lazy var angleRuler: AngleRuler = {
        let ar = AngleRuler(frame: CGRect(x: 0, y: 0, width: view.width, height: 70))
        ar.addTarget(self, action: #selector(angleRulerValueChanged(_:)), for: .valueChanged)
        ar.addTarget(self, action: #selector(angleRulerTouchEnded(_:)), for: [.editingDidEnd])
        return ar
    }()

    @objc
    func angleRulerValueChanged(_: AnyObject) {
        toolbar.isUserInteractionEnabled = false
        topBar.isUserInteractionEnabled = false
        scrollViewContainer.isUserInteractionEnabled = false
        setStraightenAngle(CGFloat(angleRuler.value * CGFloat.pi / 180.0))
    }

    @objc
    func angleRulerTouchEnded(_: AnyObject) {
        UIView.animate(withDuration: 0.25, animations: {
            self.overlay.gridLinesAlpha = 0
            self.overlay.blur = true
        }, completion: { _ in
            self.toolbar.isUserInteractionEnabled = true
            self.topBar.isUserInteractionEnabled = true
            self.scrollViewContainer.isUserInteractionEnabled = true
            self.overlay.gridLinesCount = 2
        })
    }

    // MARK: - Override

    deinit {
        self.cancelStasis()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.isHidden = true

        // TODO: transition

        if originalImage.size.width < 1 || originalImage.size.height < 1 {
            // TODO: show alert and dismiss
            return
        }

        view.backgroundColor = .clear

        scrollView.addSubview(imageView)

        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        scrollViewContainer.scrollView = scrollView
        scrollViewContainer.addSubview(scrollView)
        scrollViewContainer.addGestureRecognizer(cropBoxPanGesture)
        scrollView.panGestureRecognizer.require(toFail: cropBoxPanGesture)

        backgroundView.addSubview(scrollViewContainer)
        backgroundView.addSubview(overlay)
        bottomView.addSubview(aspectRatioPicker)
        bottomView.addSubview(angleRuler)
        bottomView.addSubview(toolbar)

        view.addSubview(backgroundView)
        view.addSubview(bottomView)
        view.addSubview(topBar)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Layout when self.view finish layout and never layout before, or self.view need reload
        if let viewFrame = defaultCropperState?.viewFrame,
            viewFrame.equalTo(view.frame) {
            if needReload {
                // TODO: reload but keep crop box
                needReload = false
                resetToDefaultLayout()
            }
        } else {
            // TODO: suppport multi oriention
            resetToDefaultLayout()

            if let initialState = initialState {
                restoreState(initialState)
                toolbar.resetButton.isHidden = isCurrentlyInDefalutState
            }

            if initialState != nil, !hasSetAspectRatioAfterLayout {
                hasSetAspectRatioAfterLayout = true
//                aspectRatioPicker.currentAspectRatio = aspectRatioPicker.currentAspectRatio
            }
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .top
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        needReload = true
    }

    // MARK: - User Interaction

    @objc
    private func cropBoxPan(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: view)

        if pan.state == .began {
            cancelStasis()
            panBeginningPoint = point
            panBeginningCropBoxFrame = overlay.cropBoxFrame
            panBeginningCropBoxEdge = nearestCropBoxEdgeForPoint(point: panBeginningPoint)
            overlay.blur = false
            overlay.gridLinesAlpha = 1
            topBar.isUserInteractionEnabled = false
            bottomView.isUserInteractionEnabled = false
        }

        if pan.state == .ended || pan.state == .cancelled {
            stasisAndThenRun {
                self.matchScrollViewAndCropView(animated: true, targetCropBoxFrame: self.overlay.cropBoxFrame, extraZoomScale: 1, blurLayerAnimated: true, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: {
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
                })
            }
        } else {
            updateCropBoxFrameWithPanGesturePoint(point)
        }
    }

    @objc
    private func cancelButtonPressed(_: UIButton) {
        delegate?.cropperDidCancel(self)
    }

    @objc
    private func confirmButtonPressed(_: UIButton) {
        delegate?.cropperDidConfirm(self, state: saveState())
    }

    @objc
    private func resetButtonPressed(_: UIButton) {
        overlay.blur = false
        overlay.gridLinesAlpha = 0
        overlay.cropBoxAlpha = 0
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.25, animations: {
            self.resetToDefaultLayout()
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, animations: {
                self.overlay.cropBoxAlpha = 1
                self.overlay.blur = true
            }, completion: { _ in
                self.topBar.isUserInteractionEnabled = true
                self.bottomView.isUserInteractionEnabled = true
            })
        })
    }

    @objc
    private func flipButtonPressed(_: UIButton) {
        flip()
    }

    @objc
    private func rotateButtonPressed(_: UIButton) {
        rotate90degrees()
    }

    @objc
    private func aspectRationButtonPressed(_: UIButton) {
        showAspectRatioPicker()
    }
}

// MARK: - Public Methods

extension CropperViewController {

    public func saveState() -> CropperState {
        let cs = CropperState(viewFrame: view.frame,
                              angle: totalAngle,
                              rotationAngle: rotationAngle,
                              straightenAngle: straightenAngle,
                              flipAngle: flipAngle,
                              imageOrientationRawValue: imageView.image?.imageOrientation.rawValue ?? 0,
                              scrollViewTransform: scrollView.transform,
                              scrollViewCenter: scrollView.center,
                              scrollViewBounds: scrollView.bounds,
                              scrollViewContentOffset: scrollView.contentOffset,
                              scrollViewMinimumZoomScale: scrollView.minimumZoomScale,
                              scrollViewMaximumZoomScale: scrollView.maximumZoomScale,
                              scrollViewZoomScale: scrollView.zoomScale,
                              cropBoxFrame: overlay.cropBoxFrame,
                              aspectRatioLocked: aspectRatioLocked,
                              currentAspectRatio: currentAspectRatio,
                              currentAspectRatioValue: currentAspectRatioValue,
                              photoTranslation: photoTranslation(),
                              imageViewTransform: imageView.transform,
                              imageViewBoundsSize: imageView.bounds.size)
        return cs
    }

    public func restoreState(_ state: CropperState, animated: Bool = false) {
        guard view.frame.equalTo(state.viewFrame) else {
            return
        }

        let animationsBlock = { () -> Void in
            self.rotationAngle = state.rotationAngle
            self.straightenAngle = state.straightenAngle
            self.flipAngle = state.flipAngle
            let orientation = UIImage.Orientation(rawValue: state.imageOrientationRawValue) ?? .up
            self.imageView.image = self.imageView.image?.withOrientation(orientation)
            self.scrollView.minimumZoomScale = state.scrollViewMinimumZoomScale
            self.scrollView.maximumZoomScale = state.scrollViewMaximumZoomScale
            self.scrollView.zoomScale = state.scrollViewZoomScale
            self.scrollView.transform = state.scrollViewTransform
            self.scrollView.bounds = state.scrollViewBounds
            self.scrollView.contentOffset = state.scrollViewContentOffset
            self.scrollView.center = state.scrollViewCenter
            self.overlay.cropBoxFrame = state.cropBoxFrame
            self.aspectRatioLocked = state.aspectRatioLocked
            self.currentAspectRatio = state.currentAspectRatio
            //            self.aspectRatioPicker.currentAspectRatio =
            self.currentAspectRatioValue = state.currentAspectRatioValue
            self.angleRuler.value = state.straightenAngle * 180 / CGFloat.pi
            // No need restore
            //            self.photoTranslation() = state.photoTranslation
            //            self.imageView.transform = state.imageViewTransform
            //            self.imageView.bounds.size = state.imageViewBoundsSize
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: animationsBlock)
        } else {
            animationsBlock()
        }
    }

    public func setStraightenAngle(_ angle: CGFloat) {
        overlay.cropBoxFrame = overlay.cropBoxFrame
        overlay.gridLinesAlpha = 1
        overlay.gridLinesCount = 8

        UIView.animate(withDuration: 0.2, animations: {
            self.overlay.blur = false
        })

        straightenAngle = angle
        scrollView.transform = CGAffineTransform(rotationAngle: totalAngle)

        let rect = overlay.cropBoxFrame
        let rotatedRect = rect.applying(CGAffineTransform(rotationAngle: totalAngle))
        let width = rotatedRect.size.width
        let height = rotatedRect.size.height
        let center = scrollView.center

        let contentOffset = scrollView.contentOffset
        let contentOffsetCenter = CGPoint(x: contentOffset.x + scrollView.bounds.size.width / 2, y: contentOffset.y + scrollView.bounds.size.height / 2)
        scrollView.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let newContentOffset = CGPoint(x: contentOffsetCenter.x - scrollView.bounds.size.width / 2, y: contentOffsetCenter.y - scrollView.bounds.size.height / 2)
        scrollView.contentOffset = newContentOffset
        scrollView.center = center

        let shouldScale: Bool = scrollView.contentSize.width / scrollView.bounds.size.width <= 1.0 || scrollView.contentSize.height / scrollView.bounds.size.height <= 1.0
        if !manualZoomed || shouldScale {
            scrollView.minimumZoomScale = scrollViewZoomScaleToBounds()
            scrollView.setZoomScale(scrollViewZoomScaleToBounds(), animated: false)

            manualZoomed = false
        }

        scrollView.contentOffset = safeContentOffsetForScrollView(newContentOffset)
        toolbar.resetButton.isHidden = isCurrentlyInDefalutState
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

    public func rotate90degrees(clockwise: Bool = true) {
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false

        // Make sure to cover the entire screen while rotating
        let scale = max(maxCropRegion.size.width / overlay.cropBoxFrame.size.width, maxCropRegion.size.height / overlay.cropBoxFrame.size.height)
        let frame = scrollViewContainer.bounds.insetBy(dx: -scrollViewContainer.width * scale * 3, dy: -scrollViewContainer.height * scale * 3)

        let rotatingOverlay = Overlay(frame: frame)
        rotatingOverlay.blur = false
        rotatingOverlay.maskColor = backgroundView.backgroundColor ?? .black
        rotatingOverlay.cropBoxAlpha = 0
        scrollViewContainer.addSubview(rotatingOverlay)

        let rotatingCropBoxFrame = rotatingOverlay.convert(overlay.cropBoxFrame, from: backgroundView)
        rotatingOverlay.cropBoxFrame = rotatingCropBoxFrame
        rotatingOverlay.transform = .identity
        rotatingOverlay.layer.anchorPoint = CGPoint(x: rotatingCropBoxFrame.midX / rotatingOverlay.size.width,
                                                    y: rotatingCropBoxFrame.midY / rotatingOverlay.size.height)

        overlay.isHidden = true

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            // rotate scroll view
            if clockwise {
                self.rotationAngle += CGFloat.pi / 2.0
            } else {
                self.rotationAngle -= CGFloat.pi / 2.0
            }
            self.rotationAngle = self.standardizeAngle(self.rotationAngle)
            self.scrollView.transform = CGAffineTransform(rotationAngle: self.totalAngle)

            // position scroll view
            let scrollViewCenter = self.scrollView.center
            let cropBoxCenter = self.defaultCropBoxCenter
            let r = self.overlay.cropBoxFrame
            var rect: CGRect = .zero

            let scaleX = self.maxCropRegion.size.width / r.size.height
            let scaleY = self.maxCropRegion.size.height / r.size.width

            let scale = min(scaleX, scaleY)

            rect.size.width = r.size.height * scale
            rect.size.height = r.size.width * scale

            rect.origin.x = cropBoxCenter.x - rect.size.width / 2.0
            rect.origin.y = cropBoxCenter.y - rect.size.height / 2.0

            self.overlay.cropBoxFrame = rect

            rotatingOverlay.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0).scaledBy(x: scale, y: scale)
            rotatingOverlay.center = scrollViewCenter

            let rotatedRect = rect.applying(CGAffineTransform(rotationAngle: self.totalAngle))
            let width = rotatedRect.size.width
            let height = rotatedRect.size.height

            let contentOffset = self.scrollView.contentOffset
            let showingContentCenter = CGPoint(x: contentOffset.x + self.scrollView.bounds.size.width / 2, y: contentOffset.y + self.scrollView.bounds.size.height / 2)
            let showingContentNormalizedCenter = CGPoint(x: showingContentCenter.x / self.imageView.width, y: showingContentCenter.y / self.imageView.height)

            self.scrollView.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            let zoomScale = self.scrollView.zoomScale * scale
            self.willSetScrollViewZoomScale(zoomScale)
            self.scrollView.zoomScale = zoomScale
            let newContentOffset = CGPoint(x: showingContentNormalizedCenter.x * self.imageView.width - self.scrollView.bounds.size.width * 0.5,
                                           y: showingContentNormalizedCenter.y * self.imageView.height - self.scrollView.bounds.size.height * 0.5)
            self.scrollView.contentOffset = self.safeContentOffsetForScrollView(newContentOffset)
            self.scrollView.center = scrollViewCenter
        }, completion: { _ in
            self.allowedAspectRatios = self.allowedAspectRatios.map { $0.rotated }
            self.currentAspectRatio = self.currentAspectRatio.rotated
            if self.aspectRatioLocked {
                self.currentAspectRatioValue = 1 / self.currentAspectRatioValue
            }
            self.overlay.cropBoxAlpha = 0
            self.overlay.blur = true
            self.overlay.isHidden = false
            UIView.animate(withDuration: 0.25, animations: {
                rotatingOverlay.alpha = 0
                self.overlay.cropBoxAlpha = 1
            }, completion: { _ in
                rotatingOverlay.isHidden = true
                rotatingOverlay.removeFromSuperview()
                self.topBar.isUserInteractionEnabled = true
                self.bottomView.isUserInteractionEnabled = true
                self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
            })
        })
    }

    public func flip(directionHorizontal: Bool = true) {
        let size: CGSize = scrollView.contentSize
        let contentOffset = scrollView.contentOffset
        let bounds: CGSize = scrollView.bounds.size

        scrollView.contentOffset = CGPoint(x: size.width - bounds.width - contentOffset.x, y: contentOffset.y)

        let image = imageView.image
        let fliped: Bool = (image?.imageOrientation == .upMirrored)
        // TODO: multi imageOrientation

        if directionHorizontal {
            flipAngle += -2.0 * totalAngle // Make sum equal to -self.totalAngle
        } else {
            flipAngle += CGFloat.pi - 2.0 * totalAngle //  Make sum equal to pi - self.totalAngle
        }

        imageView.image = image?.withOrientation(fliped ? .up : .upMirrored)

        scrollView.transform = CGAffineTransform(rotationAngle: totalAngle)
    }
}

// MARK: - Private Methods

private extension CropperViewController {

    private var cropBoxFrame: CGRect {
        get {
            return overlay.cropBoxFrame
        }
        set {
            overlay.cropBoxFrame = safeCropBoxFrame(newValue)
        }
    }

    func resetToDefaultLayout() {
        let margin: CGFloat = 20

        topBar.frame = CGRect(x: 0, y: 0, width: view.width, height: view.safeAreaInsets.top + barHeight)
        toolbar.size = CGSize(width: view.width, height: view.safeAreaInsets.bottom + barHeight)
        bottomView.size = CGSize(width: view.width, height: toolbar.height + angleRuler.height + margin)
        bottomView.bottom = view.height
        toolbar.bottom = bottomView.height
        angleRuler.bottom = toolbar.top - margin

        cropRegionInsets = UIEdgeInsets(top: margin + topBar.height,
                                        left: margin + view.safeAreaInsets.left,
                                        bottom: margin + bottomView.height,
                                        right: margin + view.safeAreaInsets.right)

        maxCropRegion = CGRect(x: cropRegionInsets.left,
                               y: cropRegionInsets.top,
                               width: view.width - cropRegionInsets.left - cropRegionInsets.right,
                               height: view.height - cropRegionInsets.top - cropRegionInsets.bottom)
        defaultCropBoxCenter = CGPoint(x: view.width / 2.0, y: cropRegionInsets.top + maxCropRegion.size.height / 2.0)
        defaultCropBoxSize = {
            var size: CGSize
            let scaleW = self.originalImage.size.width / self.maxCropRegion.size.width
            let scaleH = self.originalImage.size.height / self.maxCropRegion.size.height
            let scale = max(scaleW, scaleH)
            size = CGSize(width: self.originalImage.size.width / scale, height: self.originalImage.size.height / scale)
            return size
        }()

        backgroundView.frame = view.bounds
        scrollViewContainer.frame = CGRect(x: 0, y: topBar.height, width: view.width, height: view.height - topBar.height - bottomView.height)

        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 20
        scrollView.zoomScale = 1
        scrollView.transform = .identity
        scrollView.bounds = CGRect(x: 0, y: 0, width: defaultCropBoxSize.width, height: defaultCropBoxSize.height)
        scrollView.contentSize = defaultCropBoxSize
        scrollView.contentOffset = .zero
        scrollView.center = backgroundView.convert(defaultCropBoxCenter, to: scrollViewContainer)
        imageView.transform = .identity
        imageView.frame = scrollView.bounds
        aspectRatioPicker.frame = CGRect(x: 0, y: 0, width: view.width, height: 76)
        overlay.frame = backgroundView.bounds
        overlay.cropBoxFrame = CGRect(center: defaultCropBoxCenter, size: defaultCropBoxSize)

        straightenAngle = 0
        rotationAngle = 0
        flipAngle = 0
//        aspectRatioPicker.currentAspectRatio = .freeForm
        aspectRatioLocked = false
        currentAspectRatioValue = 1

        if originalImage.size.width / originalImage.size.height < cropBoxMinSize / maxCropRegion.size.height { // very long
            cropBoxFrame = CGRect(x: (view.width - cropBoxMinSize) / 2, y: cropRegionInsets.top, width: cropBoxMinSize, height: maxCropRegion.size.height)
            matchScrollViewAndCropView()
        } else if originalImage.size.height / originalImage.size.width < cropBoxMinSize / maxCropRegion.size.width { // very wide
            cropBoxFrame = CGRect(x: cropRegionInsets.left, y: cropRegionInsets.top + (maxCropRegion.size.height - cropBoxMinSize) / 2, width: maxCropRegion.size.width, height: cropBoxMinSize)
            matchScrollViewAndCropView()
        }

        defaultCropperState = saveState()

        angleRuler.value = 0
        toolbar.resetButton.isHidden = true
    }

    // Make angle in 0 - 360 degrees
    func standardizeAngle(_ angle: CGFloat) -> CGFloat {
        var angle = angle
        if angle >= 0, angle <= 2 * CGFloat.pi {
            return angle
        } else if angle < 0 {
            angle += 2 * CGFloat.pi

            return standardizeAngle(angle)
        } else {
            angle -= 2 * CGFloat.pi

            return standardizeAngle(angle)
        }
    }

    func autoHorizontalOrVerticalAngle(_ angle: CGFloat) -> CGFloat {
        var angle = angle
        angle = standardizeAngle(angle)

        let deviation: CGFloat = 0.017444444 // 1 * 3.14 / 180, sync with AngleRuler
        if abs(angle - 0) < deviation {
            angle = 0
        } else if abs(angle - CGFloat.pi / 2.0) < deviation {
            angle = CGFloat.pi / 2.0
        } else if abs(angle - CGFloat.pi) < deviation {
            angle = CGFloat.pi - 0.001 // Handling a iOS bug that causes problems with rotation animations
        } else if abs(angle - CGFloat.pi / 2.0 * 3) < deviation {
            angle = CGFloat.pi / 2.0 * 3
        } else if abs(angle - CGFloat.pi * 2) < deviation {
            angle = CGFloat.pi * 2
        }

        return angle
    }

    func scrollViewZoomScaleToBounds() -> CGFloat {
        let scaleW = scrollView.bounds.size.width / imageView.bounds.size.width
        let scaleH = scrollView.bounds.size.height / imageView.bounds.size.height
        return max(scaleW, scaleH)
    }

    func willSetScrollViewZoomScale(_ zoomScale: CGFloat) {
        if zoomScale > scrollView.maximumZoomScale {
            scrollView.maximumZoomScale = zoomScale
        }
        if zoomScale < scrollView.minimumZoomScale {
            scrollView.minimumZoomScale = zoomScale
        }
    }

    func photoTranslation() -> CGPoint {
        let rect = imageView.convert(imageView.bounds, to: view)
        let point = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        let zeroPoint = CGPoint(x: view.frame.width / 2, y: defaultCropBoxCenter.y)

        return CGPoint(x: point.x - zeroPoint.x, y: point.y - zeroPoint.y)
    }

    func nearestCropBoxEdgeForPoint(point: CGPoint) -> CropBoxEdge {
        var frame = overlay.cropBoxFrame

        frame = frame.insetBy(dx: -cropBoxHotArea / 2.0, dy: -cropBoxHotArea / 2.0)

        let topLeftRect = CGRect(origin: frame.origin, size: CGSize(width: cropBoxHotArea, height: cropBoxHotArea))

        if topLeftRect.contains(point) {
            return .topLeft
        }

        var topRightRect = topLeftRect
        topRightRect.origin.x = frame.maxX - cropBoxHotArea
        if topRightRect.contains(point) {
            return .topRight
        }

        var bottomLeftRect = topLeftRect
        bottomLeftRect.origin.y = frame.maxY - cropBoxHotArea
        if bottomLeftRect.contains(point) {
            return .bottomLeft
        }

        var bottomRightRect = topRightRect
        bottomRightRect.origin.y = bottomLeftRect.origin.y
        if bottomRightRect.contains(point) {
            return .bottomRight
        }

        let topRect = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: cropBoxHotArea))
        if topRect.contains(point) {
            return .top
        }

        var bottomRect = topRect
        bottomRect.origin.y = frame.maxY - cropBoxHotArea
        if bottomRect.contains(point) {
            return .bottom
        }

        let leftRect = CGRect(origin: frame.origin, size: CGSize(width: cropBoxHotArea, height: frame.height))
        if leftRect.contains(point) {
            return .left
        }

        var rightRect = leftRect
        rightRect.origin.x = frame.maxX - cropBoxHotArea
        if rightRect.contains(point) {
            return .right
        }

        return .none
    }

    static let overlayCropBoxFramePlaceholder: CGRect = .zero

    func matchScrollViewAndCropView(animated: Bool = false,
                                    targetCropBoxFrame: CGRect = overlayCropBoxFramePlaceholder,
                                    extraZoomScale: CGFloat = 1.0,
                                    blurLayerAnimated: Bool = false,
                                    animations: (() -> Void)? = nil,
                                    completion: (() -> Void)? = nil) {
        var targetCropBoxFrame = targetCropBoxFrame
        if targetCropBoxFrame.equalTo(CropperViewController.overlayCropBoxFramePlaceholder) {
            targetCropBoxFrame = overlay.cropBoxFrame
        }

        let scaleX = maxCropRegion.size.width / targetCropBoxFrame.size.width
        let scaleY = maxCropRegion.size.height / targetCropBoxFrame.size.height

        let scale = min(scaleX, scaleY)

        // calculate the new bounds of crop view
        let newCropBounds = CGRect(x: 0, y: 0, width: scale * targetCropBoxFrame.size.width, height: scale * targetCropBoxFrame.size.height)

        // calculate the new bounds of scroll view
        let rotatedRect = newCropBounds.applying(CGAffineTransform(rotationAngle: totalAngle))
        let width = rotatedRect.size.width
        let height = rotatedRect.size.height

        let cropBoxFrameBeforeZoom = targetCropBoxFrame

        let zoomRect = view.convert(cropBoxFrameBeforeZoom, to: imageView) // zoomRect is base on imageView when scrollView.zoomScale = 1
        let center = CGPoint(x: zoomRect.origin.x + zoomRect.size.width / 2, y: zoomRect.origin.y + zoomRect.size.height / 2)
        let normalizedCenter = CGPoint(x: center.x / (imageView.width / scrollView.zoomScale), y: center.y / (imageView.height / scrollView.zoomScale))

        UIView.animate(withDuration: animated ? 0.25 : 0, animations: {
            self.overlay.setCropBoxFrame(CGRect(center: self.defaultCropBoxCenter, size: newCropBounds.size), blurLayerAnimated: blurLayerAnimated)
            animations?()
            self.scrollView.bounds = CGRect(x: 0, y: 0, width: width, height: height)

            var zoomScale = scale * self.scrollView.zoomScale * extraZoomScale
            let scrollViewZoomScaleToBounds = self.scrollViewZoomScaleToBounds()
            if zoomScale < scrollViewZoomScaleToBounds { // Some are not image in the cropbox area
                zoomScale = scrollViewZoomScaleToBounds
            }
            if zoomScale > self.scrollView.maximumZoomScale { // Only rotate can make maximumZoomScale to get bigger
                zoomScale = self.scrollView.maximumZoomScale
            }
            self.willSetScrollViewZoomScale(zoomScale)

            self.scrollView.zoomScale = zoomScale

            let contentOffset = CGPoint(x: normalizedCenter.x * self.imageView.width - self.scrollView.bounds.size.width * 0.5,
                                        y: normalizedCenter.y * self.imageView.height - self.scrollView.bounds.size.height * 0.5)
            self.scrollView.contentOffset = self.safeContentOffsetForScrollView(contentOffset)
        }, completion: { _ in
            completion?()
        })

        manualZoomed = true
    }

    func safeContentOffsetForScrollView(_ contentOffset: CGPoint) -> CGPoint {
        var contentOffset = contentOffset
        contentOffset.x = max(contentOffset.x, 0)
        contentOffset.y = max(contentOffset.y, 0)

        if scrollView.contentSize.height - contentOffset.y <= scrollView.bounds.size.height {
            contentOffset.y = scrollView.contentSize.height - scrollView.bounds.size.height
        }

        if scrollView.contentSize.width - contentOffset.x <= scrollView.bounds.size.width {
            contentOffset.x = scrollView.contentSize.width - scrollView.bounds.size.width
        }

        return contentOffset
    }

    func safeCropBoxFrame(_ cropBoxFrame: CGRect) -> CGRect {
        var cropBoxFrame = cropBoxFrame
        // Upon init, sometimes the box size is still 0, which can result in CALayer issues
        if cropBoxFrame.size.width < .ulpOfOne || cropBoxFrame.size.height < .ulpOfOne {
            return CGRect(center: defaultCropBoxCenter, size: defaultCropBoxSize)
        }

        // clamp the cropping region to the inset boundaries of the screen
        let contentFrame = maxCropRegion
        let xOrigin = contentFrame.origin.x
        let xDelta = cropBoxFrame.origin.x - xOrigin
        cropBoxFrame.origin.x = max(cropBoxFrame.origin.x, xOrigin)
        if xDelta < -.ulpOfOne { // If we clamp the x value, ensure we compensate for the subsequent delta generated in the width (Or else, the box will keep growing)
            cropBoxFrame.size.width += xDelta
        }

        let yOrigin = contentFrame.origin.y
        let yDelta = cropBoxFrame.origin.y - yOrigin
        cropBoxFrame.origin.y = max(cropBoxFrame.origin.y, yOrigin)
        if yDelta < -.ulpOfOne {
            cropBoxFrame.size.height += yDelta
        }

        // given the clamped X/Y values, make sure we can't extend the crop box beyond the edge of the screen in the current state
        let maxWidth = (contentFrame.size.width + contentFrame.origin.x) - cropBoxFrame.origin.x
        cropBoxFrame.size.width = min(cropBoxFrame.size.width, maxWidth)

        let maxHeight = (contentFrame.size.height + contentFrame.origin.y) - cropBoxFrame.origin.y
        cropBoxFrame.size.height = min(cropBoxFrame.size.height, maxHeight)

        // Make sure we can't make the crop box too small
        cropBoxFrame.size.width = max(cropBoxFrame.size.width, cropBoxMinSize)
        cropBoxFrame.size.height = max(cropBoxFrame.size.height, cropBoxMinSize)

        return cropBoxFrame
    }

    func isCurrentlyInState(_ state: CropperState?) -> Bool {
        guard let state = state else { return false }
        let epsilon: CGFloat = 0.0001

        if state.viewFrame.isEqual(to: view.frame, accuracy: epsilon),
            state.angle.isEqual(to: totalAngle, accuracy: epsilon),
            state.rotationAngle.isEqual(to: rotationAngle, accuracy: epsilon),
            state.straightenAngle.isEqual(to: straightenAngle, accuracy: epsilon),
            state.flipAngle.isEqual(to: flipAngle, accuracy: epsilon),
            state.imageOrientationRawValue == imageView.image?.imageOrientation.rawValue ?? 0,
            state.scrollViewTransform.isEqual(to: scrollView.transform, accuracy: epsilon),
            state.scrollViewCenter.isEqual(to: scrollView.center, accuracy: epsilon),
            state.scrollViewBounds.isEqual(to: scrollView.bounds, accuracy: epsilon),
            state.scrollViewContentOffset.isEqual(to: scrollView.contentOffset, accuracy: epsilon),
            state.scrollViewMinimumZoomScale.isEqual(to: scrollView.minimumZoomScale, accuracy: epsilon),
            state.scrollViewMaximumZoomScale.isEqual(to: scrollView.maximumZoomScale, accuracy: epsilon),
            state.scrollViewZoomScale.isEqual(to: scrollView.zoomScale, accuracy: epsilon),
            state.cropBoxFrame.isEqual(to: overlay.cropBoxFrame, accuracy: epsilon),
            state.aspectRatioLocked == aspectRatioLocked,
            state.currentAspectRatio == currentAspectRatio,
            state.currentAspectRatioValue.isEqual(to: currentAspectRatioValue, accuracy: epsilon) {
            return true
        }

        return false
    }

    func updateCropBoxFrameWithPanGesturePoint(_ point: CGPoint) {
        var point = point
        var frame = overlay.cropBoxFrame
        let originFrame = panBeginningCropBoxFrame
        let contentFrame = maxCropRegion

        point.x = max(contentFrame.origin.x, point.x)
        point.y = max(contentFrame.origin.y, point.y)

        // The delta between where we first tapped, and where our finger is now
        var xDelta = (point.x - panBeginningPoint.x)
        var yDelta = (point.y - panBeginningPoint.y)

        let aspectRatio = currentAspectRatioValue

        var panHorizontal: Bool = false
        var panVertical: Bool = false

        switch panBeginningCropBoxEdge {
        case .left:
            frame.origin.x = originFrame.origin.x + xDelta
            frame.size.width = max(cropBoxMinSize, originFrame.size.width - xDelta)
            if aspectRatioLocked {
                panHorizontal = true
                xDelta = max(xDelta, 0)
                let scaleOrigin = CGPoint(x: originFrame.maxX, y: originFrame.midY)
                frame.size.height = frame.size.width / aspectRatio
                frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
            }

        case .right:
            if aspectRatioLocked {
                panHorizontal = true
                frame.size.width = max(cropBoxMinSize, originFrame.size.width + xDelta)
                frame.size.width = min(frame.size.width, contentFrame.size.height * aspectRatio)
                let scaleOrigin = CGPoint(x: originFrame.minX, y: originFrame.midY)
                frame.size.height = frame.size.width / aspectRatio
                frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
            } else {
                frame.size.width = originFrame.size.width + xDelta
            }

        case .bottom:
            if aspectRatioLocked {
                panVertical = true
                frame.size.height = max(cropBoxMinSize, originFrame.size.height + yDelta)
                frame.size.height = min(frame.size.height, contentFrame.size.width / aspectRatio)
                let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.minY)
                frame.size.width = frame.size.height * aspectRatio
                frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
            } else {
                frame.size.height = originFrame.size.height + yDelta
            }

        case .top:
            if aspectRatioLocked {
                panVertical = true
                yDelta = max(0, yDelta)
                frame.origin.y = originFrame.origin.y + yDelta
                frame.size.height = max(cropBoxMinSize, originFrame.size.height - yDelta)
                let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.maxY)
                frame.size.width = frame.size.height * aspectRatio
                frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
            } else {
                frame.origin.y = originFrame.origin.y + yDelta
                frame.size.height = originFrame.size.height - yDelta
            }

        case .topLeft:
            if aspectRatioLocked {
                xDelta = max(xDelta, 0)
                yDelta = max(yDelta, 0)

                var distance = CGPoint()
                distance.x = 1.0 - (xDelta / originFrame.width)
                distance.y = 1.0 - (yDelta / originFrame.height)

                let scale = (distance.x + distance.y) * 0.5

                frame.size.width = (originFrame.width * scale)
                frame.size.height = (originFrame.height * scale)
                frame.origin.x = originFrame.origin.x + (originFrame.width - frame.size.width)
                frame.origin.y = originFrame.origin.y + (originFrame.height - frame.size.height)

                panVertical = true
                panHorizontal = true
            } else {
                frame.origin.x = originFrame.origin.x + xDelta
                frame.size.width = originFrame.size.width - xDelta
                frame.origin.y = originFrame.origin.y + yDelta
                frame.size.height = originFrame.size.height - yDelta
            }

        case .topRight:
            if aspectRatioLocked {
                xDelta = max(xDelta, 0)
                yDelta = max(yDelta, 0)

                var distance = CGPoint()
                distance.x = 1.0 - ((-xDelta) / originFrame.width)
                distance.y = 1.0 - (yDelta / originFrame.height)

                var scale = (distance.x + distance.y) * 0.5
                scale = min(1.0, scale)

                frame.size.width = (originFrame.width * scale)
                frame.size.height = (originFrame.height * scale)
                frame.origin.y = originFrame.maxY - frame.size.height

                panVertical = true
                panHorizontal = true
            } else {
                frame.size.width = originFrame.size.width + xDelta
                frame.origin.y = originFrame.origin.y + yDelta
                frame.size.height = originFrame.size.height - yDelta
            }

        case .bottomLeft:
            if aspectRatioLocked {
                var distance = CGPoint()
                distance.x = 1.0 - (xDelta / originFrame.width)
                distance.y = 1.0 - (-yDelta / originFrame.height)

                let scale = (distance.x + distance.y) * 0.5

                frame.size.width = (originFrame.width * scale)
                frame.size.height = (originFrame.height * scale)
                frame.origin.x = originFrame.maxX - frame.size.width

                panVertical = true
                panHorizontal = true
            } else {
                frame.size.height = originFrame.size.height + yDelta
                frame.origin.x = originFrame.origin.x + xDelta
                frame.size.width = originFrame.size.width - xDelta
            }

        case .bottomRight:
            if aspectRatioLocked {
                var distance = CGPoint()
                distance.x = 1.0 - ((-1 * xDelta) / originFrame.width)
                distance.y = 1.0 - ((-1 * yDelta) / originFrame.height)

                let scale = (distance.x + distance.y) * 0.5

                frame.size.width = (originFrame.width * scale)
                frame.size.height = (originFrame.height * scale)

                panVertical = true
                panHorizontal = true
            } else {
                frame.size.height = originFrame.size.height + yDelta
                frame.size.width = originFrame.size.width + xDelta
            }

        case .none:
            break
        }

        // Work out the limits the box may be scaled before it starts to overlap itself
        var minSize: CGSize = .zero
        minSize.width = cropBoxMinSize
        minSize.height = cropBoxMinSize

        var maxSize: CGSize = .zero
        maxSize.width = contentFrame.width
        maxSize.height = contentFrame.height

        // clamp the box to ensure it doesn't go beyond the bounds we've set
        if aspectRatioLocked, panHorizontal {
            maxSize.height = contentFrame.size.width / aspectRatio
            if aspectRatio > 1 {
                minSize.width = cropBoxMinSize * aspectRatio
            } else {
                minSize.height = cropBoxMinSize / aspectRatio
            }
        }

        if aspectRatioLocked, panVertical {
            maxSize.width = contentFrame.size.height * aspectRatio
            if aspectRatio > 1 {
                minSize.width = cropBoxMinSize * aspectRatio
            } else {
                minSize.height = cropBoxMinSize / aspectRatio
            }
        }

        // Clamp the minimum size
        frame.size.width = max(frame.size.width, minSize.width)
        frame.size.height = max(frame.size.height, minSize.height)

        // Clamp the maximum size
        frame.size.width = min(frame.size.width, maxSize.width)
        frame.size.height = min(frame.size.height, maxSize.height)

        frame.origin.x = max(frame.origin.x, contentFrame.minX)
        frame.origin.x = min(frame.origin.x, contentFrame.maxX - minSize.width)
        frame.origin.x = min(frame.origin.x, originFrame.maxX - minSize.width) // Cannot pan the left side of the box out of the right area of the previous box

        frame.origin.y = max(frame.origin.y, contentFrame.minY)
        frame.origin.y = min(frame.origin.y, contentFrame.maxY - minSize.height)
        frame.origin.y = min(frame.origin.y, originFrame.maxY - minSize.height) // Cannot pan the top of the box out of the bottom area of the previous frame

        cropBoxFrame = frame
    }

    // MARK: Stasis

    // stasis like Zhonya's Hourglass.
    func stasisAndThenRun(_ closure: @escaping () -> Void) {
        cancelStasis()
        stasisTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(stasisOver), userInfo: nil, repeats: false)
        stasisThings = closure
    }

    func cancelStasis() {
        guard stasisTimer != nil else {
            return
        }
        stasisTimer?.invalidate()
        stasisTimer = nil
        stasisThings = nil
        view.isUserInteractionEnabled = true
    }

    @objc
    func stasisOver() {
        view.isUserInteractionEnabled = false
        if stasisThings != nil {
            stasisThings?()
        }
        cancelStasis()
    }
}

// MARK: UIScrollViewDelegate

extension CropperViewController: UIScrollViewDelegate {

    func viewForZooming(in _: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
        cancelStasis()
        overlay.blur = false
        overlay.gridLinesAlpha = 1
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
    }

    func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale _: CGFloat) {
        matchScrollViewAndCropView(animated: true, completion: {
            self.stasisAndThenRun {
                UIView.animate(withDuration: 0.25, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: { _ in
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
                })

                self.manualZoomed = true
            }
        })
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        cancelStasis()
        overlay.blur = false
        overlay.gridLinesAlpha = 1
        topBar.isUserInteractionEnabled = false
        bottomView.isUserInteractionEnabled = false
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            matchScrollViewAndCropView(animated: true, completion: {
                self.stasisAndThenRun {
                    UIView.animate(withDuration: 0.25, animations: {
                        self.overlay.gridLinesAlpha = 0
                        self.overlay.blur = true
                    }, completion: { _ in
                        self.topBar.isUserInteractionEnabled = true
                        self.bottomView.isUserInteractionEnabled = true
                        self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
                    })
                }
            })
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        matchScrollViewAndCropView(animated: true, completion: {
            self.stasisAndThenRun {
                UIView.animate(withDuration: 0.25, animations: {
                    self.overlay.gridLinesAlpha = 0
                    self.overlay.blur = true
                }, completion: { _ in
                    self.topBar.isUserInteractionEnabled = true
                    self.bottomView.isUserInteractionEnabled = true
                    self.toolbar.resetButton.isHidden = self.isCurrentlyInDefalutState
                })
            }
        })
    }
}

// MARK: UIGestureRecognizerDelegate

extension CropperViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == cropBoxPanGesture {
            let tapPoint = gestureRecognizer.location(in: view)

            let frame = overlay.cropBoxFrame

            let d = cropBoxHotArea / 2.0
            let innerFrame = frame.insetBy(dx: d, dy: d)
            let outerFrame = frame.insetBy(dx: -d, dy: -d)

            if innerFrame.contains(tapPoint) || !outerFrame.contains(tapPoint) {
                return false
            }
        }

        return true
    }
}

// MARK: AspectRatioPickerDelegate

extension CropperViewController {
    func setAspectRatio(_ aspectRatio: AspectRatio) {
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
}
