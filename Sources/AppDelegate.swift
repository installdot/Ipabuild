import UIKit
import UniformTypeIdentifiers

// MARK: - App Path Resolver (Auto-Detect UUID)

enum AppPathResolver {
    static let targetBundleID = "com.dts.freefiremax"
    static let applicationsBaseDir = "/var/mobile/Containers/Data/Application"
    
    /// Scans the application data containers to find the one matching the target bundle ID.
    static func findDataContainerPath() -> String? {
        let fm = FileManager.default
        let baseDirURL = URL(fileURLWithPath: applicationsBaseDir)
        
        guard let dirs = try? fm.contentsOfDirectory(at: baseDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return nil
        }
        
        for dir in dirs {
            let metadataURL = dir.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            
            if let data = try? Data(contentsOf: metadataURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let identifier = plist["MCMMetadataIdentifier"] as? String,
               identifier == targetBundleID {
                return dir.path
            }
        }
        
        return nil
    }
}

// MARK: - Asset slots

/// Represents the independently-managed target file.
enum AssetSlot: CaseIterable {
    case primary

    var displayName: String {
        return "Main Cache File"
    }

    var defaultPath: String {
        let suffix = "/Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        
        if let detectedPath = AppPathResolver.findDataContainerPath() {
            return detectedPath + suffix
        }
        
        // Fallback if the folder isn't found or permissions are lacking
        return "/var/mobile/Containers/Data/Application/UNKNOWN_UUID" + suffix
    }

    fileprivate var pathDefaultsKey: String {
        return "targetFilePath"
    }

    fileprivate var backupFileName: String {
        return "backup_file"
    }

    fileprivate var newFileName: String {
        return "new_file"
    }
}

// MARK: - Persistent settings

enum Settings {
    static func targetPath(for slot: AssetSlot) -> String {
        UserDefaults.standard.string(forKey: slot.pathDefaultsKey) ?? slot.defaultPath
    }

    static func setTargetPath(_ path: String, for slot: AssetSlot) {
        UserDefaults.standard.set(path, forKey: slot.pathDefaultsKey)
    }
}

// MARK: - Local storage for the Backup / New copies kept inside the app

enum LocalStore {
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func backupFile(for slot: AssetSlot) -> URL {
        documentsDir.appendingPathComponent(slot.backupFileName)
    }

    static func newFile(for slot: AssetSlot) -> URL {
        documentsDir.appendingPathComponent(slot.newFileName)
    }

    static func hasBackup(for slot: AssetSlot) -> Bool {
        FileManager.default.fileExists(atPath: backupFile(for: slot).path)
    }

    static func hasNewFile(for slot: AssetSlot) -> Bool {
        FileManager.default.fileExists(atPath: newFile(for: slot).path)
    }
}

// MARK: - File operations

enum FileOps {
    enum OpError: Error, LocalizedError {
        case sourceMissing(String)
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .sourceMissing(let p): return "File not found: \(p)"
            case .copyFailed(let msg): return "Copy failed: \(msg)"
            }
        }
    }

    /// Overwrite `destination` with the contents of `source`.
    static func replace(destination: URL, withContentsOf source: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else {
            throw OpError.sourceMissing(source.path)
        }
        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            } else {
                let dir = destination.deletingLastPathComponent()
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw OpError.copyFailed(error.localizedDescription)
        }
    }
}

// MARK: - Closure-based control actions

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

// MARK: - Reusable "card" button with icon, title & subtitle

final class CardButton: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
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
        iconBackground.backgroundColor = tint.withAlphaComponent(0.15)
        iconBackground.layer.cornerRadius = 12
        iconBackground.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        container.addSubview(iconBackground)
        iconBackground.addSubview(iconView)
        container.addSubview(textStack)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 72),

            iconBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconBackground.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 44),
            iconBackground.heightAnchor.constraint(equalToConstant: 44),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateSubtitle(_ text: String) { subtitleLabel.text = text }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.12) {
            self.container.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.container.alpha = 0.85
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.15) {
            self.container.transform = .identity
            self.container.alpha = 1.0
        }
    }
}

// MARK: - One self-contained section (path card + action buttons) for a single AssetSlot

final class SlotSectionView: UIStackView {
    let slot: AssetSlot

    private let pathLabel = UILabel()
    private let restoreButton: CardButton
    private let applyButton: CardButton

    weak var presenter: UIViewController?

