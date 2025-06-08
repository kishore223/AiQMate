import UIKit
import ARKit
import SceneKit
import FirebaseFirestore
import CoreLocation

// MARK: - Annotation Model

struct Annotation {
    var id: String
    var imageName: String
    var text: String
    var position: SCNVector3
    
    init(id: String, imageName: String, text: String, position: SCNVector3) {
        self.id = id
        self.imageName = imageName
        self.text = text
        self.position = position
    }
    
    init?(document: DocumentSnapshot) {
        let data = document.data()
        guard let imageName = data?["imageName"] as? String,
              let text = data?["text"] as? String,
              let positionData = data?["position"] as? [String: Any],
              let x = positionData["x"] as? Float,
              let y = positionData["y"] as? Float,
              let z = positionData["z"] as? Float else {
            return nil
        }
        self.id = document.documentID
        self.imageName = imageName
        self.text = text
        self.position = SCNVector3(x, y, z)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "imageName": imageName,
            "text": text,
            "position": [
                "x": position.x,
                "y": position.y,
                "z": position.z
            ]
        ]
    }
}

// MARK: - ObjectDetectionVC

class ObjectDetectionVC: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    // MARK: - Properties
    
    var imageItem: ImageItem?
    
    private var isImageDetected = false
    private var detectionOverlayView: UIView?
    private var imageAnchorNode: SCNNode?
    
    /// Dictionary of annotationID -> Annotation
    private var annotations: [String: Annotation] = [:]
    
    /// Firestore listener for real-time updates
    private var annotationListener: ListenerRegistration?
    
    private lazy var sceneView: ARSCNView = {
        let view = ARSCNView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(tapGestureRecognized(_:))
        )
        return gesture
    }()
    
    private var arImageConfig: ARWorldTrackingConfiguration!
    private let locationManager = CLLocationManager()
    private var compassImageView: UIImageView!
    
    // MARK: - "Show Pinned Names" Button with Transparent UI

    private lazy var showAnnotationsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Show Pinned Names", for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        // Make the button transparent with a subtle border
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.layer.masksToBounds = false
        
        // Add subtle shadow for better visibility
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        
        // Add blur effect background for better readability
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 8
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false  // Allow touches to pass through
        
        button.insertSubview(blurView, at: 0)
        
        // Make sure blur view covers the entire button
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: button.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapShowAnnotations), for: .touchUpInside)
        
        return button
    }()
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupARSession()
        sceneView.addGestureRecognizer(tapGesture)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissSelf)
        )
        
        setupLocationManager()
        setupCompass()
        
        // Add the button to the view
        setupShowAnnotationsButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let configuration = arImageConfig {
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        locationManager.startUpdatingHeading()
        
        // Start listening for annotation changes
        startListeningForAnnotations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
        imageAnchorNode = nil
        locationManager.stopUpdatingHeading()
        
        // Stop listening for annotation changes
        stopListeningForAnnotations()
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupARSession() {
        guard let imageItem = imageItem else {
            print("No imageItem provided.")
            return
        }
        
        // Load the reference image from the given imageItem
        DispatchQueue.global().async {
            if let imageData = try? Data(contentsOf: imageItem.imageURL),
               let uiImage = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    guard let cgImage = uiImage.cgImage else {
                        print("Failed to get cgImage from uiImage.")
                        return
                    }
                    
                    let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
                    referenceImage.name = imageItem.name
                    
                    self.arImageConfig = ARWorldTrackingConfiguration()
                    self.arImageConfig.detectionImages = [referenceImage]
                    
                    // Start AR session for detecting that reference image
                    self.sceneView.session.run(self.arImageConfig,
                                               options: [.resetTracking, .removeExistingAnchors])
                }
            } else {
                print("Failed to load image data from imageURL.")
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 1
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    private func setupCompass() {
        compassImageView = UIImageView(image: UIImage(systemName: "location.north.fill"))
        compassImageView.tintColor = .white
        compassImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(compassImageView)
        
        NSLayoutConstraint.activate([
            compassImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            compassImageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            compassImageView.widthAnchor.constraint(equalToConstant: 50),
            compassImageView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        compassImageView.isHidden = true
    }
    
    private func setupShowAnnotationsButton() {
        view.addSubview(showAnnotationsButton)
        NSLayoutConstraint.activate([
            showAnnotationsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            showAnnotationsButton.bottomAnchor.constraint(equalTo: compassImageView.topAnchor, constant: -20),
            showAnnotationsButton.widthAnchor.constraint(equalToConstant: 160),
            showAnnotationsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Real-time Annotation Loading
    
    private func startListeningForAnnotations() {
        guard let imageItem = imageItem else { return }
        
        let db = Firestore.firestore()
        annotationListener = db.collection("annotations")
            .whereField("containerName", isEqualTo: imageItem.name)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error listening for annotations: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self, let snapshot = snapshot else { return }
                
                // Track which annotations were added, modified, or removed
                for change in snapshot.documentChanges {
                    let document = change.document
                    
                    switch change.type {
                    case .added, .modified:
                        if let annotation = Annotation(document: document) {
                            let oldAnnotation = self.annotations[annotation.id]
                            self.annotations[annotation.id] = annotation
                            
                            // Update AR scene if image is detected
                            if self.isImageDetected {
                                // Remove old node if it exists
                                if oldAnnotation != nil {
                                    self.removeAnnotationNode(withId: annotation.id)
                                }
                                // Add new/updated node
                                self.addAnnotationNode(for: annotation)
                            }
                        }
                        
                    case .removed:
                        let annotationId = document.documentID
                        self.annotations.removeValue(forKey: annotationId)
                        
                        // Remove from AR scene if image is detected
                        if self.isImageDetected {
                            self.removeAnnotationNode(withId: annotationId)
                        }
                    }
                }
                
                print("Real-time update: Now have \(self.annotations.count) annotations for container \(imageItem.name).")
            }
    }
    
    private func stopListeningForAnnotations() {
        annotationListener?.remove()
        annotationListener = nil
        annotations.removeAll()
    }
    
    // MARK: - AR Node Management
    
    private func removeAnnotationNode(withId annotationId: String) {
        guard let imageAnchorNode = imageAnchorNode else { return }
        
        // Find and remove the node with the matching name
        for childNode in imageAnchorNode.childNodes {
            if childNode.name == annotationId {
                childNode.removeFromParentNode()
                break
            }
        }
    }
    
    private func addAllAnnotationNodes() {
        // Add nodes for all current annotations
        for (_, annotation) in annotations {
            addAnnotationNode(for: annotation)
        }
    }
    
    // MARK: - Firebase Methods for Adding/Deleting Annotations
    
    private func saveAnnotation(_ annotation: Annotation) {
        guard let imageItem = imageItem else {
            print("No imageItem found, cannot store container/category info.")
            return
        }
        
        let containerName = imageItem.name
        let categoryName  = imageItem.type  // or however you handle the category
        
        var annotationData = annotation.toDictionary()
        annotationData["containerName"] = containerName
        annotationData["categoryName"]  = categoryName
        
        let db = Firestore.firestore()
        db.collection("annotations")
          .document(annotation.id)
          .setData(annotationData) { error in
              if let error = error {
                  print("Error saving annotation: \(error.localizedDescription)")
              } else {
                  print("Annotation saved successfully with containerName & categoryName.")
                  // No need to manually update annotations here since the listener will handle it
              }
          }
    }
    
    private func deleteAnnotation(withId id: String) {
        let db = Firestore.firestore()
        db.collection("annotations").document(id).delete { error in
            if let error = error {
                print("Error deleting annotation: \(error.localizedDescription)")
            } else {
                print("Annotation deleted successfully")
                // No need to manually update annotations here since the listener will handle it
            }
        }
    }
    
    // MARK: - Creating Annotation Nodes in AR
    
    private func createDeleteButton(withSize size: CGFloat) -> UIImage {
        let containerSize = CGSize(width: size, height: size)
        let containerView = UIView(frame: CGRect(origin: .zero, size: containerSize))
        
        // Create circular background with gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = containerView.bounds
        gradientLayer.colors = [
            UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = size / 2
        
        // Add inner shadow
        let innerShadow = CALayer()
        innerShadow.frame = gradientLayer.bounds
        innerShadow.cornerRadius = size / 2
        innerShadow.shadowColor = UIColor.black.cgColor
        innerShadow.shadowOffset = CGSize(width: 0, height: 2)
        innerShadow.shadowOpacity = 0.2
        innerShadow.shadowRadius = 2
        innerShadow.masksToBounds = true
        gradientLayer.addSublayer(innerShadow)
        
        // Create white border
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(ovalIn: containerView.bounds.insetBy(dx: 1, dy: 1)).cgPath
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.fillColor   = nil
        borderLayer.lineWidth   = 1.5
        
        // Add glow effect
        let glowLayer = CAShapeLayer()
        glowLayer.path = borderLayer.path
        glowLayer.strokeColor = UIColor.white.cgColor
        glowLayer.fillColor   = nil
        glowLayer.lineWidth   = 1.0
        glowLayer.shadowColor = UIColor.white.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowOpacity = 0.6
        glowLayer.shadowRadius = 2
        
        // Create X symbol
        let xSymbolLayer = CAShapeLayer()
        let padding: CGFloat = size * 0.3
        let xPath = UIBezierPath()
        
        xPath.move(to: CGPoint(x: padding, y: padding))
        xPath.addLine(to: CGPoint(x: size - padding, y: size - padding))
        xPath.move(to: CGPoint(x: size - padding, y: padding))
        xPath.addLine(to: CGPoint(x: padding, y: size - padding))
        
        xSymbolLayer.path = xPath.cgPath
        xSymbolLayer.strokeColor = UIColor.white.cgColor
        xSymbolLayer.lineWidth = 2.5
        xSymbolLayer.lineCap = .round
        xSymbolLayer.shadowColor = UIColor.black.cgColor
        xSymbolLayer.shadowOffset = CGSize(width: 0, height: 1)
        xSymbolLayer.shadowOpacity = 0.3
        xSymbolLayer.shadowRadius = 1
        
        // Add layers
        containerView.layer.addSublayer(gradientLayer)
        containerView.layer.addSublayer(glowLayer)
        containerView.layer.addSublayer(borderLayer)
        containerView.layer.addSublayer(xSymbolLayer)
        
        // Create image from the containerView
        UIGraphicsBeginImageContextWithOptions(containerSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        containerView.layer.render(in: context)
        let buttonImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return buttonImage
    }
    
    private func createDeleteButtonNode(for annotationNode: SCNNode, planeWidth: CGFloat, planeHeight: CGFloat) -> SCNNode {
        let buttonSizeFactor: CGFloat = 0.2
        let xButtonPlane = SCNPlane(width: planeWidth * buttonSizeFactor, height: planeWidth * buttonSizeFactor)
        
        let deleteButtonImage = createDeleteButton(withSize: 60)
        xButtonPlane.firstMaterial?.diffuse.contents = deleteButtonImage
        xButtonPlane.firstMaterial?.isDoubleSided    = true
        xButtonPlane.firstMaterial?.transparent.contents = deleteButtonImage
        xButtonPlane.firstMaterial?.lightingModel    = .constant
        
        let xButtonNode = SCNNode(geometry: xButtonPlane)
        xButtonNode.name = "deleteButton"
        
        // Position the delete button in the top-right corner of the plane
        xButtonNode.position = SCNVector3(
            planeWidth / 2 - (xButtonPlane.width / 2),
            planeHeight / 2 - (xButtonPlane.height / 2),
            0.001
        )
        
        let xButtonConstraint = SCNBillboardConstraint()
        xButtonConstraint.freeAxes = .all
        xButtonNode.constraints = [xButtonConstraint]
        
        return xButtonNode
    }
    
    private func addAnnotationNode(for annotation: Annotation) {
        let label = UILabel()
        label.text = annotation.text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = .clear
        
        let maxLabelWidth: CGFloat = 200
        let labelSize = label.sizeThatFits(CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude))
        
        let padding: CGFloat = 10
        let containerWidth = labelSize.width + (padding * 2) + 30
        let containerHeight = labelSize.height + (padding * 2)
        
        let containerSize = CGSize(width: containerWidth, height: containerHeight)
        let containerView = UIView(frame: CGRect(origin: .zero, size: containerSize))
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderColor  = UIColor.white.cgColor
        containerView.layer.borderWidth  = 1.5
        containerView.layer.shadowColor  = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.5
        containerView.layer.shadowOffset  = CGSize(width: 2, height: 2)
        containerView.layer.shadowRadius  = 4
        
        label.frame = CGRect(x: padding, y: padding,
                             width: labelSize.width, height: labelSize.height)
        containerView.addSubview(label)
        
        let speechBubbleSize: CGFloat = 24
        let speechBubbleImageView = UIImageView()
        if let speechBubbleImage = UIImage(systemName: "bubble.left.and.bubble.right.fill") {
            speechBubbleImageView.image = speechBubbleImage
            speechBubbleImageView.tintColor = .white
        }
        speechBubbleImageView.frame = CGRect(
            x: containerSize.width - speechBubbleSize - padding,
            y: padding,
            width: speechBubbleSize,
            height: speechBubbleSize
        )
        containerView.addSubview(speechBubbleImageView)
        
        // Convert the containerView to a UIImage
        UIGraphicsBeginImageContextWithOptions(containerSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }
        containerView.layer.render(in: context)
        guard let annotationImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()
        
        let scalingFactor: CGFloat = 0.0015
        let planeWidth  = containerSize.width  * scalingFactor
        let planeHeight = containerSize.height * scalingFactor
        
        let plane = SCNPlane(width: planeWidth, height: planeHeight)
        plane.firstMaterial?.diffuse.contents = annotationImage
        plane.firstMaterial?.isDoubleSided    = true
        
        let annotationNode = SCNNode(geometry: plane)
        annotationNode.name = annotation.id
        annotationNode.position = annotation.position
        
        // Make sure it always faces the camera
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = .all
        annotationNode.constraints = [constraint]
        
        // Add the delete "X" button as a child node
        let deleteButton = createDeleteButtonNode(for: annotationNode,
                                                  planeWidth: planeWidth,
                                                  planeHeight: planeHeight)
        annotationNode.addChildNode(deleteButton)
        
        // Attach to the image anchor node if it's found
        imageAnchorNode?.addChildNode(annotationNode)
    }
    
    private func addAnnotation(at hitResult: ARHitTestResult, text: String) {
        guard isImageDetected else {
            let alert = UIAlertController(
                title: "Image Not Detected",
                message: "Please detect the image before adding annotations.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = .clear
        
        let maxLabelWidth: CGFloat = 200
        let labelSize = label.sizeThatFits(CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude))
        
        let padding: CGFloat = 10
        let containerWidth = labelSize.width + (padding * 2) + 30
        let containerHeight = labelSize.height + (padding * 2)
        
        let containerSize = CGSize(width: containerWidth, height: containerHeight)
        let containerView = UIView(frame: CGRect(origin: .zero, size: containerSize))
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderColor  = UIColor.white.cgColor
        containerView.layer.borderWidth  = 1.5
        containerView.layer.shadowColor  = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.5
        containerView.layer.shadowOffset  = CGSize(width: 2, height: 2)
        containerView.layer.shadowRadius  = 4
        
        label.frame = CGRect(x: padding, y: padding,
                             width: labelSize.width, height: labelSize.height)
        containerView.addSubview(label)
        
        let speechBubbleSize: CGFloat = 24
        let speechBubbleImageView = UIImageView()
        if let speechBubbleImage = UIImage(systemName: "bubble.left.and.bubble.right.fill") {
            speechBubbleImageView.image = speechBubbleImage
            speechBubbleImageView.tintColor = .white
        }
        speechBubbleImageView.frame = CGRect(
            x: containerWidth - speechBubbleSize - padding,
            y: padding,
            width: speechBubbleSize,
            height: speechBubbleSize
        )
        containerView.addSubview(speechBubbleImageView)
        
        UIGraphicsBeginImageContextWithOptions(containerSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }
        containerView.layer.render(in: context)
        guard let annotationImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()
        
        let scalingFactor: CGFloat = 0.0015
        let planeWidth  = containerSize.width  * scalingFactor
        let planeHeight = containerSize.height * scalingFactor
        
        let plane = SCNPlane(width: planeWidth, height: planeHeight)
        plane.firstMaterial?.diffuse.contents = annotationImage
        plane.firstMaterial?.isDoubleSided    = true
        
        let annotationId   = UUID().uuidString
        let annotationNode = SCNNode(geometry: plane)
        annotationNode.name = annotationId
        
        if let imageAnchorNode = self.imageAnchorNode {
            let transform = hitResult.worldTransform
            let worldPosition = SCNVector3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            // Convert to local coords relative to the anchor
            let localPosition = imageAnchorNode.convertPosition(worldPosition, from: nil)
            annotationNode.position = localPosition
            
            // Face the camera
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            annotationNode.constraints = [constraint]
            
            let deleteButton = createDeleteButtonNode(
                for: annotationNode,
                planeWidth: planeWidth,
                planeHeight: planeHeight
            )
            annotationNode.addChildNode(deleteButton)
            imageAnchorNode.addChildNode(annotationNode)
            
            // Build an Annotation struct to save in Firestore
            let newAnnotation = Annotation(
                id: annotationId,
                imageName: imageItem?.name ?? "",
                text: text,
                position: annotationNode.position
            )
            
            // Save to Firestore (the listener will handle updating the local annotations)
            saveAnnotation(newAnnotation)
        }
    }
    
    // MARK: - Gesture Handler
    
    @objc private func tapGestureRecognized(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: sceneView)
        
        let hitTestResults = sceneView.hitTest(tapLocation, options: nil)
        if let nodeHit = hitTestResults.first?.node {
            // If tapped on the delete "X" button
            if nodeHit.name == "deleteButton" {
                if let annotationNode = nodeHit.parent {
                    if let annotationId = annotationNode.name {
                        deleteAnnotation(withId: annotationId)
                    }
                }
                return
            }
            
            // If tapped on an annotation node (not the delete button)
            if let annotationId = nodeHit.name,
               let annotation = annotations[annotationId] {
                // Present the detailed view
                presentAnnotationDetails(for: annotation)
                return
            }
            
            // If tapped on a parent annotation node
            if let parentNode = nodeHit.parent,
               let annotationId = parentNode.name,
               let annotation = annotations[annotationId] {
                presentAnnotationDetails(for: annotation)
                return
            }
        }
        
        // Attempt hit-test for feature points / plane to place new annotation
        let hitTestResultsFeaturePoints = sceneView.hitTest(tapLocation,
                                                            types: [.existingPlaneUsingExtent, .featurePoint])
        if let result = hitTestResultsFeaturePoints.first {
            let alert = UIAlertController(
                title: "Add Annotation",
                message: "Enter text to display",
                preferredStyle: .alert
            )
            alert.addTextField()
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let text = alert.textFields?.first?.text ?? "Empty Text"
                self.addAnnotation(at: result, text: text)
            }))
            present(alert, animated: true)
        }
    }
    
    // MARK: - Present Annotation Details
    
    private func presentAnnotationDetails(for annotation: Annotation) {
        let detailVC = AnnotationDetailViewController()
        detailVC.annotation = annotation
        detailVC.containerName = imageItem?.name ?? "Unknown"
        
        let navController = UINavigationController(rootViewController: detailVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // MARK: - AR Delegate Methods
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // If an ARImageAnchor is recognized
        if let _ = anchor as? ARImageAnchor {
            DispatchQueue.main.async {
                self.isImageDetected = true
                self.imageAnchorNode = node
                self.showImageDetectedOverlay()
                self.compassImageView.isHidden = true
                
                // Add all existing annotations to the AR scene
                self.addAllAnnotationNodes()
            }
        }
    }
    
    // MARK: - Location Manager Delegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // If the image is detected, hide the compass; otherwise, show it
        guard !isImageDetected else {
            compassImageView.isHidden = true
            return
        }
        
        compassImageView.isHidden = false
        let heading: CGFloat = CGFloat(newHeading.trueHeading > 0
                                       ? newHeading.trueHeading
                                       : newHeading.magneticHeading)
        let rotation = -heading * .pi / 180
        compassImageView.transform = CGAffineTransform(rotationAngle: rotation)
    }
    
    // MARK: - Overlay Methods
    
    private func showImageDetectedOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.alpha = 0.0
        
        let tickImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        tickImageView.tintColor = UIColor.green
        tickImageView.contentMode = .scaleAspectFit
        tickImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Image Detected"
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        overlayView.addSubview(tickImageView)
        overlayView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            tickImageView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            tickImageView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -20),
            tickImageView.widthAnchor.constraint(equalToConstant: 100),
            tickImageView.heightAnchor.constraint(equalToConstant: 100),
            
            messageLabel.topAnchor.constraint(equalTo: tickImageView.bottomAnchor, constant: 20),
            messageLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor)
        ])
        
        view.addSubview(overlayView)
        detectionOverlayView = overlayView
        
        UIView.animate(withDuration: 0.5, animations: {
            overlayView.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5,
                           delay: 1.0,
                           options: [],
                           animations: {
                overlayView.alpha = 0.0
            }, completion: { _ in
                overlayView.removeFromSuperview()
            })
        }
    }
    
    // MARK: - Show Pinned Names
    
    @objc private func didTapShowAnnotations() {
        let pinnedNamesVC = PinnedNamesVC()
        
        // Convert dictionary to array of annotations
        pinnedNamesVC.annotations = Array(annotations.values)
        
        // Also pass a "containerName" or "title" if you like
        pinnedNamesVC.containerTitle = imageItem?.name ?? "Annotations"
        
        // Show the pinned names
        navigationController?.pushViewController(pinnedNamesVC, animated: true)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
 }

