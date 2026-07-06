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

// MARK: - Root View Controller

final class RootViewController: UIViewController {

    private let pathLabel = UILabel()
    private let setPathButton = UIButton(type: .system)
    private let originalButton = UIButton(type: .system)
    private let newButton = UIButton(type: .system)
    private let backupButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Asset Swapper"
        view.backgroundColor = .systemBackground
        setupUI()
        refreshPathLabel()

        NotificationCenter.default.addObserver(
            self, selector: #selector(sharedFileReceived),
            name: .receivedSharedFile, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPathLabel()
    }

    private func setupUI() {
        pathLabel.numberOfLines = 0
        pathLabel.font = .systemFont(ofSize: 13)
        pathLabel.textColor = .secondaryLabel
        pathLabel.textAlignment = .center

        configure(setPathButton, title: "Set Path", action: #selector(tapSetPath))
        configure(originalButton, title: "Original", action: #selector(tapOriginal))
        configure(newButton, title: "New", action: #selector(tapNew))
        configure(backupButton, title: "Backup", action: #selector(tapBackup))

        let stack = UIStackView(arrangedSubviews: [pathLabel, setPathButton, originalButton, newButton, backupButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configure(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func refreshPathLabel() {
        pathLabel.text = "Target:\n\(Settings.targetPath)"
    }

    // MARK: Actions

    @objc private func tapSetPath() {
        let alert = UIAlertController(title: "Set Target File Path",
                                       message: "Full path to the game asset file",
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
            self?.showInfo(title: "Saved", message: "Path updated.")
        })
        present(alert, animated: true)
    }

    @objc private func tapOriginal() {
        confirmAndRun(title: "Restore Backup",
                      message: "Replace the current file at the target path with your saved Backup copy?") {
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath),
                                 withContentsOf: LocalStore.backupFile)
        }
    }

    @objc private func tapNew() {
        confirmAndRun(title: "Apply New File",
                      message: "Replace the current file at the target path with your uploaded New file?") {
            try FileOps.replace(destination: URL(fileURLWithPath: Settings.targetPath),
                                 withContentsOf: LocalStore.newFile)
        }
    }

    @objc private func tapBackup() {
        navigationController?.pushViewController(BackupViewController(), animated: true)
    }

    @objc private func sharedFileReceived() {
        showInfo(title: "File Received", message: "A shared file was saved as New. Use the New button to apply it.")
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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Backup"
        view.backgroundColor = .systemBackground

        let originalButton = UIButton(type: .system)
        originalButton.setTitle("Original (save current file as Backup)", for: .normal)
        originalButton.titleLabel?.numberOfLines = 0
        originalButton.titleLabel?.textAlignment = .center
        originalButton.addTarget(self, action: #selector(tapSaveCurrentAsBackup), for: .touchUpInside)

        let newButton = UIButton(type: .system)
        newButton.setTitle("New (import a file)", for: .normal)
        newButton.addTarget(self, action: #selector(tapImportNew), for: .touchUpInside)

        [originalButton, newButton].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            $0.backgroundColor = .secondarySystemBackground
            $0.layer.cornerRadius = 10
            $0.heightAnchor.constraint(equalToConstant: 60).isActive = true
        }

        let stack = UIStackView(arrangedSubviews: [originalButton, newButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func tapSaveCurrentAsBackup() {
        let source = URL(fileURLWithPath: Settings.targetPath)
        do {
            try FileOps.replace(destination: LocalStore.backupFile, withContentsOf: source)
            showInfo(title: "Backed Up", message: "Current file saved as Backup.")
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
            showInfo(title: "Saved", message: "File saved as New.")
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
            // Ignore; user can retry via the in-app "New" import button.
        }
        return true
    }
}

extension Notification.Name {
    static let receivedSharedFile = Notification.Name("receivedSharedFile")
}