    init(slot: AssetSlot) {
        self.slot = slot

        let changePathButton = CardButton(icon: "folder.badge.gearshape",
                                           tint: .systemIndigo,
                                           title: "Change Target Path",
                                           subtitle: "Choose which file gets replaced")

        restoreButton = CardButton(icon: "arrow.uturn.backward.circle.fill",
                                    tint: .systemGreen,
                                    title: "Restore Saved Backup",
                                    subtitle: "Put your saved backup back in place")

        applyButton = CardButton(icon: "shippingbox.fill",
                                  tint: .systemOrange,
                                  title: "Apply Imported File",
                                  subtitle: "Swap in the file you imported")

        let manageBackupsButton = CardButton(icon: "externaldrive.fill.badge.plus",
                                              tint: .systemBlue,
                                              title: "Manage Files",
                                              subtitle: "Save a backup or import a new file")

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        axis = .vertical
        spacing = 10

        // Section header
        let sectionLabel = UILabel()
        sectionLabel.text = slot.displayName.uppercased()
        sectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        sectionLabel.textColor = .secondaryLabel

        // Path card
        let pathCard = UIView()
        pathCard.backgroundColor = .secondarySystemBackground
        pathCard.layer.cornerRadius = 16
        pathCard.translatesAutoresizingMaskIntoConstraints = false

        let pathTitleLabel = UILabel()
        pathTitleLabel.text = "CURRENT TARGET FILE"
        pathTitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        pathTitleLabel.textColor = .tertiaryLabel

        pathLabel.numberOfLines = 0
        pathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathLabel.textColor = .label

        let pathInnerStack = UIStackView(arrangedSubviews: [pathTitleLabel, pathLabel])
        pathInnerStack.axis = .vertical
        pathInnerStack.spacing = 6
        pathInnerStack.translatesAutoresizingMaskIntoConstraints = false
        pathCard.addSubview(pathInnerStack)

        NSLayoutConstraint.activate([
            pathInnerStack.topAnchor.constraint(equalTo: pathCard.topAnchor, constant: 14),
            pathInnerStack.bottomAnchor.constraint(equalTo: pathCard.bottomAnchor, constant: -14),
            pathInnerStack.leadingAnchor.constraint(equalTo: pathCard.leadingAnchor, constant: 16),
            pathInnerStack.trailingAnchor.constraint(equalTo: pathCard.trailingAnchor, constant: -16)
        ])

        addArrangedSubview(sectionLabel)
        addArrangedSubview(pathCard)
        addArrangedSubview(changePathButton)
        addArrangedSubview(restoreButton)
        addArrangedSubview(applyButton)
        addArrangedSubview(manageBackupsButton)
        setCustomSpacing(14, after: sectionLabel)
        setCustomSpacing(14, after: pathCard)

        changePathButton.addAction { [weak self] in self?.tapSetPath() }
        restoreButton.addAction { [weak self] in self?.tapRestoreOriginal() }
        applyButton.addAction { [weak self] in self?.tapApplyNew() }
        manageBackupsButton.addAction { [weak self] in self?.tapManageBackups() }

        refresh()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        pathLabel.text = Settings.targetPath(for: slot)
        restoreButton.updateSubtitle(
            LocalStore.hasBackup(for: slot) ? "Put your saved backup back in place" : "No backup saved yet"
        )
        applyButton.updateSubtitle(
            LocalStore.hasNewFile(for: slot) ? "Swap in the file you imported" : "No imported file yet — import one first"
        )
    }

    private func tapSetPath() {
        let alert = UIAlertController(title: "Change Target Path (\(slot.displayName))",
                                       message: "Enter the full path of the file you want to replace",
                                       preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = Settings.targetPath(for: self.slot)
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            Settings.setTargetPath(text, for: self.slot)
            self.refresh()
            self.presenter?.showInfo(title: "Saved", message: "Target path updated.")
        })
        presenter?.present(alert, animated: true)
    }

    private func tapRestoreOriginal() {
        presenter?.confirmAndRun(
            title: "Restore Saved Backup",
            message: "This will replace the current \(slot.displayName) target file with your saved backup copy. Continue?"
        ) { [slot] in
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath(for: slot)),
                                 withContentsOf: LocalStore.backupFile(for: slot))
        }
    }

    private func tapApplyNew() {
        presenter?.confirmAndRun(
            title: "Apply Imported File",
            message: "This will replace the current \(slot.displayName) target file with the file you imported. Continue?"
        ) { [slot] in
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath(for: slot)),
                                 withContentsOf: LocalStore.newFile(for: slot))
        }
    }

    private func tapManageBackups() {
        guard let presenter else { return }
        presenter.navigationController?.pushViewController(BackupViewController(slot: slot), animated: true)
    }
}

// MARK: - Root View Controller

