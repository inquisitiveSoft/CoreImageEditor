//
//  PreviewImageViewController.swift
//  PhotoEditor
//
//  Created by Harry Jordan 18/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit

// This preview view is just used to see the output image

class PreviewImageViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView?

    var image: UIImage? {
        didSet {
            imageView?.image = image
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        imageView?.image = image
    }

}
