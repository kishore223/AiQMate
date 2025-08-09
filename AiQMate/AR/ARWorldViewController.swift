//
//  ARWorldViewController.swift
//  AiQMate
//
//  v3.2 ‑ 20 Jul 2025  ✦ COMPLETE FILE WITH READABLE NOTES
//
//  ───────────── WHAT'S NEW ─────────────
//  ▸ Notes are now stored as **ARAnchor objects** whose `name`
//    carries the note text.  Those anchors are baked into the
//    `ARWorldMap`, so they *only* re‑appear after ARKit has
//    successfully **relocalised** to the saved environment.
//  ▸ Users can now input custom text for their notes
//  ▸ Compact, readable note containers with properly centered text
//
//  ───────────── REQUIREMENTS ─────────────
//  •  RealityKit, ARKit
//  •  FirebaseCore          (call FirebaseApp.configure() in AppDelegate)
//  •  FirebaseFirestore
//  •  FirebaseStorage
//

import UIKit
import RealityKit
import ARKit
import FirebaseFirestore
import FirebaseStorage

// MARK: - Helpers ------------------------------------------------------------

private func archive(_ map: ARWorldMap) throws -> Data {
    try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
}

private func unarchiveMap(from data: Data) -> ARWorldMap? {
    try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
}

// MARK: - ViewController -----------------------------------------------------

final class ARWorldViewController: UIViewController {

    // UI
    private let arView      = ARView(frame: .zero)
    private let statusLabel = UILabel()
    private let saveBtn     = UIButton(type: .system)
    private let loadBtn     = UIButton(type: .system)
    private let resetBtn    = UIButton(type: .system)

    // Firebase
    private let firestore   = Firestore.firestore()
    private let storage     = Storage.storage()

    // Local dir
    private let docsURL     = FileManager.default.urls(for: .documentDirectory,
                                                       in: .userDomainMask).first!

    // Pending note transform (for when user taps and we need their input)
    private var pendingNoteTransform: simd_float4x4?

    // ────────────────────────────────────────────────────────────────

    override func viewDidLoad() {
        super.viewDidLoad()

        setupARView()
        setupOverlay()
        configureSession()   // fresh run
        addTapRecognizer()
    }

