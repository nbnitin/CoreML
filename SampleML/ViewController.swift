//
//  ViewController.swift
//  SampleML
//
//  Created by Nitin on 12/06/20.
//  Copyright © 2020 Nitin. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVKit

//We'll need AVKit because we'll be creating an AVCaptureSession to display a live feed while classifying images in real time. Also, since this is using computer vision, we'll need to import the Vision framework.

class ViewController: UIViewController,UINavigationControllerDelegate, UIImagePickerControllerDelegate  {
    
    //variable
    
    //these datas can get from mlmodel itself, single click on mlmodel and look for inputs -> image there will size written under prediciton
    var widthOfImageModelCanProcess = 224
    var heightOfImageModelCanProcess = 224
    var imagePicker = UIImagePickerController()
    
    
    @IBOutlet weak var imgFeed: UIImageView!
    
    @IBOutlet weak var lblImageName: UILabel!
    
    @IBOutlet weak var lblMatchValue: UILabel!
    
    @IBOutlet var img1: [UIImageView]!
    
    @IBOutlet weak var btnOpenGallery: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        for imgs in img1 {
            let gest = UITapGestureRecognizer(target: self, action: #selector(setImage(_:)))
            imgs.addGestureRecognizer(gest)
            imgs.isUserInteractionEnabled = true
        }
        btnOpenGallery.addTarget(self, action: #selector(btnOpenGalleryAction), for: .touchUpInside)
    }
    
    @objc func btnOpenGalleryAction(){
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            print("Button capture")
            
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            
            present(imagePicker, animated: true, completion: nil)
        }
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            imgFeed.image = pickedImage
            imagePicker.dismiss(animated: true, completion: nil)
            processImage()
        }
    }
    
    @objc func setImage(_ sender : UITapGestureRecognizer) {
        let img = sender.view as! UIImageView
        self.imgFeed.image = img.image
        processImage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        processImage()
    }
    
    func processImage(){
        let image = imgFeed.image
        recogniseImageMethod1(pixelBuffer: getBuffer(image: image!))
        //recognizeImageMethod2(pixelBuffer: getBuffer(image: image!))
    }
    
    //Mark:- converts image into buffer
    func getBuffer(image:UIImage)->CVPixelBuffer?{
        UIGraphicsBeginImageContextWithOptions(CGSize(width: widthOfImageModelCanProcess, height: widthOfImageModelCanProcess), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: widthOfImageModelCanProcess, height: widthOfImageModelCanProcess))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
        
        context?.translateBy(x: 0, y: newImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        //imageView.image = newImage
        
        return pixelBuffer
    }
    
    
    //Mark: this function only gives name of object
    func recognizeImageMethod2(pixelBuffer:CVPixelBuffer?){
        let model = MobileNetV2()
        guard let prediction = try? model.prediction(image: pixelBuffer!) else {
            return
        }
        lblImageName.text = prediction.classLabel
    }
    
    
    //Mark: this function help to know name of object also its value of confidence
    func recogniseImageMethod1(pixelBuffer:CVPixelBuffer?){
        guard let model1 = try? VNCoreMLModel(for: MobileNetV2().model) else { return }
        
        let request = VNCoreMLRequest(model: model1, completionHandler: { (vnrequest, error) in
            if let results = vnrequest.results as? [VNClassificationObservation] {
                let topResult = results.first
                DispatchQueue.main.async {
                    
                    self.lblImageName.text = topResult!.identifier.capitalized.components(separatedBy: ",").first
                    self.lblMatchValue.text = String(format: "%.2f", topResult!.confidence * 100) + "%"
                    
                }
            }
        })
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer!, options: .init())
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print("Err :(")
            }
        }
        
        
    }
}



