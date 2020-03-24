//
//  ViewController.swift
//  Firebase Face Detection
//
//  Created by Sandrika on 3/18/20.
//  Copyright © 2020 Sandrika. All rights reserved.
//

import UIKit
import Firebase
import Vision

enum VisionEnum: Int {
    case none = 0
    case firebase = 1
    case apple = 2
    case ciDetector = 3
}

enum PhotoType {
    case camera
    case cameraRoll
}

class ViewController: UIViewController {
    
    // MARK: - IBOutlet
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var resultLbl: UILabel!
    @IBOutlet private weak var cameraBtn: UIButton!
    @IBOutlet private weak var switcher: UISwitch!
    @IBOutlet private weak var loaderView: UIView!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    
    // MARK: - Properties
    private let options = VisionFaceDetectorOptions()
    private lazy var vision = Vision.vision()
    private var visionEnum: VisionEnum = .none
    private var photoType: PhotoType = .camera
    private var imageHelper: ImageHelper?
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.screenUI()
        self.firebaseVisionCustomization()
        self.showHideLoader(show: false)
    }
    
    // MARK: - Custom Funcs
    private func screenUI() {
        self.cameraBtn.layer.cornerRadius = self.cameraBtn.frame.size.width / 2
        self.spinner.hidesWhenStopped = true
    }
    
    private func firebaseVisionCustomization() {
        self.resultLbl.isHidden = true
        self.options.performanceMode = .accurate
        self.options.landmarkMode = .all
        self.options.classificationMode = .all
        self.options.contourMode = .all
    }
    
    private func showHideLoader(show: Bool) {
        show ? self.spinner.startAnimating() : self.spinner.stopAnimating()
        UIView.animate(withDuration: 0.2) {
            self.loaderView.alpha = show ? 0.7 : 0.0
        }
    }
    
    private func createFaceOutline(for rectangle: CGRect){
        let yellowView = UIView()
        yellowView.backgroundColor = .clear
        yellowView.layer.borderWidth = 3
        yellowView.layer.borderColor = UIColor.yellow.cgColor
        yellowView.layer.cornerRadius = 5
        yellowView.alpha = 0.0
        yellowView.frame = rectangle
        yellowView.tag = 232323
        self.view.addSubview(yellowView)
        
        UIView.animate(withDuration: 0.3) {
            yellowView.alpha = 0.75
            self.spinner.alpha = 0.0
        }        
    }
    
    private func detectImage(image: UIImage) {
        self.showHideLoader(show: true)
        if self.visionEnum == .apple {
            guard let cgImage = image.removeRotationForImage().cgImage else {
                return
            }
            let scaledHeight = (view.frame.width / image.size.width) * image.size.height
            DispatchQueue.global(qos: .background).async {
                self.imageHelper?.performVisionRequest(for: cgImage, with: scaledHeight, completion: { [weak self] completed, cgImage in
                    self?.showHideLoader(show: false)
                    self?.imageHelper = nil
                    guard completed, let cgImage = cgImage else { return }
                    self?.imageView.image = UIImage(cgImage: cgImage)
                })
            }
        } else if self.visionEnum == .firebase {
            self.imageHelper?.detectImageWithFirebaseVision(with: image, options: self.options, completion: { [weak self] completed, faces in
                self?.imageHelper = nil
                self?.showHideLoader(show: false)
                guard completed, let faces = faces else {
                    self?.dismiss(animated: true, completion: nil)
                    self?.resultLbl.text = "No Face Detected"
                    return
                }
                faces.forEach({ face in
                    DispatchQueue.main.async {
                        guard let transform = self?.transformMatrix() else { return }
                        let transformedRect = face.frame.applying(transform)
//                        guard let cgImage = self?.cropImage(faceRectangle: transformedRect, cgImage: image.cgImage!) else {
//                            return
//                        }
//                        self?.imageView.image = UIImage(cgImage: cgImage)
                        let yellowView = UIView(frame: transformedRect)
                        yellowView.backgroundColor = .yellow
                        yellowView.layer.borderWidth = 3
//                        yellowView.layer.borderColor = UIColor.yellow.cgColor
                        yellowView.layer.cornerRadius = 5
//                        yellowView.alpha = 0.0
//                        yellowView.frame = transformedRect
                        yellowView.tag = 232323
                        self?.imageView.addSubview(yellowView)

                        UIView.animate(withDuration: 0.3) {
                            yellowView.alpha = 0.75
                            self?.spinner.alpha = 0.0
                        }
                    }
                })
            })
        } else {
            let detectedFaces = self.imageHelper?.detectFaceWithCiDetector(from: image.removeRotationForImage())
            self.showHideLoader(show: false)
            self.imageHelper = nil
            if detectedFaces?.count != 0 {
                self.imageView.image = detectedFaces?.first
            }
        }
    }
    
    private func transformMatrix() -> CGAffineTransform {
       guard let image = imageView.image else { return CGAffineTransform() }
       let imageViewWidth = imageView.frame.size.width
       let imageViewHeight = imageView.frame.size.height
       let imageWidth = image.size.width
       let imageHeight = image.size.height

       let imageViewAspectRatio = imageViewWidth / imageViewHeight
       let imageAspectRatio = imageWidth / imageHeight
       let scale = (imageViewAspectRatio > imageAspectRatio)
         ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

       // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
       // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
       let scaledImageWidth = imageWidth * scale
       let scaledImageHeight = imageHeight * scale
       let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
       let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

       var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
       transform = transform.scaledBy(x: scale, y: scale)
       return transform
     }
    
    private func showSimpleActionSheet(controller: UIViewController) {
        if self.imageHelper == nil {
            self.imageHelper = ImageHelper()
        }
        let alert = UIAlertController(title: nil, message: "Select Face Detection", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Apple Vision", style: .default, handler: { [weak self] _ in
            self?.visionEnum = .apple
            self?.photoType == .camera ? self?.loadLibraryOrCamera(with: .camera) : self?.loadLibraryOrCamera(with: .photoLibrary)
        }))
        alert.addAction(UIAlertAction(title: "Firebase Vision", style: .default, handler: { [weak self] _  in
            self?.visionEnum = .firebase
            self?.photoType == .camera ? self?.loadLibraryOrCamera(with: .camera) : self?.loadLibraryOrCamera(with: .photoLibrary)
        }))
        alert.addAction(UIAlertAction(title: "Simple Face detector", style: .default, handler: { [weak self] _  in
            self?.visionEnum = .ciDetector
            self?.photoType == .camera ? self?.loadLibraryOrCamera(with: .camera) : self?.loadLibraryOrCamera(with: .photoLibrary)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _  in
            self?.visionEnum = .none
        }))
        self.present(alert, animated: true, completion: {
            print("completion block")
        })
    }

    private func loadLibraryOrCamera(with sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            return
        }
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self;
        myPickerController.sourceType = sourceType
        self.present(myPickerController, animated: true, completion: nil)
    }
    
    private func cropImage(faceRectangle: CGRect, cgImage: CGImage) -> CGImage? {
        let width = faceRectangle.width * CGFloat(cgImage.width)
        let height = faceRectangle.height * CGFloat(cgImage.height)
        let x = faceRectangle.origin.x * CGFloat(cgImage.width)
        let y = (1 - faceRectangle.origin.y) * CGFloat(cgImage.height) - height
        
        let croppingRect = CGRect(x: faceRectangle.origin.x, y: faceRectangle.origin.y, width: 400, height: 400)
        let image = cgImage.cropping(to: croppingRect)
        return image
    }
    
    // MARK: - IBAction
    @IBAction func cameraBtn(_ sender: Any) {
        self.showSimpleActionSheet(controller: self)
    }
    
    @IBAction func switcherAction(_ sender: UISwitch) {
        if sender.isOn {
            self.photoType = .camera
            self.cameraBtn.setTitle("Camera", for: .normal)
        } else {
            self.photoType = .cameraRoll
            self.cameraBtn.setTitle("Camera Roll", for: .normal)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate && UINavigationControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        for subview in self.imageView.subviews {
            if subview.tag == 232323 {
                subview.removeFromSuperview()
            }
        }
        let image = info[.originalImage] as! UIImage
        let width = self.view.frame.width
        let scaledHeight = width / image.size.width * image.size.height
        self.imageView.frame = CGRect(x: 0, y: 0, width: width, height: scaledHeight)
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.imageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.imageView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            self.imageView.widthAnchor.constraint(equalToConstant: width),
            self.imageView.heightAnchor.constraint(equalToConstant: scaledHeight),
        ])
        self.view.layoutIfNeeded()
        self.imageView.image = image
        self.detectImage(image: image)
        self.dismiss(animated: true, completion: nil)
    }
}

