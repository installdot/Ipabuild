import UIKit
import UniformTypeIdentifiers

// MARK: - App Path Resolver (Auto-Detect UUID)

struct AppDetectionInfo {
    let appName: String
    let bundleID: String
    let uuid: String
    let fullPath: String
    let isDetected: Bool
}

enum AppPathResolver {
    static let targetBundleID = "com.dts.freefireth"
    static let targetAppName = "Free Fire"
    static let applicationsBaseDir = "/var/mobile/Containers/Data/Application"
    
    /// Scans the application data containers to find the one matching the target bundle ID.
    static func resolveApp() -> AppDetectionInfo {
        let fm = FileManager.default
        let baseDirURL = URL(fileURLWithPath: applicationsBaseDir)
        
        guard let dirs = try? fm.contentsOfDirectory(at: baseDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return AppDetectionInfo(appName: targetAppName, bundleID: targetBundleID, uuid: "Access Denied / Not Jailbroken", fullPath: "", isDetected: false)
        }
        
        for dir in dirs {
            let metadataURL = dir.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            
            if fm.fileExists(atPath: metadataURL.path),
               let data = try? Data(contentsOf: metadataURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let identifier = plist["MCMMetadataIdentifier"] as? String,
               identifier.trimmingCharacters(in: .whitespacesAndNewlines) == targetBundleID {
                
                let uuid = dir.lastPathComponent
                return AppDetectionInfo(appName: targetAppName, bundleID: targetBundleID, uuid: uuid, fullPath: dir.path, isDetected: true)
            }
        }
        
        return AppDetectionInfo(appName: targetAppName, bundleID: targetBundleID, uuid: "NOT FOUND (Verify Jailbreak/TrollStore Permissions)", fullPath: "", isDetected: false)
    }
}

// MARK: - Config Mode Targets

enum ConfigMode {
    case fortyPercent
    case oneHundredPercent
    
    var displayName: String {
        switch self {
        case .fortyPercent: return "40% Asset Modifier"
        case .oneHundredPercent: return "100% Full Variant"
        }
    }
}

// MARK: - Persistent Target Resolution

enum AssetConfig {
    static var targetPath: String {
        let suffix = "/Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
        let detection = AppPathResolver.resolveApp()
        if detection.isDetected {
            return detection.fullPath + suffix
        }
        return "/var/mobile/Containers/Data/Application/UNKNOWN_UUID" + suffix
    }
}

// MARK: - Sandboxed Internal Storage

enum LocalStore {
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static var file40URL: URL { documentsDir.appendingPathComponent("imported_40_percent.data") }
    static var file100URL: URL { documentsDir.appendingPathComponent("imported_100_percent.data") }
    static var automaticBackupURL: URL { documentsDir.appendingPathComponent("original_stock_backup.bak") }
    
    static func hasFile(for mode: ConfigMode) -> Bool {
        let path = mode == .fortyPercent ? file40URL.path : file100URL.path
        return FileManager.default.fileExists(atPath: path)
    }
    
    static func hasBackup() -> Bool {
        return FileManager.default.fileExists(atPath: automaticBackupURL.path)
    }
}

// MARK: - High-Speed File Transport Engine

enum FileOps {
    static func applyConfig(from sourceURL: URL, to livePath: String) throws {
        let fm = FileManager.default
        let destinationURL = URL(fileURLWithPath: livePath)
        
        // 1. Safe Auto-Backup to local App Documents directory before modifying system layers
        if fm.fileExists(atPath: destinationURL.path) && !LocalStore.hasBackup() {
            try? fm.copyItem(at: destinationURL, to: LocalStore.automaticBackupURL)
        }
        
        // 2. Clear target runtime vectors
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        } else {
            let parentDir = destinationURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        // 3. Mount working configuration asset payload
        try fm.copyItem(at: sourceURL, to: destinationURL)
    }
    
