//
//  ViewController.swift
//
//  Created by Chen Qizhi on 2019/10/15.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var originalImage: UIImage?
    var cropperState: CropperState?

    lazy var startButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: view.height - 200, width: view.width, height: 40))
        button.addTarget(self, action: #selector(startButtonPressed(_:)), for: .touchUpInside)
        button.setTitle("Start", for: .normal)
        return button
    }()

    lazy var reeditButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: view.height - 160, width: view.width, height: 40))
        button.addTarget(self, action: #selector(reeditButtonPressed(_:)), for: .touchUpInside)
        button.setTitle("Re-edit", for: .normal)
        return button
    }()

    lazy var imageView: UIImageView = {
        let iv = UIImageView(frame: CGRect(x: 0, y: 100, width: view.width, height: view.width))
        iv.layer.borderColor = UIColor.white.cgColor
        iv.layer.borderWidth = 1
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(imageView)
        view.addSubview(startButton)
        view.addSubview(reeditButton)
    }

    @objc
    func startButtonPressed(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    @objc
    func reeditButtonPressed(_ sender: UIButton) {
        if let image = originalImage, let state = cropperState {
            let cropper = CropperViewController(originalImage: image, initialState: state)
            cropper.delegate = self
            self.present(cropper, animated: true, completion: nil)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = (info[.originalImage] as? UIImage) else { return }

        self.originalImage = image

        let cropper = CropperViewController(originalImage: image)
        cropper.delegate = self

        picker.dismiss(animated: true) {
            self.present(cropper, animated: true, completion: nil)
        }
    }
}

extension ViewController: CropperViewControllerDelegate {
    func cropperDidConfirm(_ cropper: CropperViewController, state: CropperState?) {
        cropper.dismiss(animated: true, completion: nil)

        if let state = state,
            let image = cropper.originalImage.cropped(withCropperState: state) {

            self.cropperState = state
            imageView.image = image
            print(cropper.isCurrentlyInInitialState)
            print(image)
        }
    }
}
