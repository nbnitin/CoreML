//
//  LiveCheckViewController.swift
//  SampleML
//
//  Created by Nitin on 16/06/20.
//  Copyright © 2020 Nitin. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVKit

class LiveCheckViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var requests = [VNRequest]()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
       var rootLayer: CALayer! = nil

    var bufferSize : CGSize! = .zero
    var detectionOverlay : CALayer!
    
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var lblObject: UILabel!
    
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var lblConfidence: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        let captureSession = AVCaptureSession()
        
        captureSession.sessionPreset = .vga640x480 //to set session image size

        guard let captureDevice = AVCaptureDevice.default(for: .video) else {return}
        guard let input = (try? AVCaptureDeviceInput(device: captureDevice)) else {
            return
        }
        captureSession.addInput(input)
        captureSession.startRunning()
        let dimensions = CMVideoFormatDescriptionGetDimensions((captureDevice.activeFormat.formatDescription))
        bufferSize.width = CGFloat(dimensions.width)
        bufferSize.height = CGFloat(dimensions.height)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        rootLayer = cameraPreview.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        
        setupLayer()
        
        
        let dataOutput = AVCaptureVideoDataOutput()
         dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        captureSession.addOutput(dataOutput)
        dataOutput.alwaysDiscardsLateVideoFrames = true
       // infoView.layer.zPosition = 2 // to bring info view to top of camera preview else it will get hide
        updateLayerGeometry()
    }
    
    func setupLayer(){
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
        detectionOverlay.zPosition = 2
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        // let formatDescription: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
        // let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // let bufferSize: (width: Int, height: Int) = (CVPixelBufferGetHeight(imageBuffer), CVPixelBufferGetWidth(imageBuffer))
        
        
        
        
        guard let pixelBuffer : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        
        guard let model = try? VNCoreMLModel(for: ObjectDetector().model) else {return}
        let request = VNCoreMLRequest(model: model, completionHandler: {(request,error) in
            
            
            DispatchQueue.main.async(execute: {
                // perform all the UI updates on the main queue
                if let results = request.results {
                    self.drawVisionRequestResults(results)
                }
            })
            
            
            
            
        })
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: topLabelObservation.identifier,
                                                            confidence: topLabelObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
            print(shapeLayer)
        }
       self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func updateLayerGeometry() {
        let bounds = cameraPreview.layer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    
}
