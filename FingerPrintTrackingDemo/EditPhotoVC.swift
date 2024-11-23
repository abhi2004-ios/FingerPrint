//
//  EditPhotoVC.swift
//  FingerPrintTrackingDemo
//
//  Created by DREAMWORLD on 19/11/24.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML

class EditPhotoVC: UIViewController {

    @IBOutlet weak var vwBGimgEdit: UIView!
    @IBOutlet weak var imgEditHeight: NSLayoutConstraint!
    @IBOutlet weak var imgEditWidth: NSLayoutConstraint!
    @IBOutlet weak var imgEditImage: UIImageView!

    var cropView: CropAreaView?
    var cropViewX = 0.0
    var cropViewY = 0.0
    var cropViewHeight = 0.0
    var cropViewWidth = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupUI()
    }

    func setupUI() {

        self.title = "Edit Photooo"
        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(btnAddAction(_:))),
            UIBarButtonItem(title: "Apply", style: .plain, target: self, action: #selector(btnApplyAction(_:)))
        ]

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(btnSaveAction(_:)))

    }

    @objc func btnAddAction(_ sender: UIBarButtonItem) {
        self.openPhotoLibrary()
    }

    @objc func btnApplyAction(_ sender: UIBarButtonItem) {
        self.removeBackground()
    }

    @objc func btnSaveAction(_ sender: UIBarButtonItem) {
        self.saveImageToDevice()
    }

    func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }

    func removeBackground() {
        guard let image = self.imgEditImage.image else { return }
        guard let inputImage = CIImage(image: image ) else {
            print("Failed to create CIImage")
            return
        }

        Task {
            guard let maskImage = createMask(from: inputImage) else {
                print("Failed to create mask")
                return
            }

            let outputImage = applyMask(mask: maskImage, to: inputImage)
            let finalImage = convertToUIImage(ciImage: outputImage)

            self.imgEditImage.image = finalImage
        }
    }

    func createMask(from inputImage: CIImage) -> CIImage? {

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: inputImage)

        do {
            try handler.perform([request])

            if let result = request.results?.first {
                let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                return CIImage(cvPixelBuffer: mask)
            }
        } catch {
            print(error)
        }

        return nil
    }

    func applyMask(mask: CIImage, to image: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()

        filter.inputImage = image
        filter.maskImage = mask
        filter.backgroundImage = CIImage.empty()

        return filter.outputImage!
    }

    func convertToUIImage(ciImage: CIImage) -> UIImage {
        guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent) else {
            fatalError("Failed to render CGImage")
        }

        return UIImage(cgImage: cgImage)
    }

    func saveImageToDevice() {
        guard let image = self.imgEditImage.image else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

}

extension EditPhotoVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            self.imgEditImage.image = selectedImage

            // Get the dimensions of the selected image
            let imageWidth = selectedImage.size.width
            let imageHeight = selectedImage.size.height
            let aspectRatio = imageWidth / imageHeight

            // Get the dimensions of vwBGimgEdit
            let containerWidth = vwBGimgEdit.frame.width
            let containerHeight = vwBGimgEdit.frame.height
            let containerAspectRatio = containerWidth / containerHeight

            // Adjust width and height of imgEditImage to fit within vwBGimgEdit
            if aspectRatio > containerAspectRatio {
                // Image is wider than container, scale based on width
                self.imgEditWidth.constant = containerWidth
                self.imgEditHeight.constant = containerWidth / aspectRatio
            } else {
                // Image is taller than container, scale based on height
                self.imgEditHeight.constant = containerHeight
                self.imgEditWidth.constant = containerHeight * aspectRatio
            }

            // Update the layout
            view.layoutIfNeeded()

            self.addCropView()
        }
        picker.dismiss(animated: true, completion: nil)
    }
}

//MARK: - Cropview
extension EditPhotoVC {

    func addCropView() {
        self.cropView?.removeFromSuperview()
        self.view.layoutIfNeeded()

        cropViewX = 0
        cropViewY = 0
        cropViewHeight = self.imgEditImage.bounds.height
        cropViewWidth = self.imgEditImage.bounds.width
        self.cropView = CropAreaView(frame: CGRect(x: cropViewX, y: cropViewY, width: cropViewWidth, height: cropViewHeight))
        self.cropView?.isUserInteractionEnabled = true
        self.imgEditImage.addSubview(self.cropView!)

        self.cropView?.btnTopLeftCorner.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:))))
        self.cropView?.btnTopRightCorner.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:))))
        self.cropView?.btnBottomLeftCorner.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:))))
        self.cropView?.btnBottomRightCorner.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:))))
    }

    @objc func panGestureAction(_ sender: UIPanGestureRecognizer) {
        guard let button = sender.view as? UIButton else { return }

        let translation = sender.translation(in: self.imgEditImage)
        let imgHeight = self.imgEditImage.bounds.height
        let imgWidht = self.imgEditImage.bounds.width

        if sender.state == .began {

        } else if sender.state == .changed {
            if button == cropView?.btnTopLeftCorner {
                let x = imgWidht - (cropViewX + translation.x) > imgWidht ? 0 : cropViewX + translation.x
                let y = imgHeight - (cropViewY + translation.y) > imgHeight ? 0 : cropViewY + translation.y
                cropViewHeight = imgHeight - y
                cropViewWidth = imgWidht - x
                self.cropView?.frame = CGRect(x: x, y: y, width: cropViewWidth, height: cropViewHeight)
                self.view.layoutIfNeeded()
            } else if button == cropView?.btnBottomLeftCorner {
                let x = imgWidht - (cropViewX + translation.x) > imgWidht ? 0 : cropViewX + translation.x
                let y = imgHeight - (cropViewY + translation.y) > imgHeight ? 0 : cropViewY + translation.y
                cropViewHeight = imgHeight - y
                cropViewWidth = imgWidht - x
                self.cropView?.frame = CGRect(x: x, y: y, width: cropViewWidth - translation.x, height: cropViewHeight - translation.x)
                self.view.layoutIfNeeded()
            }
        } else if sender.state == .ended {
            cropViewX += translation.x
            cropViewY += translation.y
            cropViewHeight = imgHeight - cropViewX
            cropViewWidth = imgWidht - cropViewY
        }
    }
}
