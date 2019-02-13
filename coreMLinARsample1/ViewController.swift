//
//  ViewController.swift
//  coreMLinARsample1
//
//  Created by Naraharisetty, Venkat on 2/10/19.
//  Copyright © 2019 Naraharisetty, Venkat. All rights reserved.
//

import UIKit
import AVKit
import Vision
import ARKit
import CoreML


class ViewController: UIViewController, ARSCNViewDelegate {
    let captureSession = AVCaptureSession()
    let imageOutput = AVCapturePhotoOutput()
    var visionRequests = [VNRequest]()
    var nodeArray = [SCNNode()]
    var retreivedObjectName =  ""
    var receivedConfidence: Double = 0.0
    
    
    var dispatchQueueML = DispatchQueue(label:"test")

    @IBOutlet internal var sceneView : ARSCNView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    func getObjectFromML(){
        guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("cannot find model")
        }
        let objectRequest = VNCoreMLRequest(model: model, completionHandler: objectDetectionHandler)
        objectRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [objectRequest]
        self.updateCoreMLObject()
    }
    
    func objectDetectionHandler(request:VNRequest, error: Error?){
        if error != nil{
            print("Error in detection")
            return
        }
        
        let objectResults = request.results?.first as? VNClassificationObservation
        let mainObjectName = objectResults?.identifier ?? nil
        let objectArray = mainObjectName?.components(separatedBy: ",")
        let objectName = objectArray?[0]
        self.retreivedObjectName = objectName ?? ""
        self.receivedConfidence = Double(objectResults?.confidence ?? 0.0)
        print("Object name is \n", self.retreivedObjectName)
    }
    
    func updateCoreMLObject(){
        let image : CVPixelBuffer? = sceneView.session.currentFrame?.capturedImage
        if image == nil {return}
         let convertedImage = CIImage(cvPixelBuffer: image!)
        let handler = VNImageRequestHandler(ciImage: convertedImage)
        do {
            try handler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    func popupNameInAR(objectName:String) -> SCNNode {
        let returnNode = SCNNode()
        let arObjectText = SCNText(string: objectName, extrusionDepth: 0.01)
       let font = UIFont(name: "Futura", size: 0.2)
        arObjectText.font = font
        arObjectText.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        arObjectText.firstMaterial?.diffuse.contents = UIColor(red: 244/255.0, green: 66/255.0, blue: 83/255.0, alpha: 1)
        arObjectText.firstMaterial?.specular.contents = UIColor.white
        arObjectText.firstMaterial?.isDoubleSided = true
        arObjectText.chamferRadius = 0.01
        let (minBound,maxBound) = arObjectText.boundingBox
        let node = SCNNode()
        node.geometry = arObjectText
        node.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x)/2, minBound.y, 0.01/2)
        node.scale = SCNVector3Make(0.2, 0.2, 0.2)
        nodeArray.append(node)
        returnNode.addChildNode(node)
        
        let billBoardConstraints = SCNBillboardConstraint()
        billBoardConstraints.freeAxes = SCNBillboardAxis.Y
        returnNode.constraints = [billBoardConstraints]
        return returnNode
    }
    
    
   
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("In touches begin")
        if let touch = touches.first {
            
            let touchLocation = touch.location(in: sceneView)
            let results: [ARHitTestResult] = sceneView.hitTest(touchLocation, types:[.featurePoint])
            
            if let hitResult = results.first {
               getObjectFromML()
                let popupNode = popupNameInAR(objectName: self.retreivedObjectName);
                popupNode.position = SCNVector3(x:hitResult.worldTransform.columns.3.x,y:hitResult.worldTransform.columns.3.y,z:hitResult.worldTransform.columns.3.z)
                print("place to add node to scene, new node is \n", popupNode)
                sceneView.scene.rootNode.addChildNode(popupNode)
            }
        }
 
    }


   
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // intentionally blank
    }
    
    @IBAction func refreshButton(_ sender: Any) {
        if !nodeArray.isEmpty {
            for node in nodeArray {
                node.removeFromParentNode()
            }
        }
    }
    
    
}