    static func restoreStockBackup(to livePath: String) throws {
        let fm = FileManager.default
        let destinationURL = URL(fileURLWithPath: livePath)
        guard fm.fileExists(atPath: LocalStore.automaticBackupURL.path) else { return }
        
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.copyItem(at: LocalStore.automaticBackupURL, to: destinationURL)
    }
}

// MARK: - Functional Closure Extensions

extension UIControl {
    private final class ClosureSleeve {
        let closure: () -> Void
        init(_ closure: @escaping () -> Void) { self.closure = closure }
        @objc func invoke() { closure() }
    }

    func addAction(for event: UIControl.Event = .touchUpInside, _ closure: @escaping () -> Void) {
        let sleeve = ClosureSleeve(closure)
        addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: event)
        objc_setAssociatedObject(self, UUID().uuidString.withCString { UnsafeRawPointer($0) }, sleeve, .OBJC_ASSOCIATION_RETAIN)
    }
}

// MARK: - UI Layer: Reusable Card Controls

final class CardButton: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionIndicator = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill"))
    private let container = UIView()

    init(icon: String, tint: UIColor, title: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        container.isUserInteractionEnabled = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        let iconBackground = UIView()
        iconBackground.backgroundColor = tint.withAlphaComponent(0.12)
        iconBackground.layer.cornerRadius = 12
        iconBackground.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .label

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        actionIndicator.tintColor = tint.withAlphaComponent(0.7)
        actionIndicator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconBackground)
        iconBackground.addSubview(iconView)
        container.addSubview(textStack)
        container.addSubview(actionIndicator)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 76),

            iconBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconBackground.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 46),
            iconBackground.heightAnchor.constraint(equalToConstant: 46),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: actionIndicator.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            actionIndicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            actionIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            actionIndicator.widthAnchor.constraint(equalToConstant: 22),
            actionIndicator.heightAnchor.constraint(equalToConstant: 22)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateSubtitle(_ text: String) { subtitleLabel.text = text }
    func updateIndicatorIcon(_ systemName: String) { actionIndicator.image = UIImage(systemName: systemName) }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.container.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            self.container.alpha = 0.88
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.12) {
            self.container.transform = .identity
            self.container.alpha = 1.0
        }
    }
}

// MARK: - Main Application Dashboard View Controller

final class RootViewController: UIViewController, UIDocumentPickerDelegate {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    // Status Information Elements
    private let infoCard = UIView()
    private let appNameValLabel = UILabel()
    private let bundleIdValLabel = UILabel()
    private let uuidValLabel = UILabel()
    private let pathPreviewLabel = UILabel()

    // Control Interface Elements
    private let import40Button = CardButton(icon: "doc.badge.plus", tint: .systemBlue, title: "Import 40% Variant Payload", subtitle: "Load file into app documents storage")
    private let apply40Button = CardButton(icon: "bolt.circle.fill", tint: .systemOrange, title: "Instantly Inject 40%", subtitle: "No confirmations; active configuration changes instantly")
    
    private let import100Button = CardButton(icon: "doc.badge.plus", tint: .systemPurple, title: "Import 100% Variant Payload", subtitle: "Load file into app documents storage")
    private let apply100Button = CardButton(icon: "flash.diagonal.fill", tint: .systemRed, title: "Instantly Inject 100%", subtitle: "No confirmations; active configuration changes instantly")
    
    private let restoreStockButton = CardButton(icon: "arrow.3.trianglepath", tint: .systemGreen, title: "Restore Original Asset Layout", subtitle: "Revert back using local documents fallback cache")

