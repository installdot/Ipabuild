import UIKit
import UniformTypeIdentifiers

// MARK: - Persistent settings

enum Settings {
    static let targetPathKey = "targetFilePath"
    static let defaultTargetPath =
        "/var/mobile/Containers/Data/Application/CD69FE41-53FF-4EE8-A0BC-22181F943960/Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"

    static var targetPath: String {
        get { UserDefaults.standard.string(forKey: targetPathKey) ?? defaultTargetPath }
        set { UserDefaults.standard.set(newValue, forKey: targetPathKey) }
    }
}

// MARK: - Local storage for the Backup / New copies kept inside the app

enum LocalStore {
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var backupFile: URL { documentsDir.appendingPathComponent("backup_file") }
    static var newFile: URL { documentsDir.appendingPathComponent("new_file") }

    static var hasBackup: Bool { FileManager.default.fileExists(atPath: backupFile.path) }
    static var hasNewFile: Bool { FileManager.default.fileExists(atPath: newFile.path) }
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

// MARK: - Root View Controller

final class RootViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let welcomeTitle = UILabel()
    private let welcomeSubtitle = UILabel()

    private let pathCard = UIView()
    private let pathLabel = UILabel()
    private let changePathButton = CardButton(icon: "folder.badge.gearshape",
                                               tint: .systemIndigo,
                                               title: "Change Target Path",
                                               subtitle: "Choose which file gets replaced")

    private let restoreOriginalButton = CardButton(icon: "arrow.uturn.backward.circle.fill",
                                                    tint: .systemGreen,
                                                    title: "Restore Saved Backup",
                                                    subtitle: "Put your saved backup back in place")

    private let applyNewFileButton = CardButton(icon: "shippingbox.fill",
                                                 tint: .systemOrange,
                                                 title: "Apply Imported File",
                                                 subtitle: "Swap in the file you imported")

    private let manageBackupsButton = CardButton(icon: "externaldrive.fill.badge.plus",
                                                  tint: .systemBlue,
                                                  title: "Manage Files",
                                                  subtitle: "Save a backup or import a new file")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Asset Swapper"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        refreshPathLabel()
        refreshSubtitles()

        NotificationCenter.default.addObserver(
            self, selector: #selector(sharedFileReceived),
            name: .receivedSharedFile, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPathLabel()
        refreshSubtitles()
    }

    private func setupUI() {
        // Scroll container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Welcome header
        welcomeTitle.text = "Welcome back 👋"
        welcomeTitle.font = .systemFont(ofSize: 28, weight: .bold)
        welcomeTitle.textColor = .label

        welcomeSubtitle.text = "Manage and swap your cached game asset file in just a couple of taps."
        welcomeSubtitle.font = .systemFont(ofSize: 15)
        welcomeSubtitle.textColor = .secondaryLabel
        welcomeSubtitle.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [welcomeTitle, welcomeSubtitle])
        headerStack.axis = .vertical
        headerStack.spacing = 6

        // Target path card
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

        // Section label helper
        func sectionLabel(_ text: String) -> UILabel {
            let l = UILabel()
            l.text = text
            l.font = .systemFont(ofSize: 13, weight: .semibold)
            l.textColor = .secondaryLabel
            return l
        }