final class RootViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let welcomeTitle = UILabel()
    private let welcomeSubtitle = UILabel()

    private var slotSections: [SlotSectionView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Asset Swapper"
        view.backgroundColor = .systemGroupedBackground
        setupUI()

        NotificationCenter.default.addObserver(
            self, selector: #selector(sharedFileReceived(_:)),
            name: .receivedSharedFile, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        slotSections.forEach { $0.refresh() }
    }

    private func setupUI() {
        // Scroll container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Welcome header
        welcomeTitle.text = "Welcome back 👋"
        welcomeTitle.font = .systemFont(ofSize: 28, weight: .bold)
        welcomeTitle.textColor = .label

        welcomeSubtitle.text = "Manage and swap your cached game asset files in just a couple of taps."
        welcomeSubtitle.font = .systemFont(ofSize: 15)
        welcomeSubtitle.textColor = .secondaryLabel
        welcomeSubtitle.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [welcomeTitle, welcomeSubtitle])
        headerStack.axis = .vertical
        headerStack.spacing = 6

        contentStack.addArrangedSubview(headerStack)

        // One independent section per asset slot
        for slot in AssetSlot.allCases {
            let section = SlotSectionView(slot: slot)
            section.presenter = self
            slotSections.append(section)
            contentStack.addArrangedSubview(section)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: Shared file handling

    /// A file was shared into the app via the system Share Sheet.
    @objc private func sharedFileReceived(_ note: Notification) {
        guard let url = note.userInfo?[Notification.SharedFileKeys.url] as? URL else { return }
        
        // Since there is only one slot now, we automatically stage it for .primary
        stageSharedFile(url, for: .primary)
    }

    private func stageSharedFile(_ url: URL, for slot: AssetSlot) {
        do {
            try FileOps.replace(destination: LocalStore.newFile(for: slot), withContentsOf: url)
            slotSections.first(where: { $0.slot as AssetSlot == slot })?.refresh()
            showInfo(title: "Saved", message: "File staged for \(slot.displayName). Use \"Apply Imported File\" to swap it in.")
        } catch {
            showInfo(title: "Error", message: error.localizedDescription)
        }
    }
}

// MARK: - Shared present/confirm helpers used by both the root VC and slot sections

extension UIViewController {
    func confirmAndRun(title: String, message: String, action: @escaping () throws -> Void) {
        let confirm = UIAlertController(title: title, message: message, preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Replace", style: .destructive) { [weak self] _ in
            do {
                try action()
                self?.showInfo(title: "Done", message: "File replaced successfully.")
            } catch {
                self?.showInfo(title: "Error", message: error.localizedDescription)
            }
        })
        present(confirm, animated: true)
    }

    func showInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Backup View Controller

final class BackupViewController: UIViewController, UIDocumentPickerDelegate {

    private let slot: AssetSlot

    private let saveCurrentButton = CardButton(icon: "square.and.arrow.down.fill",
                                                tint: .systemGreen,
                                                title: "Save Current File as Backup",
                                                subtitle: "Keeps a safe copy of what's active now")

    private let importFileButton = CardButton(icon: "square.and.arrow.up.fill",
                                               tint: .systemOrange,
                                               title: "Import a New File",
                                               subtitle: "Pick a file from your device to use later")

    init(slot: AssetSlot) {
        self.slot = slot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manage Files"
        view.backgroundColor = .systemGroupedBackground

        let headerLabel = UILabel()
        headerLabel.text = slot.displayName
        headerLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let subLabel = UILabel()
        subLabel.text = "Save a copy of this file, or bring in a new one to apply later."
        subLabel.font = .systemFont(ofSize: 14)
        subLabel.textColor = .secondaryLabel
        subLabel.numberOfLines = 0

        saveCurrentButton.addAction { [weak self] in self?.tapSaveCurrentAsBackup() }
        importFileButton.addAction { [weak self] in self?.tapImportNew() }

        let stack = UIStackView(arrangedSubviews: [headerLabel, subLabel, saveCurrentButton, importFileButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(4, after: headerLabel)
        stack.setCustomSpacing(24, after: subLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    private func tapSaveCurrentAsBackup() {
        let source = URL(fileURLWithPath: Settings.targetPath(for: slot))
        do {
            try FileOps.replace(destination: LocalStore.backupFile(for: slot), withContentsOf: source)
            showInfo(title: "Backed Up", message: "Current \(slot.displayName) file saved as your backup.")
        } catch {
            showInfo(title: "Error", message: error.localizedDescription)
        }
    }

    private func tapImportNew() {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        }
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let picked = urls.first else { return }
        do {
            try FileOps.replace(destination: LocalStore.newFile(for: slot), withContentsOf: picked)
            showInfo(title: "Saved", message: "File imported and ready to apply to \(slot.displayName).")
        } catch {
            showInfo(title: "Error", message: error.localizedDescription)
        }
    }
}

// MARK: - App Delegate

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController(rootViewController: RootViewController())
        nav.navigationBar.prefersLargeTitles = true
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()

        let stagedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)

        do {
            try FileOps.replace(destination: stagedURL, withContentsOf: url)
            if accessed { url.stopAccessingSecurityScopedResource() }
            NotificationCenter.default.post(name: .receivedSharedFile,
                                             object: nil,
                                             userInfo: [Notification.SharedFileKeys.url: stagedURL])
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return true
    }
}

extension Notification.Name {
    static let receivedSharedFile = Notification.Name("receivedSharedFile")
}

extension Notification {
    enum SharedFileKeys {
        static let url = "url"
    }
}