    // MARK: Setup ------------------------------------------------------------

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
    }

    private func setupOverlay() {

        func style(_ b: UIButton, _ title: String) {
            b.setTitle(title, for: .normal)
            b.setTitleColor(.systemBackground, for: .normal)
            b.backgroundColor = UIColor.label.withAlphaComponent(0.75)
            b.layer.cornerRadius = 8
            b.contentEdgeInsets = .init(top: 6, left: 12, bottom: 6, right: 12)
        }

        style(saveBtn,  "Save Map")
        style(loadBtn,  "Load Map")
        style(resetBtn, "Reset")

        saveBtn.addTarget(self,  action: #selector(promptForMapName), for: .touchUpInside)
        loadBtn.addTarget(self,  action: #selector(loadMapChooser),    for: .touchUpInside)
        resetBtn.addTarget(self, action: #selector(resetSession),      for: .touchUpInside)

        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .systemBackground
        statusLabel.backgroundColor = UIColor.label.withAlphaComponent(0.75)
        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true

        let buttons = UIStackView(arrangedSubviews: [saveBtn, loadBtn, resetBtn])
        buttons.axis = .horizontal
        buttons.spacing = 8

        let overlay = UIStackView(arrangedSubviews: [statusLabel, buttons])
        overlay.axis = .vertical
        overlay.alignment = .center
        overlay.spacing = 12
        overlay.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func addTapRecognizer() {
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                           action: #selector(handleTap(_:))))
    }

    // MARK: AR Session -------------------------------------------------------

    private func configureSession(using map: ARWorldMap? = nil) {

        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]
        cfg.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            cfg.sceneReconstruction = .meshWithClassification
        }
        if let map = map { cfg.initialWorldMap = map }

        arView.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        statusLabel.text = map == nil ? "Scanning… 📡" : "Loaded map – move device to relocalise"
    }

    // MARK: Tap‑to‑Pin --------------------------------------------------------

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let pt = g.location(in: arView)

        // planes / mesh
        if let res = arView.raycast(from: pt, allowing: .estimatedPlane, alignment: .any).first {
            promptForNoteText(at: res.worldTransform)
            return
        }

        // feature point fallback
        if let feat = arView.hitTest(pt, types: [.featurePoint]).first {
            promptForNoteText(at: feat.worldTransform)
            return
        }

        statusLabel.text = "⛔️ No surface – move device"
    }

    private func promptForNoteText(at transform: simd_float4x4) {
        // Store the transform temporarily
        pendingNoteTransform = transform
        
        let alert = UIAlertController(title: "Create Note",
                                      message: "Enter your note text",
                                      preferredStyle: .alert)
        
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
            self.createNoteAnchor(at: transform, text: finalText)
            self.pendingNoteTransform = nil
        })
        
        present(alert, animated: true)
    }

    private func createNoteAnchor(at transform: simd_float4x4, text: String) {
        // Store note as ARAnchor → persists inside ARWorldMap.
        let anchor = ARAnchor(name: text, transform: transform)
        arView.session.add(anchor: anchor)
        // Visuals will be created in session(_:didAdd:)
        statusLabel.text = "Note created: \"\(text)\""
    }

    // MARK: Save Flow --------------------------------------------------------

    @objc private func promptForMapName() {
        guard arView.session.currentFrame?.worldMappingStatus == .mapped else {
            statusLabel.text = "Map not ready – keep scanning"
            return
        }
        let alert = UIAlertController(title: "Save Map",
                                      message: "Enter a name you'll recognise later",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "e.g. Office‑Corner" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? "Untitled"
            self.saveWorldMap(named: name.isEmpty ? "Untitled" : name)
        })
        present(alert, animated: true)
    }

    private func saveWorldMap(named mapName: String) {
        arView.session.getCurrentWorldMap { [weak self] map, err in
            guard let self = self, let map = map, err == nil else {
                self?.statusLabel.text = "❌ Map capture failed"; return
            }
            do {
                let data = try archive(map)
                // local backup
                let id   = UUID().uuidString
                let file = self.docsURL.appendingPathComponent("WorldMap‑\(id).arexperience")
                try data.write(to: file)
                self.statusLabel.text = "💾 saved locally"

                // cloud
                let path = "worldMaps/\(id).arexperience"
                self.storage.reference(withPath: path).putData(data, metadata: nil) { _, err2 in
                    if let err2 = err2 {
                        DispatchQueue.main.async { self.statusLabel.text = "Cloud ❌ \(err2.localizedDescription)" }
                        return
                    }
                    // firestore meta
                    self.firestore.collection("worldMaps").document(id).setData([
                        "name"       : mapName,
                        "createdAt"  : Timestamp(date: Date()),
                        "storagePath": path
                    ]) { err3 in
                        DispatchQueue.main.async {
                            self.statusLabel.text = err3 == nil ? "Saved \(mapName) ✅" : "Meta ❌"
                        }
                    }
                }

            } catch { self.statusLabel.text = "Archive ❌" }
        }
    }

    // MARK: Load Flow --------------------------------------------------------

    @objc private func loadMapChooser() {
        firestore.collection("worldMaps")
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snap, err in
                guard let self = self, let docs = snap?.documents, err == nil else {
                    self?.statusLabel.text = "List ❌"; return
                }
                if docs.isEmpty { self.statusLabel.text = "No saved maps"; return }

                let sheet = UIAlertController(title: "Load Map",
                                              message: nil,
                                              preferredStyle: .actionSheet)
                docs.forEach { doc in
                    let name = doc.get("name") as? String ?? "(unnamed)"
                    sheet.addAction(UIAlertAction(title: name, style: .default) { _ in
                        self.downloadAndLoad(doc)
                    })
                }
                sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(sheet, animated: true)
            }
    }

    private func downloadAndLoad(_ doc: DocumentSnapshot) {
        guard let path = doc.get("storagePath") as? String else { return }
        statusLabel.text = "Downloading… ⏬"

        storage.reference(withPath: path).getData(maxSize: 50 * 1024 * 1024) { [weak self] data, err in
            guard let self = self, let data = data, err == nil,
                  let map = unarchiveMap(from: data) else {
                DispatchQueue.main.async { self?.statusLabel.text = "Download ❌" }
                return
            }
            DispatchQueue.main.async {
                self.arView.scene.anchors.removeAll()
                self.configureSession(using: map)   // notes will appear only after relocalisation
            }
        }
    }

    // MARK: Reset ------------------------------------------------------------

    @objc private func resetSession() {
        arView.scene.anchors.removeAll()
        configureSession()
        statusLabel.text = "Session reset"
        pendingNoteTransform = nil
    }
}

// MARK: - ARSessionDelegate --------------------------------------------------

extension ARWorldViewController: ARSessionDelegate {