        changePathButton.addTarget(self, action: #selector(tapSetPath), for: .touchUpInside)
        restoreOriginalButton.addTarget(self, action: #selector(tapRestoreOriginal), for: .touchUpInside)
        applyNewFileButton.addTarget(self, action: #selector(tapApplyNew), for: .touchUpInside)
        manageBackupsButton.addTarget(self, action: #selector(tapManageBackups), for: .touchUpInside)

        let actionsStack = UIStackView(arrangedSubviews: [
            sectionLabel("ACTIONS"),
            changePathButton,
            restoreOriginalButton,
            applyNewFileButton,
            manageBackupsButton
        ])
        actionsStack.axis = .vertical
        actionsStack.spacing = 10
        actionsStack.setCustomSpacing(14, after: actionsStack.arrangedSubviews[0])

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(pathCard)
        contentStack.addArrangedSubview(actionsStack)

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

    private func refreshPathLabel() {
        pathLabel.text = Settings.targetPath
    }

    private func refreshSubtitles() {
        restoreOriginalButton.updateSubtitle(
            LocalStore.hasBackup ? "Put your saved backup back in place" : "No backup saved yet"
        )
        applyNewFileButton.updateSubtitle(
            LocalStore.hasNewFile ? "Swap in the file you imported" : "No imported file yet — import one first"
        )
    }

    // MARK: Actions

    @objc private func tapSetPath() {
        let alert = UIAlertController(title: "Change Target Path",
                                       message: "Enter the full path of the file you want to replace",
                                       preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = Settings.targetPath
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            Settings.targetPath = text
            self?.refreshPathLabel()
            self?.showInfo(title: "Saved", message: "Target path updated.")
        })
        present(alert, animated: true)
    }

    @objc private func tapRestoreOriginal() {
        confirmAndRun(title: "Restore Saved Backup",
                      message: "This will replace the current target file with your saved backup copy. Continue?") {
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath),
                                 withContentsOf: LocalStore.backupFile)
        }
    }

    @objc private func tapApplyNew() {
        confirmAndRun(title: "Apply Imported File",
                      message: "This will replace the current target file with the file you imported. Continue?") {
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath),
                                 withContentsOf: LocalStore.newFile)
        }
    }

    @objc private func tapManageBackups() {
        navigationController?.pushViewController(BackupViewController(), animated: true)
    }

    @objc private func sharedFileReceived() {
        refreshSubtitles()
        showInfo(title: "File Received", message: "A shared file was saved. Use \"Apply Imported File\" to swap it in.")
    }

    // MARK: Helpers

    private func confirmAndRun(title: String, message: String, action: @escaping () throws -> Void) {
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

    private let saveCurrentButton = CardButton(icon: "square.and.arrow.down.fill",
                                                tint: .systemGreen,
                                                title: "Save Current File as Backup",
                                                subtitle: "Keeps a safe copy of what's active now")

    private let importFileButton = CardButton(icon: "square.and.arrow.up.fill",
                                               tint: .systemOrange,
                                               title: "Import a New File",
                                               subtitle: "Pick a file from your device to use later")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manage Files"
        view.backgroundColor = .systemGroupedBackground

        let headerLabel = UILabel()
        headerLabel.text = "Backups & Imports"
        headerLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let subLabel = UILabel()
        subLabel.text = "Save a copy of your current file, or bring in a new one to apply later."
        subLabel.font = .systemFont(ofSize: 14)
        subLabel.textColor = .secondaryLabel
        subLabel.numberOfLines = 0

        saveCurrentButton.addTarget(self, action: #selector(tapSaveCurrentAsBackup), for: .touchUpInside)
        importFileButton.addTarget(self, action: #selector(tapImportNew), for: .touchUpInside)

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

    @objc private func tapSaveCurrentAsBackup() {
        let source = URL(fileURLWithPath: Settings.targetPath)
        do {
            try FileOps.replace(destination: LocalStore.backupFile, withContentsOf: source)
            showInfo(title: "Backed Up", message: "Current file saved as your backup.")
        } catch {
            showInfo(title: "Error", message: error.localizedDescription)
        }
    }

    @objc private func tapImportNew() {
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
            try FileOps.replace(destination: LocalStore.newFile, withContentsOf: picked)
            showInfo(title: "Saved", message: "File imported and ready to apply.")
        } catch {
            showInfo(title: "Error", message: error.localizedDescription)
        }
    }

    private func showInfo(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

    // Handles files shared to this app via the system Share Sheet ("Copy to <App>" / "Open in <App>").
    func application(_ app: UIApplication, open url: URL,
                      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileOps.replace(destination: LocalStore.newFile, withContentsOf: url)
            NotificationCenter.default.post(name: .receivedSharedFile, object: nil)
        } catch {
            // Ignore; user can retry via the in-app import button.
        }
        return true
    }
}

extension Notification.Name {
    static let receivedSharedFile = Notification.Name("receivedSharedFile")
}
