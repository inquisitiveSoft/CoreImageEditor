//
//  ExamplePhotoEditorViewController.swift
//  PhotoEditor
//
//  Created by Harry Jordan 05/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import Photos
import PhotoEditor


let CurrentFilterSetKey = "CurrentEffectKey"
let PreviewSegue = "PreviewSegue"

class ExamplePhotoEditorViewController: UIViewController {
    lazy var photoPickerController = UIImagePickerController()

    // MARK: Content

    var image: CIImage {
        didSet {
            didUpdateImage()
        }
    }

    var info: [String: Any] = [:]


    // MARK: UI Elements

    @IBOutlet var imageView: CoreImageView!


    init(image: UIImage, info: [String : Any]) {
        self.image = CIImage(image: image)!
        self.info = info

        super.init(nibName: nil, bundle: nil)
    }


    init(ciImage: CIImage) {
        self.image = ciImage
        super.init(nibName: nil, bundle: nil)
    }


    required init?(coder aDecoder: NSCoder) {
        self.image = CIImage(image: UIImage(named: "001")!, options: [:])!
        super.init(coder: aDecoder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        let padding: CGFloat = 20.0
        imageView.contentEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        imageView.targetAspectRatio = AspectRatio(width: 3, height: 2)
        imageView.backgroundColor = .gray
        imageView.borderColor = .lightGray
        imageView.overlayView = ExamplePhotoGridOverlayView()

        didUpdateImage()

        let resetGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resetTransform(_:)))
        resetGestureRecognizer.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(resetGestureRecognizer)
    }

    // MARK: Filters

    var autoEnhanceFilters: [FilterDefinition] = []

    var effectAmount: CGFloat = 1.0 {
        didSet {
            updateFilters()
        }
    }

    func didUpdateImage() {
        imageView.setImage(image)
        autoEnhanceFilters = image.autoEnhanceFilterDefinitions()
    }

    @IBOutlet weak var effectSlider: UISlider!

    var currentFilterEffect: FilterEffect = .enhance {
        didSet {
            updateFilters()
        }
    }

    func updateFilters() {
        let filters = currentFilterEffect.filters(for: effectAmount, autoEnhanceFilters: autoEnhanceFilters)
        imageView.filters = filters
        effectNameLabel.text = currentFilterEffect.name
    }

    // MARK: User Interface

    @IBOutlet weak var effectNameLabel: UILabel!
    @IBOutlet weak var effectAmountLabel: UILabel!

    // MARK: Handling actions

    @IBAction func selectPhoto(_ sender: Any) {
        presentPhotoPicker()
    }

    @IBAction func effectSliderDidChange(_ slider: UISlider) {
        effectAmount = CGFloat(slider.value)
    }

    @IBAction func rotateClockwise(_ sender: Any) {
        imageView.rotateClockwise()
    }

    @IBAction func rotateCounterClockwise(_ sender: Any) {
        imageView.rotateCounterClockwise()
    }

    @IBAction func resetTransform(_ sender: Any) {
        imageView.resetTransform(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let outputImage = try? UIImage(ciImage: image,
                                       filters: imageView.filters,
                                       desiredAspectRatio: imageView.targetAspectRatio,
                                       maximumDimensions: imageView.initialSize(for: image.extent.size),
                                       transform: imageView.imageTransform)

        if let outputImage = outputImage,
            let destination = segue.destination as? PreviewImageViewController {

            print("Created image: \(outputImage)")
            destination.image = outputImage
        }
    }

}

extension ExamplePhotoEditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func presentPhotoPicker() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            photoPickerController.delegate = self
            photoPickerController.modalPresentationStyle = .currentContext

            present(photoPickerController, animated: true)
        } else {
            // Present an alert
            let alertController = UIAlertController(title: "Unable to access Photo Library", message: "-", preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "OK", style: .default, handler: { (action) in
                alertController.dismiss(animated: true, completion: nil)
            })

            alertController.addAction(dismissAction)

            present(alertController, animated: true)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError()
        }

        self.image = CIImage(image: image)!
        self.info = info

        picker.dismiss(animated: true)
    }

}
