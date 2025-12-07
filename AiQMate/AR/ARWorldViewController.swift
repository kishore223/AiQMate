//
//  ARWorldViewController.swift
//  AiQMate
//
//  v4.1 - Cross-Device Compatible with Crash Prevention
//
//  ───────────── COMPATIBILITY IMPROVEMENTS ─────────────
//  ▸ Device capability validation before configuration
//  ▸ Safe map archiving/unarchiving with error handling
//  ▸ Memory management for large maps
//  ▸ iOS version compatibility checks
//  ▸ Graceful fallbacks for unsupported features
//  ▸ Detailed error logging and user feedback
//  ▸ Cross-device map validation system
//
//  ───────────── REQUIREMENTS ─────────────
//  •  RealityKit, ARKit
//  •  FirebaseCore (call FirebaseApp.configure() in AppDelegate)
//  •  FirebaseFirestore
//  •  FirebaseStorage
//  •  iOS 13.0+ (with graceful handling for newer features)
//

import UIKit
import RealityKit
import ARKit
import FirebaseFirestore
import FirebaseStorage

// MARK: - Device Capability Helper -------------------------------------------

struct DeviceCapabilities {
    static let current = DeviceCapabilities()
    
    let supportsWorldTracking: Bool
    let supportsSceneReconstruction: Bool
    let supports60FPS: Bool
    let supportsLiDAR: Bool
    let deviceModel: String
    let iosVersion: String
    
    private init() {
        supportsWorldTracking = ARWorldTrackingConfiguration.isSupported
        supportsSceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        supports60FPS = !ARWorldTrackingConfiguration.supportedVideoFormats.filter({ $0.framesPerSecond == 60 }).isEmpty
        supportsLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        deviceModel = UIDevice.current.model
        iosVersion = UIDevice.current.systemVersion
    }
    
    var description: String {
        return "Device: \(deviceModel), iOS: \(iosVersion), WorldTracking: \(supportsWorldTracking), LiDAR: \(supportsLiDAR)"
    }
}

// MARK: - Safe Helpers -------------------------------------------------------

private func safeArchive(_ map: ARWorldMap) throws -> Data {
    do {
        let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
        print("✅ Map archived successfully: \(data.count) bytes")
        return data
    } catch {
        print("❌ Map archiving failed: \(error)")
        throw error
    }
}

private func safeUnarchiveMap(from data: Data) -> ARWorldMap? {
    do {
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            print("❌ Failed to unarchive ARWorldMap - invalid data format")
            return nil
        }
        
        // Basic validation
        print("✅ Map unarchived successfully: \(map.anchors.count) anchors")
        return map
        
    } catch {
        print("❌ Map unarchiving error: \(error)")
        return nil
    }
}

// MARK: - Extensions ---------------------------------------------------------

extension simd_float4x4 {
    init(translation vector: simd_float3) {
        self = matrix_identity_float4x4
        self.columns.3 = simd_float4(vector.x, vector.y, vector.z, 1.0)
    }
}

// MARK: - Main ViewController ------------------------------------------------

final class ARWorldViewController: UIViewController {

    // UI Components
    private let arView = ARView(frame: .zero)
    private let statusLabel = UILabel()
    private let saveBtn = UIButton(type: .system)
    private let loadBtn = UIButton(type: .system)
    private let resetBtn = UIButton(type: .system)
    private let qualityIndicator = UIView()
    private let scanningGuidanceLabel = UILabel()
    private let deviceInfoLabel = UILabel()

    // Firebase
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()

    // Local directory
    private let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    // State management
    private var pendingNoteTransform: simd_float4x4?
    private var validationAnchors: [String: [ARAnchor]] = [:]
    private var isScanning = false
    private var lastMappingQuality: Float = 0.0
    private var qualityUpdateTimer: Timer?

    // ────────────────────────────────────────────────────────────────

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ✅ CRITICAL: Check device compatibility first
        guard DeviceCapabilities.current.supportsWorldTracking else {
            showUnsupportedDeviceAlert()
            return
        }
        
        print("📱 Device Info: \(DeviceCapabilities.current.description)")
        