    private var activePickingMode: ConfigMode?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fast Asset Swapper"
        view.backgroundColor = .systemGroupedBackground
        setupLayoutStructure()
        runEnvironmentScan()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        evaluateFileStatusStates()
    }

    private func setupLayoutStructure() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        setupTargetTrackingCard()
        
        // Assemble View Tree Component Hierarchy
        contentStack.addArrangedSubview(infoCard)
        
        let sectionHeader40 = createHeaderLabel("40% CONFIGURATION OPTIONS")
        contentStack.addArrangedSubview(sectionHeader40)
        contentStack.addArrangedSubview(import40Button)
        contentStack.addArrangedSubview(apply40Button)
        
        let sectionHeader100 = createHeaderLabel("100% CONFIGURATION OPTIONS")
        contentStack.addArrangedSubview(sectionHeader100)
        contentStack.addArrangedSubview(import100Button)
        contentStack.addArrangedSubview(apply100Button)
        
        let sectionHeaderSystem = createHeaderLabel("EMERGENCY RESTORATION TOOLS")
        contentStack.addArrangedSubview(sectionHeaderSystem)
        contentStack.addArrangedSubview(restoreStockButton)

        // Target Control Interactive Binding Hooks
        import40Button.addAction { [weak self] in self?.triggerFileImportTarget(.fortyPercent) }
        import100Button.addAction { [weak self] in self?.triggerFileImportTarget(.oneHundredPercent) }
        
        apply40Button.addAction { [weak self] in self?.executeInstantInjection(.fortyPercent) }
        apply100Button.addAction { [weak self] in self?.executeInstantInjection(.oneHundredPercent) }
        
        restoreStockButton.addAction { [weak self] in self?.executeStockReversion() }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    private func setupTargetTrackingCard() {
        infoCard.backgroundColor = .secondarySystemBackground
        infoCard.layer.cornerRadius = 16
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        
        let infoHeader = UILabel()
        infoHeader.text = "RESOLVED RUNTIME CONFIG TARGET"
        infoHeader.font = .systemFont(ofSize: 11, weight: .bold)
        infoHeader.textColor = .tertiaryLabel
        
        let appStack = createRowInfoStack(title: "App Context:", valLabel: appNameValLabel, boldValue: true)
        let bundleStack = createRowInfoStack(title: "Bundle Core:", valLabel: bundleIdValLabel, isMono: true)
        let uuidStack = createRowInfoStack(title: "Container ID:", valLabel: uuidValLabel, isMono: true)
        
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        
        let targetPathTitle = UILabel()
        targetPathTitle.text = "TARGET RESOLUTION PATH:"
        targetPathTitle.font = .systemFont(ofSize: 10, weight: .bold)
        targetPathTitle.textColor = .secondaryLabel
        
        pathPreviewLabel.numberOfLines = 0
        pathPreviewLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathPreviewLabel.textColor = .label
        
        let trackingVerticalStack = UIStackView(arrangedSubviews: [infoHeader, appStack, bundleStack, uuidStack, separator, targetPathTitle, pathPreviewLabel])
        trackingVerticalStack.axis = .vertical
        trackingVerticalStack.spacing = 8
        trackingVerticalStack.setCustomSpacing(12, after: separator)
        trackingVerticalStack.translatesAutoresizingMaskIntoConstraints = false
        
        infoCard.addSubview(trackingVerticalStack)
        
        NSLayoutConstraint.activate([
            trackingVerticalStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 14),
            trackingVerticalStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -14),
            trackingVerticalStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            trackingVerticalStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14)
        ])
    }
    
    private func createRowInfoStack(title: String, valLabel: UILabel, boldValue: Bool = false, isMono: Bool = false) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .secondaryLabel
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        
        valLabel.font = isMono ? .monospacedSystemFont(ofSize: 12, weight: boldValue ? .bold : .regular) : .systemFont(ofSize: 13, weight: boldValue ? .bold : .regular)
        valLabel.textColor = .label
        valLabel.numberOfLines = 0
        
        let horizontalRow = UIStackView(arrangedSubviews: [titleLabel, valLabel])
        horizontalRow.axis = .horizontal
        horizontalRow.alignment = .top
        return horizontalRow
    }
    
    private func createHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        return label
    }

    private func runEnvironmentScan() {
        let result = AppPathResolver.resolveApp()
        appNameValLabel.text = result.appName
        bundleIdValLabel.text = result.bundleID
        uuidValLabel.text = result.uuid
        uuidValLabel.textColor = result.isDetected ? .label : .systemRed
        
        pathPreviewLabel.text = AssetConfig.targetPath
    }

    private func evaluateFileStatusStates() {
        // Evaluate condition metrics of the 40% variant subsystem
        if LocalStore.hasFile(for: .fortyPercent) {
            import40Button.updateSubtitle("Payload ready inside app container folder")
            import40Button.updateIndicatorIcon("checkmark.circle.fill")
            apply40Button.isEnabled = true
            apply40Button.alpha = 1.0
        } else {
            import40Button.updateSubtitle("No configuration package active — tap to choose file")
            import40Button.updateIndicatorIcon("plus.circle")
            apply40Button.isEnabled = false
            apply40Button.alpha = 0.5
        }
        
        // Evaluate condition metrics of the 100% variant subsystem
        if LocalStore.hasFile(for: .oneHundredPercent) {
            import100Button.updateSubtitle("Payload ready inside app container folder")
            import100Button.updateIndicatorIcon("checkmark.circle.fill")
            apply100Button.isEnabled = true
            apply100Button.alpha = 1.0
        } else {
            import100Button.updateSubtitle("No configuration package active — tap to choose file")
            import100Button.updateIndicatorIcon("plus.circle")
            apply100Button.isEnabled = false
            apply100Button.alpha = 0.5
        }
        
        // Evaluate status metrics for the fallback backup profile
        if LocalStore.hasBackup() {
            restoreStockButton.isEnabled = true
            restoreStockButton.alpha = 1.0
            restoreStockButton.updateSubtitle("Original base backup file preserved in sandboxed safety layout")
        } else {
            restoreStockButton.isEnabled = false
            restoreStockButton.alpha = 0.5
            restoreStockButton.updateSubtitle("No stock file backup captured yet (Generated on first swap action)")
        }
    }

    // MARK: - Operational Target Executions

    private func triggerFileImportTarget(_ mode: ConfigMode) {
        activePickingMode = mode
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func executeInstantInjection(_ mode: ConfigMode) {
        let payloadURL = mode == .fortyPercent ? LocalStore.file40URL : LocalStore.file100URL
        let targetPath = AssetConfig.targetPath
        
        do {
            try FileOps.applyConfig(from: payloadURL, to: targetPath)
            evaluateFileStatusStates()
            
            // Subtle, transient notification layout for rapid action visual profiling
            let alert = UIAlertController(title: "Applied Instantly", message: "Swapped profile execution vector completed.", preferredStyle: .textFields)
            present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
        } catch {
            showRuntimeErrorAlert(error)
        }
    }
    
    private func executeStockReversion() {
        let targetPath = AssetConfig.targetPath
        do {
            try FileOps.restoreStockBackup(to: targetPath)
            let alert = UIAlertController(title: "Restored", message: "Stock configuration re-mounted.", preferredStyle: .textFields)
            present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
        } catch {
            showRuntimeErrorAlert(error)
        }
    }
    
    private func showRuntimeErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "File Operations Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Document Picker Delegate Hooks

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first, let mode = activePickingMode else { return }
        let saveDestination = mode == .fortyPercent ? LocalStore.file40URL : LocalStore.file100URL
        
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: saveDestination.path) {
                try fm.removeItem(at: saveDestination)
            }
            try fm.copyItem(at: pickedURL, to: saveDestination)
            evaluateFileStatusStates()
        } catch {
            showRuntimeErrorAlert(error)
        }
        activePickingMode = nil
    }
    
    func documentPickerDidCancel(_ controller: UIDocumentPickerViewController) {
        activePickingMode = nil
    }
}

// MARK: - Core System Interface Bridge Layout

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootNav = UINavigationController(rootViewController: RootViewController())
        rootNav.navigationBar.prefersLargeTitles = true
        window?.rootViewController = rootNav
        window?.makeKeyAndVisible()
        return true
    }
}
