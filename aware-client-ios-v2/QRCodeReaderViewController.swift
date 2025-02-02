//
//  QRCodeReaderViewController.swift
//  aware-client-ios-v2
//
//  Created by Yuuki Nishiyama on 2019/02/27.
//  Copyright © 2019 Yuuki Nishiyama. All rights reserved.
//

import UIKit
import AVFoundation
import AWAREFramework

class QRCodeReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var joinButton: UIButton!
    
    var previewLayer:AVCaptureVideoPreviewLayer?
    var qrcodeFrameView:UIView?
    
    private let captureSession = AVCaptureSession()
    private let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
    private let captureMetadataOutput = AVCaptureMetadataOutput()
    
    var qrcodeViewHideTimer = Timer()
    
    var qrcode:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        qrcodeFrameView = UIView(frame: CGRect.zero)
        if let qrcodeFrameView = qrcodeFrameView {
            qrcodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrcodeFrameView.layer.borderWidth = 2
            qrcodeFrameView.layer.cornerRadius = 5
            self.view.addSubview(qrcodeFrameView)
            self.view.bringSubviewToFront(qrcodeFrameView)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        switch AVCaptureDevice.authorizationStatus(for: .video ) {
        case .authorized: // The user has previously granted access to the camera.
            DispatchQueue.main.async {
                self.setupCaptureSession()
            }
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCaptureSession()
                    }
                }
            }
        case .denied: // The user has previously denied access.
            return
        case .restricted: // The user can't grant access due to restrictions.
            return
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        captureSession.stopRunning()
        
        for output in captureSession.outputs {
            //session.removeOutput((output as? AVCaptureOutput)!)
            captureSession.removeOutput(output)
        }
        
        for input in captureSession.inputs {
            //session.removeInput((input as? AVCaptureInput)!)
            captureSession.removeInput(input)
        }
    }
    
    func setupCaptureSession(){
        captureSession.beginConfiguration()
        
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
            captureSession.canAddInput(videoDeviceInput)
            else { return }
        captureSession.addInput(videoDeviceInput)
        
        if captureSession.canSetSessionPreset(.hd4K3840x2160){
            captureSession.sessionPreset = .hd4K3840x2160
        }
        
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        captureSession.addOutput(captureMetadataOutput)
        captureMetadataOutput.metadataObjectTypes = [.qr, .face]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.frame = self.previewView.layer.bounds
         self.previewView.layer.addSublayer(previewLayer!)
        
        captureSession.commitConfiguration()
        
        captureSession.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        for object in metadataObjects {
            switch object.type {
            case .qr:
                if let qrObject = previewLayer?.transformedMetadataObject(for: object) as? AVMetadataMachineReadableCodeObject {
                    qrcodeFrameView?.frame = qrObject.bounds
                    qrcodeFrameView?.isHidden = false
                    qrcodeViewHideTimer.invalidate()
                    qrcodeViewHideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { (timer) in
                        self.qrcodeFrameView?.isHidden = true
                    }
                    qrcode = qrObject.stringValue
                }
                
                joinButton.layer.borderColor  = UIColor.white.cgColor
                joinButton.layer.borderWidth = 2
                joinButton.layer.cornerRadius = 5
                joinButton.setTitle("Join", for: .normal)
                joinButton.isEnabled = true
                
                break
            default: break
                
            }
            
        }
    }
    
    @IBAction func didPushCloseButton(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didPushJoinButton(_ sender: UIButton) {
        if let qr = qrcode {
            let study   = AWAREStudy.shared()
            let manager = AWARESensorManager.shared()
            let core    = AWARECore.shared()
            
            study.join(withURL: qr, completion: { (settings, status, error) in
                
                core.requestPermissionForBackgroundSensing()
                core.requestPermissionForPushNotification()
                core.activate()
                manager.stopAndRemoveAllSensors()
                manager.addSensors(with: study)
                if let fitbit = manager.getSensor(SENSOR_PLUGIN_FITBIT) as? Fitbit {
                    fitbit.viewController = self
                }
                manager.startAllSensors()
                manager.createDBTablesOnAwareServer()
                self.dismiss(animated: true, completion: nil)
                
            })
        }
    }
    
}
