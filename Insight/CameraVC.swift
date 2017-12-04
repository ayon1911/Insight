//
//  CameraVC.swift
//  Insight
//
//  Created by Khaled Rahman Ayon on 04/12/2017.
//  Copyright © 2017 Khaled Rahman Ayon. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState {
    case off
    case on
}

class CameraVC: UIViewController {

    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var speechSynthesizer = AVSpeechSynthesizer()
    
    var photoData: Data?
    var flashControl: FlashState = .off
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var captureImageView: RoundedImageView!
    @IBOutlet weak var flashBtn: RoundedShadowBtn!
    @IBOutlet weak var scanneditemlbl: UILabel!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var roundedShadowView: RoundedShadowView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        spinner.isHidden = true
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
    }
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        tap.numberOfTapsRequired = 1
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) == true {
                captureSession.addInput(input)
            }
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) == true {
                captureSession.addOutput(cameraOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                cameraView.layer.addSublayer(previewLayer!)
                cameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
        } catch {
            debugPrint(error)
        }
    }
    
    @objc func didTapCameraView() {
        self.cameraView.isUserInteractionEnabled = false
        self.spinner.isHidden = false
        self.spinner.startAnimating()
        
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashControl == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resultMethods(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { return }
        for classification in results {
            if classification.confidence < 0.5 {
                let notFoundObjectMessage = "I am not sure what that is, please try again"
                self.scanneditemlbl.text = notFoundObjectMessage
                synthesizeSpeech(fromString: notFoundObjectMessage)
                self.confidenceLbl.text = ""
                break
            } else {
                let identifiedObjectMessage = classification.identifier
                let confidence = Int(classification.confidence * 100)
                let fullMessage = "This looks like a \(identifiedObjectMessage) and \(confidence) percent sure"
                self.scanneditemlbl.text = identifiedObjectMessage
                self.confidenceLbl.text = "CONFIDENCE: \(confidence)%"
                synthesizeSpeech(fromString: fullMessage)
                break
            }
        }
    }
    
    func synthesizeSpeech(fromString string: String) {
        let speechUtterence = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterence)
    }

    @IBAction func flashBtnPressed(_ sender: Any) {
        switch flashControl {
        case .off:
            flashBtn.setTitle("FLASH ON", for: .normal)
            flashControl = .on
        case .on:
            flashBtn.setTitle("FLASH OFF", for: .normal)
            flashControl = .off
        }
    }
}

extension CameraVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultMethods)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            self.captureImageView.image = image
        }
    }
}

extension CameraVC: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.cameraView.isUserInteractionEnabled = true
        self.spinner.isHidden = true
        self.spinner.stopAnimating()
    }
}




