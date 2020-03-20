//
//  ImageHelper.swift
//  Firebase Face Detection
//
//  Created by Sandrika on 3/19/20.
//  Copyright © 2020 Sandrika. All rights reserved.
//

import Foundation
import Firebase
import Vision

class ImageHelper {
    
    deinit {
        print("deinit happend ImageHelper")
    }
    
    var vision = Vision.vision()
    
    func detectImageWithFirebaseVision(with image: UIImage, options: VisionFaceDetectorOptions, completion: @escaping (Bool, [VisionFace]?) -> Void) {
        let faceDetector = self.vision.faceDetector(options: options)
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = self.visionImageOrientation(from: image.imageOrientation)
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces, !faces.isEmpty else {
                completion(false, nil)
                return
            }
            completion(true, faces)
        }
    }
    
    func detectFaceWithCiDetector(from image: UIImage) -> [UIImage] {
        guard let ciimage = CIImage(image: image) else { return [] }
        var orientation: NSNumber {
            switch image.imageOrientation {
            case .up:            return 1
            case .upMirrored:    return 2
            case .down:          return 3
            case .downMirrored:  return 4
            case .leftMirrored:  return 5
            case .right:         return 6
            case .rightMirrored: return 7
            case .left:          return 8
            @unknown default:
                fatalError()
            }
        }
        return CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])?
            .features(in: ciimage, options: [CIDetectorImageOrientation: orientation])
            .compactMap {
                let rect = $0.bounds.insetBy(dx: 0, dy: 0)
                let ciimage = ciimage.cropped(to: rect)
                UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
                defer { UIGraphicsEndImageContext() }
                UIImage(ciImage: ciimage).draw(in: CGRect(origin: .zero, size: rect.size))
                guard let face = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
                let size = face.size
                let breadth = min(size.width, size.height)
                let breadthSize = CGSize(width: breadth, height: breadth)
                UIGraphicsBeginImageContextWithOptions(breadthSize, false, image.scale)
                defer { UIGraphicsEndImageContext() }
                guard let cgImage = face.cgImage?.cropping(to: CGRect(origin:
                    
                    CGPoint(x: size.width > size.height ? (size.width - size.height).rounded(.down).remainder(dividingBy: 1) : 0,
                            y: size.height > size.width ? (size.height - size.width).rounded(.down).remainder(dividingBy: 1) : 0),
                                                                      size: breadthSize)) else { return nil }
                let faceRect = CGRect(origin: .zero, size: CGSize(width: min(size.width, size.height), height: min(size.width, size.height)))
                UIImage(cgImage: cgImage).draw(in: faceRect)
                return UIGraphicsGetImageFromCurrentImageContext()
            } ?? []
    }
    
    func performVisionRequest(for image: CGImage, with scaleHeight: CGFloat, completion: @escaping (Bool, CGImage?) -> Void) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard error == nil else {
                completion(false, nil)
                return
            }
            DispatchQueue.main.async {
                let faceImages = request.results?.map({ result -> CGImage? in
                    guard let face = result as? VNFaceObservation else { return nil }
                    let faceImage = self?.cropImage(object: face, cgImage: image)
                    return faceImage
                }).compactMap { $0 }
                guard let result = faceImages, result.count > 0 else {
                    completion(false, nil)
                    return
                }
                completion(true, faceImages?.first)
            }
        }
        let imageRequestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
            print("Faild to perform image request: ", error.localizedDescription)
            return
        }
    }
    
    private func cropImage(object: VNDetectedObjectObservation, cgImage: CGImage) -> CGImage? {
        let width = object.boundingBox.width * CGFloat(cgImage.width)
        let height = object.boundingBox.height * CGFloat(cgImage.height)
        let x = object.boundingBox.origin.x * CGFloat(cgImage.width)
        let y = (1 - object.boundingBox.origin.y) * CGFloat(cgImage.height) - height
        
        let croppingRect = CGRect(x: x, y: y, width: width, height: height)
        let image = cgImage.cropping(to: croppingRect)
        return image
    }
    
    private func visionImageOrientation(from imageOrientation: UIImage.Orientation) -> VisionDetectorImageOrientation {
        switch imageOrientation {
        case .up:
            return .topLeft
        case .down:
            return .bottomRight
        case .left:
            return .leftBottom
        case .right:
            return .rightTop
        case .upMirrored:
            return .topRight
        case .downMirrored:
            return .bottomLeft
        case .leftMirrored:
            return .leftTop
        case .rightMirrored:
            return .rightBottom
        @unknown default:
            fatalError()
        }
    }
}
