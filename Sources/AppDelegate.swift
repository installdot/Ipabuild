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
        
        return AppDetectionInfo(appName: targetAppName, bundleID: targetBundleID, uuid: "NOT FOUND", fullPath: "", isDetected: false)
    }
}

// MARK: - Config Mode Targets

enum ConfigMode {
    case fortyPercent
    case oneHundredPercent
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
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
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
            heightAnchor.constraint(equalToConstant: 80),

            iconBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconBackground.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 50),
            iconBackground.heightAnchor.constraint(equalToConstant: 50),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            textStack.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: actionIndicator.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            actionIndicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            actionIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            actionIndicator.widthAnchor.constraint(equalToConstant: 24),
            actionIndicator.heightAnchor.constraint(equalToConstant: 24)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateSubtitle(_ text: String) { subtitleLabel.text = text }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.container.alpha = 0.85
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
    
    // Core 4 UI Buttons
    private let detectButton = CardButton(icon: "magnifyingglass", tint: .systemTeal, title: "Detect UUID", subtitle: "Find the Free Fire container directory")
    private let apply40Button = CardButton(icon: "bolt.fill", tint: .systemOrange, title: "40%", subtitle: "Instantly Inject 40% Payload")
    private let apply100Button = CardButton(icon: "flash.diagonal.fill", tint: .systemRed, title: "100%", subtitle: "Instantly Inject 100% Payload")
    private let fileButton = CardButton(icon: "folder.fill", tint: .systemBlue, title: "File", subtitle: "Import payload files or restore original")

    private var activePickingMode: ConfigMode?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fast Asset Swapper"
        view.backgroundColor = .systemGroupedBackground
        setupLayoutStructure()
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
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Add Only the 4 Buttons
        contentStack.addArrangedSubview(detectButton)
        contentStack.addArrangedSubview(apply40Button)
        contentStack.addArrangedSubview(apply100Button)
        contentStack.addArrangedSubview(fileButton)

        // Assign Actions
        detectButton.addAction { [weak self] in self?.executeDetect() }
        apply40Button.addAction { [weak self] in self?.executeInstantInjection(.fortyPercent) }
        apply100Button.addAction { [weak self] in self?.executeInstantInjection(.oneHundredPercent) }
        fileButton.addAction { [weak self] in self?.showFileMenu() }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16), // Fixed syntax
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    private func evaluateFileStatusStates() {
        let has40 = LocalStore.hasFile(for: .fortyPercent)
        apply40Button.updateSubtitle(has40 ? "Ready to inject" : "No file set - Tap 'File' to import")
        apply40Button.alpha = has40 ? 1.0 : 0.6
        apply40Button.isEnabled = has40
        
        let has100 = LocalStore.hasFile(for: .oneHundredPercent)
        apply100Button.updateSubtitle(has100 ? "Ready to inject" : "No file set - Tap 'File' to import")
        apply100Button.alpha = has100 ? 1.0 : 0.6
        apply100Button.isEnabled = has100
    }

    // MARK: - Actions

    private func executeDetect() {
        let result = AppPathResolver.resolveApp()
        let message = result.isDetected ? "Target App: \(result.appName)\nUUID: \(result.uuid)" : "Could not map folder containing standard runtime plists."
        
        let alert = UIAlertController(title: "UUID Detection", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showFileMenu() {
        let alert = UIAlertController(title: "Manage Files", message: "Assign payload files or restore the default game asset.", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Set 40% File", style: .default) { [weak self] _ in
            self?.triggerFileImportTarget(.fortyPercent)
        })
        
        alert.addAction(UIAlertAction(title: "Set 100% File", style: .default) { [weak self] _ in
            self?.triggerFileImportTarget(.oneHundredPercent)
        })
        
        alert.addAction(UIAlertAction(title: "Restore Original Asset", style: .destructive) { [weak self] _ in
            self?.executeStockReversion()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = fileButton
            popover.sourceRect = fileButton.bounds
        }
        
        present(alert, animated: true)
    }

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
            
            // Fixed UI Alert Style (.alert instead of .textFields)
            let alert = UIAlertController(title: "Applied Instantly", message: "Swapped profile execution vector completed.", preferredStyle: .alert)
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
            
            // Fixed UI Alert Style (.alert instead of .textFields)
            let alert = UIAlertController(title: "Restored", message: "Stock configuration re-mounted.", preferredStyle: .alert)
            present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
        } catch {
            showRuntimeErrorAlert(error)
        }
    }
    
    private func showRuntimeErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
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
