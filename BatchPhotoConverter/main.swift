//
//  main.swift
//  PhotoEditor
//
//  Created by Harry Jordan 09/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import Foundation
import AppKit

let inputPathOption = StringOption(shortFlag: "i", longFlag: "input", required: true, helpMessage: "Input folder")
let outputPathOption = StringOption(shortFlag: "o", longFlag: "output", required: false, helpMessage: "Output folder")
let effectOption = DoubleOption(shortFlag: "e", longFlag: "effect", required: false, helpMessage: "Interpolation weighting")

let commandLine = CommandLine()
commandLine.addOptions([inputPathOption, outputPathOption, effectOption])

do {
    try commandLine.parse()

    guard let inputPath = inputPathOption.value,
        let outputPath = outputPathOption.value else {
            print("Couldn't load input \(String(describing: inputPathOption.value)), or output \(String(describing: outputPathOption.value))")
        exit(EX_IOERR)
    }

    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)

    let fileManager = FileManager()

    if !fileManager.fileExists(atPath: outputURL.path) {
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
    }


    guard let enumerator = fileManager.enumerator(at: inputURL, includingPropertiesForKeys: []) else {
        print("Couldn't create directory enumerator for \(inputURL)")
        exit(EX_IOERR)
    }


    let context = CIContext()
    var numberOfImages = 0

    for sourceImageURL in enumerator {
        guard let sourceImageURL = sourceImageURL as? URL,
            let imageSource = CGImageSourceCreateWithURL(sourceImageURL as CFURL, nil),
            let inputCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { continue }

        // Calculate auto enhancements
        let inputCIImage = CIImage(cgImage: inputCGImage)
        var filters = inputCIImage.autoEnhanceFilterDefinitions()
        let effectAmount = CGFloat(effectOption.value ?? 1.0)

        filters = filters.map { (filter) in
            return filter.interpolatedWithDefaultValue(effectAmount)
        }


        // Constructing destination image URLs
        let fileName = (sourceImageURL.lastPathComponent as NSString).deletingPathExtension

        var outputImageURL = outputURL
        outputImageURL = outputImageURL.appendingPathComponent(fileName + "-before.jpg")

        var inputImageURL = outputURL
        inputImageURL = inputImageURL.appendingPathComponent(fileName + "-after.jpg")


        // Remove existing files
        if fileManager.fileExists(atPath: outputImageURL.path) {
            try fileManager.removeItem(at: outputImageURL)
        }

        if fileManager.fileExists(atPath: outputImageURL.path) {
            try fileManager.removeItem(at: inputImageURL)
        }


        // Saving out the image
        let outputImage = inputCIImage.applying(filters: filters)

        if let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent),
            let imageDestination = CGImageDestinationCreateWithURL(outputImageURL as CFURL, kUTTypeJPEG, 0, nil) {
            CGImageDestinationAddImage(imageDestination, outputCGImage, nil)
            CGImageDestinationFinalize(imageDestination)


            // Copy the input image for easy comparison
            try fileManager.copyItem(at: sourceImageURL, to: inputImageURL)

            numberOfImages += 1
        } else {
            print("Couldn't write: \(outputImageURL)")
        }
    }

    print("Converted \(numberOfImages) images")
} catch let error {
    commandLine.printUsage(error)
    exit(EX_USAGE)
}