    // create visuals *only* when ARKit reports anchors (which it does
    // after relocalisation OR immediately after we add a new anchor).
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors.forEach { anchor in
            guard let text = anchor.name else { return }
            // build a RealityKit AnchorEntity attached to the ARAnchor
            let entityAnchor = AnchorEntity(anchor: anchor)
            entityAnchor.addChild(makeNoteCard(text))
            arView.scene.addAnchor(entityAnchor)
        }
    }

    private func makeNoteCard(_ text: String) -> Entity {
        let container = Entity()
        
        // Modern card dimensions
        let cardWidth: Float = 0.28
        let cardHeight: Float = 0.09
        let cardDepth: Float = 0.006
        
        // Main background - modern gradient-like appearance
        let backgroundMesh = MeshResource.generateBox(
            width: cardWidth,
            height: cardHeight,
            depth: cardDepth,
            cornerRadius: 0.015
        )
        let backgroundMaterial = SimpleMaterial(
            color: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95), // Dark blue-gray
            roughness: 0.1,
            isMetallic: false
        )
        let backgroundEntity = ModelEntity(mesh: backgroundMesh, materials: [backgroundMaterial])
        container.addChild(backgroundEntity)
        
        // Accent strip at the top
        let accentMesh = MeshResource.generateBox(
            width: cardWidth - 0.01,
            height: 0.008,
            depth: cardDepth + 0.001,
            cornerRadius: 0.004
        )
        let accentMaterial = SimpleMaterial(
            color: UIColor(red: 0.0, green: 0.7, blue: 0.9, alpha: 1.0), // Bright cyan
            roughness: 0.0,
            isMetallic: true
        )
        let accentEntity = ModelEntity(mesh: accentMesh, materials: [accentMaterial])
        accentEntity.position.y = (cardHeight / 2) - 0.015
        accentEntity.position.z = cardDepth * 0.5
        container.addChild(accentEntity)
        
        // Subtle border glow
        let glowMesh = MeshResource.generateBox(
            width: cardWidth + 0.003,
            height: cardHeight + 0.003,
            depth: cardDepth * 0.3,
            cornerRadius: 0.018
        )
        let glowMaterial = SimpleMaterial(
            color: UIColor(red: 0.0, green: 0.7, blue: 0.9, alpha: 0.3), // Subtle cyan glow
            roughness: 0.8,
            isMetallic: false
        )
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowEntity.position.z = -cardDepth * 0.65
        container.addChild(glowEntity)
        
        // Text (truncate if too long for readability)
        let displayText = text.count > 35 ? String(text.prefix(32)) + "..." : text
        
        do {
            let textMesh = MeshResource.generateText(
                displayText,
                extrusionDepth: 0.003,
                font: .systemFont(ofSize: 0.038, weight: .medium),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            
            // Modern white text with slight glow
            let textMaterial = SimpleMaterial(
                color: UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0), // Cool white
                roughness: 0.0,
                isMetallic: false
            )
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            
            // Center the text precisely
            let textBounds = textEntity.model?.mesh.bounds
            if let bounds = textBounds {
                textEntity.position.x = -bounds.center.x
                textEntity.position.y = -bounds.center.y - 0.005 // Slightly below center for visual balance
                textEntity.position.z = cardDepth * 0.8
            } else {
                textEntity.position.y = -0.005
                textEntity.position.z = cardDepth * 0.8
            }
            
            container.addChild(textEntity)
            
            // Add subtle text shadow for depth
            let shadowMaterial = SimpleMaterial(
                color: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4),
                roughness: 1.0,
                isMetallic: false
            )
            let shadowEntity = ModelEntity(mesh: textMesh, materials: [shadowMaterial])
            shadowEntity.position = textEntity.position
            shadowEntity.position.x += 0.001
            shadowEntity.position.y -= 0.001
            shadowEntity.position.z -= 0.001
            container.addChild(shadowEntity)
            
        } catch {
            // Fallback: modern indicator if text fails
            let indicatorMesh = MeshResource.generateSphere(radius: 0.01)
            let indicatorMaterial = SimpleMaterial(
                color: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0), // Soft red
                roughness: 0.2,
                isMetallic: false
            )
            let indicatorEntity = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
            indicatorEntity.position.z = cardDepth
            container.addChild(indicatorEntity)
        }
        
        // Position container slightly above surface
        container.position.y += 0.02
        
        // Always face the camera
        if #available(iOS 15.0, *) {
            container.components.set(BillboardComponent())
        }
        
        return container
    }

    // status updates
    func session(_ s: ARSession, didUpdate frame: ARFrame) {
        let msg: String
        switch frame.worldMappingStatus {
        case .notAvailable: msg = "Scanning… 📡"
        case .limited:      msg = "Mapping limited… move slowly"
        case .extending:    msg = "Almost mapped… 🔄"
        case .mapped:       msg = frame.camera.trackingState == .normal
                               ? "Mapped ✔︎"
                               : "Relocalising…"
        @unknown default:   msg = "Mapping ?"
        }
        statusLabel.text = msg
    }

    func session(_ s: ARSession, didFailWithError error: Error) {
        statusLabel.text = "Session ❌ \(error.localizedDescription)"
    }

    func sessionWasInterrupted(_ s: ARSession) {
        statusLabel.text = "⏸ Interrupted"
    }

    func sessionInterruptionEnded(_ s: ARSession) {
        resetSession()
    }
}
