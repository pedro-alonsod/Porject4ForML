//
//  ViewController.swift
//  Porject4ForML
//
//  Created by Pedro Alonso on 4/9/18.
//  Copyright © 2018 Pedro Alonso. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVFoundation
import AVKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate  {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var lbDescription: UILabel!
    @IBOutlet weak var videoLayer: UIView!
    
    var cameraOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var captureSession : AVCaptureSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        detectImageContent()
    }
    
    func detectImageContent() {
        
        lbDescription.text = "Learning..."
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else {
            fatalError("CoreML error")
        }
        let request = VNCoreMLRequest(model: model, completionHandler: {
            
            [weak self] (_ request, error) in
 
//            let handler = VNImageRequestHandler(
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else { fatalError("Unexpected results") }
            
            DispatchQueue.main.async {
                [weak self] in
                self?.lbDescription.text = "\(topResult.identifier) \(topResult.confidence * 100) % confidence \n"
                
                for i in 0..<10 {
                    self?.lbDescription.text! += "\(results[i].identifier) - confidence \(results[i].confidence) \n "
                }
            }
        })
        guard let ciImage = CIImage(image: (self.imageView.image!)) else {
            fatalError("cannot create ciimage")
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        DispatchQueue.global().async {
            do {
                try handler.perform([request])
            } catch let error {
                print(error)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func btnTakePictureTapped(_ sender: UIButton) {
        imageView.isHidden = false
        videoLayer.isHidden = true
        
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker =  UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    @IBAction func btnPicImageTapped(_ sender: UIButton) {
        imageView.isHidden = false
        videoLayer.isHidden = true
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker =  UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            imagePicker.allowsEditing = true
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    @IBAction func grabVideoTapped(_ sender: UIButton) {
        imageView.isHidden = true
        videoLayer.isHidden = false
        useCamera()
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.contentMode = .scaleToFill
            imageView.image = pickedImage
            
        }
        detectImageContent()
//
        picker.dismiss(animated: true, completion: nil)
    }
    func useCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        if let input = try? AVCaptureDeviceInput(device: device!) {
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(cameraOutput)) {
                    captureSession.addOutput(cameraOutput)
                }
                previewLayer = AVCaptureVideoPreviewLayer(session:
                    captureSession)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                previewLayer.anchorPoint = videoLayer.bounds.origin
                previewLayer.frame = CGRect(x: videoLayer.bounds.origin.x, y: videoLayer.bounds.origin.y, width: videoLayer.frame.size.width, height: videoLayer.frame.size.height)
//                videoLayer.addSubview(previewLayer)
                //                previewLayer.
                videoLayer.layer.addSublayer(previewLayer)
                captureSession.startRunning()
            } else {
                print ("Could not get any input")
            }
        } else {
            print ("No video feed available")
        }
        recognizeImage()
    }
    
    @objc func recognizeImage() {
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print ("Error code: \(error.localizedDescription)")
        }
        if let imageData = photo.fileDataRepresentation(), let image =
            UIImage(data: imageData) {
            predictItem(image: image)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in:
            .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func predictItem(image: UIImage) {
        if let data = UIImagePNGRepresentation(image) {
            let fileName = getDocumentsDirectory().appendingPathComponent("image.png")
            try? data.write(to: fileName)
            let modelFile = Resnet50()
            let model = try! VNCoreMLModel(for: modelFile.model)
            let request = VNCoreMLRequest(model: model, completionHandler:
                finalGuess)
            let handler = VNImageRequestHandler(url: fileName)
            try! handler.perform([request])
        }
    }
    
    func finalGuess(request: VNRequest, error: Error?) {
        guard let results = request.results as?
            [VNClassificationObservation] else {
                fatalError("Unable to get a prediction")
        }
        var bestGuess = ""
        var confidence: VNConfidence = 0
        for classification in results {
            if classification.confidence > confidence {
                confidence = classification.confidence
                bestGuess = classification.identifier
            } }
        self.lbDescription.text = bestGuess + "\n"
        for i in 0..<10 {
            self.lbDescription.text! += "\(results[i].identifier), "
        }
        Timer.scheduledTimer(timeInterval: 5.0, target: self, selector:
            #selector(self.recognizeImage), userInfo: nil, repeats: false)
    }
    
//    func useCamera() {
//        captureSession = AVCaptureSession()
//        captureSession.sessionPreset = AVCaptureSession.Preset.photo
//        cameraOutput = AVCapturePhotoOutput()
//        let device = AVCaptureDevice.default(for: AVMediaType.video)
//        if let input = try? AVCaptureDeviceInput(device: device!) {
//            if (captureSession.canAddInput(input)) {
//                captureSession.addInput(input)
//                if (captureSession.canAddOutput(cameraOutput)) {
//                    captureSession.addOutput(cameraOutput)
//                }
//                previewLayer = AVCaptureVideoPreviewLayer(session:
//                    captureSession)
//                previewLayer.videoGravity = AVLayerVideoGravity.resize
//                previewLayer.frame = videoFeed.frame
//                //                previewLayer.
//                videoFeed.layer.addSublayer(previewLayer)
//                captureSession.startRunning()
//            } else {
//                print ("Could not get any input")
//            }
//        } else {
//            print ("No video feed available")
//        }
//        recognizeImage()
//    }

}