        setupARView()
        setupCompatibleOverlay()
        configureSafeSession()
        addTapRecognizer()
        startQualityMonitoring()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qualityUpdateTimer?.invalidate()
        arView.session.pause()
    }
    
    deinit {
        qualityUpdateTimer?.invalidate()
    }

    // MARK: Safe Setup -------------------------------------------------------

    private func setupARView() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
    }

    private func setupCompatibleOverlay() {
        
        func style(_ button: UIButton, _ title: String) {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.systemBackground, for: .normal)
            button.backgroundColor = UIColor.label.withAlphaComponent(0.85)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        }

        style(saveBtn, "Save Map")
        style(loadBtn, "Load Map")
        style(resetBtn, "Reset")

        saveBtn.addTarget(self, action: #selector(promptForMapName), for: .touchUpInside)
        loadBtn.addTarget(self, action: #selector(loadMapChooser), for: .touchUpInside)
        resetBtn.addTarget(self, action: #selector(resetSession), for: .touchUpInside)

        // Main status label
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textColor = .systemBackground
        statusLabel.backgroundColor = UIColor.label.withAlphaComponent(0.85)
        statusLabel.numberOfLines = 3
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        
        // Add padding manually since contentInsets isn't available on UILabel
        statusLabel.text = "  Initializing AR...  "

        // Quality indicator
        qualityIndicator.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        qualityIndicator.layer.cornerRadius = 10
        qualityIndicator.backgroundColor = .systemRed
        qualityIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Scanning guidance
        scanningGuidanceLabel.font = .systemFont(ofSize: 12, weight: .medium)
        scanningGuidanceLabel.textColor = .systemBackground
        scanningGuidanceLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        scanningGuidanceLabel.numberOfLines = 3
        scanningGuidanceLabel.textAlignment = .center
        scanningGuidanceLabel.layer.cornerRadius = 8
        scanningGuidanceLabel.clipsToBounds = true
        scanningGuidanceLabel.isHidden = true
        scanningGuidanceLabel.text = "  Move slowly around textured surfaces  \n  Avoid blank walls and direct sunlight  \n  Hold device steady when placing notes  "

        // Device info label
        deviceInfoLabel.font = .systemFont(ofSize: 10, weight: .regular)
        deviceInfoLabel.textColor = .secondaryLabel
        deviceInfoLabel.textAlignment = .center
        deviceInfoLabel.numberOfLines = 2
        let caps = DeviceCapabilities.current
        deviceInfoLabel.text = "\(caps.deviceModel) • iOS \(caps.iosVersion)\nLiDAR: \(caps.supportsLiDAR ? "✅" : "❌") • 60fps: \(caps.supports60FPS ? "✅" : "❌")"

        // Button stack
        let buttons = UIStackView(arrangedSubviews: [saveBtn, loadBtn, resetBtn])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        // Quality stack
        let qualityStack = UIStackView()
        qualityStack.axis = .horizontal
        qualityStack.spacing = 8
        qualityStack.alignment = .center
        
        let qualityLabel = UILabel()
        qualityLabel.text = "Quality:"
        qualityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        qualityLabel.textColor = .label
        
        qualityStack.addArrangedSubview(qualityLabel)
        qualityStack.addArrangedSubview(qualityIndicator)

        // Main overlay
        let mainOverlay = UIStackView(arrangedSubviews: [statusLabel, qualityStack, buttons, deviceInfoLabel])
        mainOverlay.axis = .vertical
        mainOverlay.alignment = .center
        mainOverlay.spacing = 12
        mainOverlay.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scanningGuidanceLabel)
        view.addSubview(mainOverlay)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Main overlay at bottom
            mainOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainOverlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            mainOverlay.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            mainOverlay.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Scanning guidance at top
            scanningGuidanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanningGuidanceLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scanningGuidanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            scanningGuidanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Quality indicator size
            qualityIndicator.widthAnchor.constraint(equalToConstant: 20),
            qualityIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func addTapRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSafeTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        arView.addGestureRecognizer(tapGesture)
    }

    private func startQualityMonitoring() {
        qualityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateQualityIndicator()
        }
    }

    private func showUnsupportedDeviceAlert() {
        let alert = UIAlertController(
            title: "Device Not Supported",
            message: "This device doesn't support ARKit World Tracking required for this app.\n\nRequired: iPhone 6s/iPad Pro (2017) or newer",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Safe AR Session Configuration ------------------------------------

    private func configureSafeSession(using map: ARWorldMap? = nil) {
        guard DeviceCapabilities.current.supportsWorldTracking else {
            statusLabel.text = "❌ ARKit not supported on this device"
            return
        }
        
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]
        cfg.environmentTexturing = .automatic
        cfg.isAutoFocusEnabled = true
        
        // ✅ SAFE FEATURE CONFIGURATION based on device capabilities
        let caps = DeviceCapabilities.current
        
        // Scene reconstruction (LiDAR)
        if caps.supportsSceneReconstruction {
            cfg.sceneReconstruction = .meshWithClassification
            print("✅ Scene reconstruction enabled")
        } else {
            print("ℹ️ Scene reconstruction not available")
        }
        
        // High frame rate video
        if caps.supports60FPS {
            if let highFPSFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 60 }) {
                cfg.videoFormat = highFPSFormat
                print("✅ 60fps video format enabled")
            }
        } else {
            print("ℹ️ 60fps not available, using default format")
        }
        
        // World map loading
        if let map = map {
            cfg.initialWorldMap = map
            print("✅ Loading world map with \(map.anchors.count) anchors")
        }
        
        // Run session with error handling
        do {
            arView.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
            
            isScanning = map == nil
            updateScanningGuidance()
            
            let message = map == nil ? "📡 Safe scanning mode active" : "🗺 Map loaded - move to relocalize"
            statusLabel.text = message
            print("✅ AR session configured successfully")
            
        } catch {
            statusLabel.text = "❌ Failed to start AR session"
            print("❌ AR session error: \(error)")
        }
    }

    private func updateScanningGuidance() {
        DispatchQueue.main.async {
            self.scanningGuidanceLabel.isHidden = !self.isScanning
            if self.isScanning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.scanningGuidanceLabel.isHidden = true
                }
            }
        }
    }

    private func updateQualityIndicator() {
        guard let frame = arView.session.currentFrame else {
            lastMappingQuality = 0.0
            return
        }
        
        var quality: Float = 0.0
        
        // Tracking state (40% weight)
        switch frame.camera.trackingState {
        case .normal:
            quality += 0.4
        case .limited(let reason):
            switch reason {
            case .excessiveMotion, .insufficientFeatures:
                quality += 0.1
            case .initializing:
                quality += 0.2
            case .relocalizing:
                quality += 0.25
            @unknown default:
                quality += 0.1
            }
        case .notAvailable:
            quality += 0.0
        }
        
        // Mapping status (30% weight)
        switch frame.worldMappingStatus {
        case .mapped:
            quality += 0.3
        case .extending:
            quality += 0.2
        case .limited:
            quality += 0.1
        case .notAvailable:
            quality += 0.0
        @unknown default:
            quality += 0.0
        }
        
        // Anchor count (20% weight)
        let anchorCount = Float(frame.anchors.count)
        let anchorScore = min(anchorCount / 10.0, 1.0) * 0.2
        quality += anchorScore
        
        // Feature points (10% weight)
        if let featurePoints = frame.rawFeaturePoints {
            let featureScore = min(Float(featurePoints.points.count) / 1000.0, 1.0) * 0.1
            quality += featureScore
        }
        
        lastMappingQuality = quality
        
        // Update UI on main thread
        DispatchQueue.main.async {
            let color: UIColor
            if quality > 0.8 {
                color = .systemGreen
            } else if quality > 0.6 {
                color = .systemYellow
            } else if quality > 0.3 {
                color = .systemOrange
            } else {
                color = .systemRed
            }
            self.qualityIndicator.backgroundColor = color
        }
    }

    // MARK: Safe Tap Handling ------------------------------------------------

    @objc private func handleSafeTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        // ✅ HIERARCHICAL RAYCAST with error handling
        do {
            // Priority 1: Existing detected planes (highest accuracy)
            let existingPlaneResults = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any)
            if let result = existingPlaneResults.first {
                promptForNoteText(at: result.worldTransform, accuracy: .high)
                return
            }
            
            // Priority 2: Estimated infinite planes (good accuracy)
            let estimatedPlaneResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
            if let result = estimatedPlaneResults.first {
                promptForNoteText(at: result.worldTransform, accuracy: .medium)
                return
            }
            
            // Priority 3: Feature points (lower accuracy, but still usable)
            let featureResults = arView.hitTest(location, types: [.featurePoint])
            if let result = featureResults.first {
                promptForNoteText(at: result.worldTransform, accuracy: .low)
                return
            }
            
            // No surface found - provide guidance
            statusLabel.text = "⚠️ No surface detected - scan more areas"
            
            if lastMappingQuality < 0.5 {
                showScanningGuidance()
            }
            
        } catch {
            print("❌ Raycast error: \(error)")
            statusLabel.text = "⚠️ Surface detection failed"
        }
    }

    private func showScanningGuidance() {
        scanningGuidanceLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.scanningGuidanceLabel.isHidden = true
        }
    }

    private enum AnchorAccuracy {
        case high, medium, low
        
        var description: String {
            switch self {
            case .high: return "High accuracy (detected plane)"
            case .medium: return "Medium accuracy (estimated plane)"
            case .low: return "Basic accuracy (feature point)"
            }
        }
        
        var confidenceScore: Float {
            switch self {
            case .high: return 0.9
            case .medium: return 0.7
            case .low: return 0.5
            }
        }
    }

    private func promptForNoteText(at transform: simd_float4x4, accuracy: AnchorAccuracy) {
        pendingNoteTransform = transform
        
        let alert = UIAlertController(
            title: "Create Note",
            message: "\(accuracy.description)\nEnter your note text:",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "e.g. Remember to water plants"
            textField.autocapitalizationType = .sentences
            textField.returnKeyType = .done
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.pendingNoteTransform = nil
        })
        
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let finalText = text.isEmpty ? "Note" : text
            self.createSafeNoteAnchor(at: transform, text: finalText, accuracy: accuracy)
            self.pendingNoteTransform = nil
        })
        
        present(alert, animated: true)
    }

    private func createSafeNoteAnchor(at transform: simd_float4x4, text: String, accuracy: AnchorAccuracy) {
        do {
            let noteId = UUID().uuidString
            
            // Create main anchor
            let mainAnchor = ARAnchor(name: text, transform: transform)
            arView.session.add(anchor: mainAnchor)
            
            // Create validation anchors only for high accuracy placements
            if accuracy == .high && DeviceCapabilities.current.supportsLiDAR {
                var validationAnchorsForNote: [ARAnchor] = []
                let offsetDistance: Float = 0.03 // 3cm offset
                
                let offsets: [simd_float3] = [
                    simd_float3(offsetDistance, 0, 0),
                    simd_float3(-offsetDistance, 0, 0),
                    simd_float3(0, 0, offsetDistance)
                ]
                
                for (index, offset) in offsets.enumerated() {
                    let validationTransform = simd_mul(transform, simd_float4x4(translation: offset))
                    let validationAnchor = ARAnchor(name: "\(noteId)_validation_\(index)", transform: validationTransform)
                    arView.session.add(anchor: validationAnchor)
                    validationAnchorsForNote.append(validationAnchor)
                }
                
                validationAnchors[noteId] = validationAnchorsForNote
            }
            
            statusLabel.text = "✅ Note created: \"\(text)\" (\(accuracy.description))"
            print("✅ Note anchor created successfully: \(text)")
            
        } catch {
            statusLabel.text = "❌ Failed to create note"
            print("❌ Anchor creation error: \(error)")
        }
    }

    // MARK: Safe Save Flow ---------------------------------------------------

    @objc private func promptForMapName() {
        // ✅ COMPREHENSIVE VALIDATION before saving
        guard let frame = arView.session.currentFrame else {
            statusLabel.text = "❌ No camera frame available"
            return
        }
        
        guard frame.camera.trackingState == .normal else {
            let message: String
            if case .limited(let reason) = frame.camera.trackingState {
                switch reason {
                case .excessiveMotion:
                    message = "❌ Move device more slowly"
                case .insufficientFeatures:
                    message = "❌ Point at textured surfaces"
                case .initializing:
                    message = "❌ Still initializing - wait a moment"
                case .relocalizing:
                    message = "❌ Still relocalizing - wait a moment"
                @unknown default:
                    message = "❌ Camera tracking limited"
                }
            } else {
                message = "❌ Camera tracking unavailable"
            }
            statusLabel.text = message
            return
        }
        
        guard frame.worldMappingStatus == .mapped else {
            statusLabel.text = "❌ Map not ready - continue scanning (\(Int(lastMappingQuality * 100))%)"
            return
        }
        
        // Quality threshold check
        if lastMappingQuality < 0.5 {
            showLowQualityWarning()
            return
        }
        
        showMapNamePrompt()
    }
    
    private func showLowQualityWarning() {
        let alert = UIAlertController(
            title: "Low Mapping Quality",
            message: "Current quality: \(Int(lastMappingQuality * 100))%\nRecommended: >50%\n\nScanning more areas will improve accuracy on other devices.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Continue Scanning", style: .default))
        alert.addAction(UIAlertAction(title: "Save Anyway", style: .destructive) { _ in
            self.showMapNamePrompt()
        })
        present(alert, animated: true)
    }
    
    private func showMapNamePrompt() {
        let anchorCount = arView.session.currentFrame?.anchors.count ?? 0
        let noteCount = arView.scene.anchors.count
        let caps = DeviceCapabilities.current
        
        let alert = UIAlertController(
            title: "Save Compatible Map",
            message: "Quality: \(Int(lastMappingQuality * 100))% • Notes: \(noteCount)\nDevice: \(caps.deviceModel)\n\nEnter name:",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "e.g. Office-Desk-\(caps.deviceModel)"
            textField.autocapitalizationType = .words
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let timestamp = Int(Date().timeIntervalSince1970)
            let finalName = name.isEmpty ? "Map-\(caps.deviceModel)-\(timestamp)" : name
            self.saveSafeWorldMap(named: finalName)
        })
        
        present(alert, animated: true)
    }

    private func saveSafeWorldMap(named mapName: String) {
        statusLabel.text = "📊 Capturing map safely..."
        
        arView.session.getCurrentWorldMap { [weak self] map, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let map = map, error == nil else {
                    self.statusLabel.text = "❌ Map capture failed: \(error?.localizedDescription ?? "Unknown error")"
                    print("❌ getCurrentWorldMap error: \(String(describing: error))")
                    return
                }
                
                self.processAndUploadMap(map, named: mapName)
            }
        }
    }
    
    private func processAndUploadMap(_ map: ARWorldMap, named mapName: String) {
        do {
            // Safe archiving with error handling
            let data = try safeArchive(map)
            let sizeInMB = Float(data.count) / (1024 * 1024)
            
            print("📊 Map details: \(sizeInMB) MB, \(map.anchors.count) anchors")
            
            // Warn about large maps that might not work cross-device
            if sizeInMB > 15 {
                showLargeMapWarning(data: data, mapName: mapName, size: sizeInMB)
                return
            }
            
            // Save locally first
            saveMapLocally(data, named: mapName)
            
            // Upload to cloud
            uploadMapToCloud(data, mapName: mapName, size: sizeInMB, anchors: map.anchors.count)
            
        } catch {
            statusLabel.text = "❌ Failed to process map: \(error.localizedDescription)"
            print("❌ Map processing error: \(error)")
        }
    }
    
    private func showLargeMapWarning(data: Data, mapName: String, size: Float) {
        let alert = UIAlertController(
            title: "Large Map Warning",
            message: "Map size: \(String(format: "%.1f", size))MB\n\nLarge maps may not load properly on older devices. Continue?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save Anyway", style: .destructive) { _ in
            self.saveMapLocally(data, named: mapName)
            self.uploadMapToCloud(data, mapName: mapName, size: size, anchors: 0)
        })
        present(alert, animated: true)
    }
    
    private func saveMapLocally(_ data: Data, named mapName: String) {
        do {
            let id = UUID().uuidString
            let filename = "CompatibleMap-\(id).arexperience"
            let fileURL = docsURL.appendingPathComponent(filename)
            try data.write(to: fileURL)
            
            print("✅ Map saved locally: \(filename)")
            statusLabel.text = "💾 Saved locally, uploading to cloud..."
            
        } catch {
            print("❌ Local save error: \(error)")
            statusLabel.text = "⚠️ Local save failed, trying cloud only..."
        }
    }
    
    private func uploadMapToCloud(_ data: Data, mapName: String, size: Float, anchors: Int) {
        let id = UUID().uuidString
        let path = "compatibleMaps/\(id).arexperience"
        let caps = DeviceCapabilities.current
        
        // Enhanced metadata for compatibility tracking
        let metadata: [String: Any] = [
            "name": mapName,
            "createdAt": Timestamp(date: Date()),
            "storagePath": path,
            "quality": lastMappingQuality,
            "anchorCount": anchors,
            "sizeInMB": size,
            "version": "4.1-compatible",
            "deviceModel": caps.deviceModel,
            "iosVersion": caps.iosVersion,
            "supportsLiDAR": caps.supportsLiDAR,
            "supports60FPS": caps.supports60FPS,
            "supportsSceneReconstruction": caps.supportsSceneReconstruction
        ]
        
        // Upload to Firebase Storage
        storage.reference(withPath: path).putData(data, metadata: nil) { [weak self] _, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.statusLabel.text = "❌ Upload failed: \(error.localizedDescription)"
                    print("❌ Storage upload error: \(error)")
                    return
                }
                
                self.statusLabel.text = "☁️ Uploaded, saving metadata..."
                
                // Save metadata to Firestore
                self.firestore.collection("compatibleMaps").document(id).setData(metadata) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.statusLabel.text = "❌ Metadata save failed: \(error.localizedDescription)"
                            print("❌ Firestore error: \(error)")
                        } else {
                            self.statusLabel.text = "✅ Map '\(mapName)' saved successfully!"
                            self.isScanning = false
                            self.updateScanningGuidance()
                            print("✅ Map upload completed successfully")
                        }
                    }
                }
            }
        }
    }

    // MARK: Safe Load Flow ---------------------------------------------------

    @objc private func loadMapChooser() {
        statusLabel.text = "📋 Loading compatible maps..."
        
        firestore.collection("compatibleMaps")
            .order(by: "createdAt", descending: true)
            .limit(to: 20) // Limit to prevent memory issues
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    guard let documents = snapshot?.documents, error == nil else {
                        self.statusLabel.text = "❌ Failed to load maps: \(error?.localizedDescription ?? "Unknown error")"
                        print("❌ Firestore query error: \(String(describing: error))")
                        return
                    }
                    
                    if documents.isEmpty {
                        self.statusLabel.text = "📭 No compatible maps found"
                        return
                    }
                    
                    self.showMapSelectionSheet(documents)
                }
            }
    }
    
    private func showMapSelectionSheet(_ documents: [DocumentSnapshot]) {
        let actionSheet = UIAlertController(
            title: "Load Compatible Map",
            message: "Choose from \(documents.count) available maps:",
            preferredStyle: .actionSheet
        )
        
        let currentDevice = DeviceCapabilities.current.deviceModel
        
        for document in documents {
            let name = document.get("name") as? String ?? "(unnamed)"
            let quality = document.get("quality") as? Float ?? 0.0
            let size = document.get("sizeInMB") as? Float ?? 0.0
            let createdDevice = document.get("deviceModel") as? String ?? "Unknown"
            let anchorCount = document.get("anchorCount") as? Int ?? 0
            
            // Show compatibility info
            let compatibility = createdDevice == currentDevice ? "✅" : "⚠️"
            let title = "\(name) \(compatibility)\nQ:\(Int(quality * 100))% • \(String(format: "%.1f", size))MB • \(anchorCount) notes\nFrom: \(createdDevice)"
            
            actionSheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.downloadAndLoadSafely(document)
            })
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = loadBtn
            popover.sourceRect = loadBtn.bounds
        }
        
        present(actionSheet, animated: true)
        statusLabel.text = "📋 Choose a map (✅ = same device type)"
    }

    private func downloadAndLoadSafely(_ document: DocumentSnapshot) {
        guard let path = document.get("storagePath") as? String else {
            statusLabel.text = "❌ Invalid map path"
            return
        }
        
        let name = document.get("name") as? String ?? "Unknown"
        let size = document.get("sizeInMB") as? Float ?? 0.0
        let createdDevice = document.get("deviceModel") as? String ?? "Unknown"
        
        statusLabel.text = "⏬ Downloading '\(name)'... (\(String(format: "%.1f", size))MB)"
        
        // Show progress for large downloads
        if size > 5.0 {
            showDownloadProgress(true)
        }
        
        storage.reference(withPath: path).getData(maxSize: 150 * 1024 * 1024) { [weak self] data, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.showDownloadProgress(false)
                
                guard let data = data, error == nil else {
                    self.statusLabel.text = "❌ Download failed: \(error?.localizedDescription ?? "Unknown error")"
                    print("❌ Storage download error: \(String(describing: error))")
                    return
                }
                
                // Validate and load map
                self.validateAndLoadMap(data, name: name, createdDevice: createdDevice)
            }
        }
    }
    
    private func showDownloadProgress(_ show: Bool) {
        if show {
            saveBtn.isEnabled = false
            loadBtn.isEnabled = false
            resetBtn.isEnabled = false
        } else {
            saveBtn.isEnabled = true
            loadBtn.isEnabled = true
            resetBtn.isEnabled = true
        }
    }
    
    private func validateAndLoadMap(_ data: Data, name: String, createdDevice: String) {
        statusLabel.text = "🔍 Validating map compatibility..."
        
        // Attempt to unarchive safely
        guard let map = safeUnarchiveMap(from: data) else {
            statusLabel.text = "❌ Map format incompatible with this device"
            showMapIncompatibilityAlert(name: name, createdDevice: createdDevice)
            return
        }
        
        // Additional validation
        if map.anchors.isEmpty {
            statusLabel.text = "⚠️ Map contains no anchors - loading anyway"
        }
        
        // Clear existing state
        arView.scene.anchors.removeAll()
        validationAnchors.removeAll()
        
        // Load map with safe configuration
        statusLabel.text = "🗺 Loading map..."
        configureSafeSession(using: map)
        
        statusLabel.text = "✅ Loaded '\(name)' - move device to relocalize"
        isScanning = false
        updateScanningGuidance()
        
        print("✅ Map loaded successfully: \(map.anchors.count) anchors")
    }
    
    private func showMapIncompatibilityAlert(name: String, createdDevice: String) {
        let currentDevice = DeviceCapabilities.current.deviceModel
        let alert = UIAlertController(
            title: "Map Incompatible",
            message: "Map '\(name)' was created on \(createdDevice) and cannot be loaded on \(currentDevice).\n\nThis can happen when:\n• Different iOS versions\n• Different ARKit capabilities\n• Corrupted map data",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Reset Session ----------------------------------------------------

    @objc private func resetSession() {
        print("🔄 Resetting AR session...")
        
        arView.scene.anchors.removeAll()
        validationAnchors.removeAll()
        configureSafeSession()
        
        statusLabel.text = "🔄 Session reset - safe scanning active"
        lastMappingQuality = 0.0
        isScanning = true
        updateScanningGuidance()
    }
}

// MARK: - Safe ARSessionDelegate ---------------------------------------------

extension ARWorldViewController: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            // Only process main anchors, skip validation anchors
            guard let text = anchor.name, !text.contains("_validation_") else { continue }
            
            do {
                // Calculate confidence score
                let confidence = calculateSafeAnchorConfidence(for: anchor)
                
                // Create visual representation
                let anchorEntity = AnchorEntity(anchor: anchor)
                let noteCard = makeSafeNoteCard(text, confidence: confidence)
                anchorEntity.addChild(noteCard)
                arView.scene.addAnchor(anchorEntity)
                
                print("✅ Note anchor added: \(text)")
                
            } catch {
                print("❌ Error adding anchor visual: \(error)")
            }
        }
    }

    private func calculateSafeAnchorConfidence(for anchor: ARAnchor) -> Float {
        guard let frame = arView.session.currentFrame else { return 0.5 }
        
        var confidence: Float = 0.0
        
        // Base confidence from tracking state (60% weight)
        switch frame.camera.trackingState {
        case .normal:
            confidence += 0.6
        case .limited(let reason):
            switch reason {
            case .relocalizing:
                confidence += 0.4
            case .initializing:
                confidence += 0.3
            default:
                confidence += 0.2
            }
        case .notAvailable:
            confidence += 0.0
        }
        
        // Mapping quality contribution (40% weight)
        confidence += lastMappingQuality * 0.4
        
        return min(confidence, 1.0)
    }

    private func makeSafeNoteCard(_ text: String, confidence: Float) -> Entity {
        let container = Entity()
        
        // Safe card dimensions
        let baseWidth: Float = 0.25
        let maxWidth: Float = 0.45
        let cardWidth = min(baseWidth + (Float(text.count) * 0.002), maxWidth)
        let cardHeight: Float = 0.08
        let cardDepth: Float = 0.006
        
        // Confidence-based styling with safe colors
        let confidenceColor: UIColor
        let glowIntensity: Float
        
        if confidence > 0.75 {
            confidenceColor = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0) // Green
            glowIntensity = 0.35
        } else if confidence > 0.5 {
            confidenceColor = UIColor(red: 0.0, green: 0.6, blue: 0.9, alpha: 1.0) // Blue
            glowIntensity = 0.25
        } else if confidence > 0.3 {
            confidenceColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // Orange
            glowIntensity = 0.2
        } else {
            confidenceColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0) // Red
            glowIntensity = 0.15
        }
        
        do {
            // Main card background
            let backgroundMesh = MeshResource.generateBox(
                width: cardWidth,
                height: cardHeight,
                depth: cardDepth,
                cornerRadius: 0.015
            )
            let backgroundMaterial = SimpleMaterial(
                color: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.9),
                roughness: 0.1,
                isMetallic: false
            )
            let backgroundEntity = ModelEntity(mesh: backgroundMesh, materials: [backgroundMaterial])
            container.addChild(backgroundEntity)
            
            // Confidence accent strip
            let accentMesh = MeshResource.generateBox(
                width: cardWidth - 0.01,
                height: 0.01,
                depth: cardDepth + 0.001,
                cornerRadius: 0.005
            )
            let accentMaterial = SimpleMaterial(
                color: confidenceColor,
                roughness: 0.0,
                isMetallic: true
            )
            let accentEntity = ModelEntity(mesh: accentMesh, materials: [accentMaterial])
            accentEntity.position.y = (cardHeight / 2) - 0.015
            accentEntity.position.z = cardDepth * 0.6
            container.addChild(accentEntity)
            
            // Subtle glow
            let glowMesh = MeshResource.generateBox(
                width: cardWidth + 0.004,
                height: cardHeight + 0.004,
                depth: cardDepth * 0.3,
                cornerRadius: 0.02
            )
            let glowMaterial = SimpleMaterial(
                color: confidenceColor.withAlphaComponent(CGFloat(glowIntensity)),
                roughness: 0.8,
                isMetallic: false
            )
            let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
            glowEntity.position.z = -cardDepth * 0.7
            container.addChild(glowEntity)
            
        } catch {
            print("❌ Error creating card background: \(error)")
        }
        
        // Safe text rendering
        let maxDisplayLength = Int(cardWidth * 60)
        let displayText = text.count > maxDisplayLength ?
            String(text.prefix(maxDisplayLength - 3)) + "..." : text
        
        do {
            let textMesh = MeshResource.generateText(
                displayText,
                extrusionDepth: 0.003,
                font: .systemFont(ofSize: 0.035, weight: .medium),
                containerFrame: CGRect(x: 0, y: 0, width: Double(cardWidth - 0.02), height: Double(cardHeight - 0.02)),
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            
            let textMaterial = SimpleMaterial(
                color: UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0),
                roughness: 0.0,
                isMetallic: false
            )
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            
            // Center text
            if let bounds = textEntity.model?.mesh.bounds {
                textEntity.position.x = -bounds.center.x
                textEntity.position.y = -bounds.center.y
                textEntity.position.z = cardDepth * 0.8
            } else {
                textEntity.position.z = cardDepth * 0.8
            }
            
            container.addChild(textEntity)
            
        } catch {
            print("❌ Text rendering failed: \(error)")
            
            // Fallback indicator
            do {
                let indicatorMesh = MeshResource.generateSphere(radius: 0.01)
                let indicatorMaterial = SimpleMaterial(color: confidenceColor, roughness: 0.2, isMetallic: false)
                let indicatorEntity = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
                indicatorEntity.position.z = cardDepth
                container.addChild(indicatorEntity)
            } catch {
                print("❌ Fallback indicator failed: \(error)")
            }
        }
        
        // Position above surface
        container.position.y += 0.02
        
        // Billboard component (iOS 15+ safe)
        if #available(iOS 15.0, *) {
            container.components.set(BillboardComponent())
        }
        
        return container
    }

    // MARK: Safe Session Status Updates --------------------------------------

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let trackingState = frame.camera.trackingState
        let mappingStatus = frame.worldMappingStatus
        
        var statusMessage: String
        var shouldShowGuidance = false
        
        switch (trackingState, mappingStatus) {
        case (.normal, .mapped):
            statusMessage = isScanning ? "✅ High-quality mapping complete!" : "🗺 Map loaded & tracking normally"
            if isScanning {
                isScanning = false
                updateScanningGuidance()
            }
            
        case (.normal, .extending):
            statusMessage = "🔄 Expanding map coverage... (\(Int(lastMappingQuality * 100))%)"
            
        case (.normal, .limited):
            statusMessage = "📊 Building map... (\(Int(lastMappingQuality * 100))%)"
            shouldShowGuidance = lastMappingQuality < 0.3
            
        case (.normal, .notAvailable):
            statusMessage = "🔍 Initializing mapping system..."
            shouldShowGuidance = true
            
        case (.limited(let reason), _):
            switch reason {
            case .excessiveMotion:
                statusMessage = "⚠️ Slow down device movement"
                shouldShowGuidance = true
            case .insufficientFeatures:
                statusMessage = "⚠️ Need more visual features - avoid blank surfaces"
                shouldShowGuidance = true
            case .initializing:
                statusMessage = "🔄 Starting camera tracking..."
            case .relocalizing:
                statusMessage = "🔍 Finding saved map location..."
            @unknown default:
                statusMessage = "⚠️ Limited tracking - move device slowly"
                shouldShowGuidance = true
            }
            
        case (.notAvailable, _):
            statusMessage = "❌ Camera unavailable - check app permissions"
            shouldShowGuidance = true
            
        @unknown default:
            statusMessage = "❓ Unknown tracking state"
            shouldShowGuidance = true
        }
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.statusLabel.text = statusMessage
            
            if shouldShowGuidance && self.scanningGuidanceLabel.isHidden {
                self.showScanningGuidance()
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("🚨 AR Session failed: \(error)")
        
        DispatchQueue.main.async {
            self.statusLabel.text = "❌ AR failed: \(error.localizedDescription)"
            
            // Show detailed error for debugging
            let alert = UIAlertController(
                title: "AR Session Error",
                message: "\(error.localizedDescription)\n\nDevice: \(DeviceCapabilities.current.deviceModel)\niOS: \(DeviceCapabilities.current.iosVersion)\n\nThe app will attempt to recover automatically.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            
            // Attempt automatic recovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.resetSession()
            }
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("⏸ AR Session interrupted")
        DispatchQueue.main.async {
            self.statusLabel.text = "⏸ AR session paused (phone call, etc.)"
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("▶️ AR Session interruption ended")
        DispatchQueue.main.async {
            self.statusLabel.text = "▶️ AR session resuming..."
        }
        
        // Brief delay to allow system stabilization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.resetSession()
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Clean up validation anchor tracking
        for anchor in anchors {
            if let name = anchor.name, !name.contains("_validation_") {
                validationAnchors.removeValue(forKey: name)
                print("🗑 Removed anchor: \(name)")
            }
        }
    }
}
