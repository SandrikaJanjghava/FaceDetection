//
//  Extensions.swift
//  Firebase Face Detection
//
//  Created by Sandrika on 3/19/20.
//  Copyright © 2020 Sandrika. All rights reserved.
//

import UIKit

struct Constants {
    static let screenFactor = UIScreen.main.bounds.width / 375.0
}

extension NSLayoutConstraint {
    @IBInspectable var shouldAdjustConstantToFitDevice : Bool { get { return false } set { if(newValue) { self.constant *= Constants.screenFactor } } }
}

extension UIImage {
    func removeRotationForImage() -> UIImage {
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: self.size))
        let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}
