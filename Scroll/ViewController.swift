//
//  ViewController.swift
//  Scroll
//
//  Created by Jeff Chimney on 2017-09-07.
//  Copyright © 2017 Jeff Chimney. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    var session: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    var requests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
//        let ciImageWithOrientation = ciImage.applyingOrientation(Int32(UIImageOrientation.leftMirrored.rawValue))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) ==  AVAuthorizationStatus.authorized
        {
            // Already Authorized
            imageView.isHidden = false
            setUpCamera()
        }
        else
        {
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted :Bool) -> Void in
                if granted == true
                {
                    // User granted
                    DispatchQueue.main.async {
                        self.imageView.isHidden = false
                        self.setUpCamera()
                    }
                }
                else
                {
                    // User Rejected
                    DispatchQueue.main.async {
                        self.imageView.isHidden = true
                    }
                }
            });
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let detectFaceRequest: VNDetectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleFaces)
        self.requests = [detectFaceRequest]
        
        guard let cgImage = (imageView.image?.cgImage!) else {
            return
        }
        let detectFaceRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try detectFaceRequestHandler.perform([detectFaceRequest])
        } catch {
            print(error)
        }
    }
    
    func handleFaces(request: VNRequest, error: Error?) {
        if let error = error {
            print("Couldnt detect faces")
            return
        }
        
        request.results?.forEach({(res) in
            print(res)
            
            guard let faceObservation = res as? VNFaceObservation else {return}
            
            DispatchQueue.main.async() {
                self.imageView.layer.sublayers?.removeSubrange(1...)
                
                self.highlightFace(box: faceObservation)
            }
            
            print(faceObservation.boundingBox)
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setUpCamera() {
        //if !imagePicked {
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.photo
        
        let videoDevices = AVCaptureDevice.devices(for: AVMediaType.video)
        var captureDevice:AVCaptureDevice?
        
        for device in videoDevices{
            let device = device as AVCaptureDevice
            if device.position == AVCaptureDevice.Position.front {
                captureDevice = device
                break
            }
        }
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: captureDevice!)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        if error == nil && session!.canAddInput(input) {
            //2
            let deviceOutput = AVCaptureVideoDataOutput()
            deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            deviceOutput.setSampleBufferDelegate(self as! AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
            session?.addInput(input)
            session?.addOutput(deviceOutput)
            
            //3
            let imageLayer = AVCaptureVideoPreviewLayer(session: session!)
            imageLayer.frame = imageView.bounds
            imageView.layer.addSublayer(imageLayer)
            
            session?.startRunning()
        }
    }
    
    func highlightFace(box: VNFaceObservation) {
        let boundingBox = box.boundingBox
        
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        
        if boundingBox.maxX < maxX {
            maxX = boundingBox.maxX
        }
        if boundingBox.minX > minX {
            minX = boundingBox.minX
        }
        if boundingBox.maxY < maxY {
            maxY = boundingBox.maxY
        }
        if boundingBox.minY > minY {
            minY = boundingBox.minY
        }
        
        let xCord = (1-minX) * imageView.frame.size.width
        let yCord = (1 - minY) * imageView.frame.size.height
        let width = (minX - maxX) * imageView.frame.size.width
        let height = (minY - maxY) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        imageView.layer.addSublayer(outline)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: 6, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
}

