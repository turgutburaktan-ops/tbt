import UIKit
import UniformTypeIdentifiers

// The extension is independent of Flutter. Providers finish one at a time so
// unordered callbacks cannot truncate an album or overwrite another image.
final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let caption = UITextView()
    private let save = UIButton(type: .system)
    private var providers: [NSItemProvider] = []
    private var items: [[String: Any]] = []
    private var folder: URL?
    private var totalBytes = 0
    private var saved = false
    private var cancelled = false
    private let groupID = "group.com.tbt.social.share"

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(red: 0.055, green: 0.063, blue: 0.071, alpha: 1)
        let title = UILabel(); title.text = "TBT’ye aktar"; title.font = .boldSystemFont(ofSize: 25)
        status.text = "İçerik hazırlanıyor…"; status.numberOfLines = 0
        caption.font = .systemFont(ofSize: 17); caption.backgroundColor = .secondarySystemBackground
        caption.layer.cornerRadius = 14
        caption.heightAnchor.constraint(equalToConstant: 130).isActive = true
        save.setTitle("Taslağı kaydet", for: .normal); save.isEnabled = false
        save.titleLabel?.font = .boldSystemFont(ofSize: 18)
        save.addTarget(self, action: #selector(saveDraft), for: .touchUpInside)
        let cancel = UIButton(type: .system); cancel.setTitle("Vazgeç", for: .normal)
        cancel.addTarget(self, action: #selector(close), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, status, caption, save, cancel])
        stack.axis = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30)])
        let incoming = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        providers = incoming.flatMap { $0.attachments ?? [] }
        caption.text = incoming.compactMap { $0.attributedContentText?.string }.joined(separator: "\n")
        guard !providers.isEmpty, providers.count <= 20,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            status.text = "İçerik alınamadı. Tek seferde en fazla 20 dosya seçebilirsin."; return
        }
        folder = container.appendingPathComponent("TBTIncoming/\(UUID().uuidString)", isDirectory: true)
        do { try FileManager.default.createDirectory(at: folder!, withIntermediateDirectories: true) }
        catch { status.text = "Taslak alanı açılamadı."; return }
        loadNext(0)
    }

    private func loadNext(_ index: Int) {
        guard !cancelled else { return }
        if index == providers.count {
            status.text = "\(items.count) içerik hazır. TBT’de düzenleyip paylaşabilirsin."
            save.isEnabled = !items.isEmpty; return
        }
        let provider = providers[index]
        let options: [(UTType, String)] = [(.movie, "video"), (.image, "image"), (.url, "url"), (.text, "text")]
        guard let choice = options.first(where: { provider.hasItemConformingToTypeIdentifier($0.0.identifier) }) else {
            status.text = "Seçimde desteklenmeyen bir dosya var. Fotoğraf, video veya bağlantı seç."; return
        }
        provider.loadItem(forTypeIdentifier: choice.0.identifier, options: nil) { [weak self] value, error in
            guard let self = self else { return }
            // Process one provider at a time without blocking the extension UI.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if let error = error { throw error }
                    let path: String
                    if choice.1 == "url", let url = value as? URL { path = url.absoluteString }
                    else if choice.1 == "text", let text = value as? String { path = text }
                    else if choice.1 == "text", let text = value as? NSAttributedString { path = text.string }
                    else if let source = value as? URL, source.isFileURL {
                        let scoped = source.startAccessingSecurityScopedResource()
                        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                        let bytes = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        try self.checkSize(bytes, video: choice.1 == "video")
                        let suffix = source.pathExtension.isEmpty ? (choice.1 == "video" ? "mp4" : "jpg") : source.pathExtension
                        let target = self.folder!.appendingPathComponent("\(index).\(suffix)")
                        try FileManager.default.copyItem(at: source, to: target)
                        path = target.path
                    } else if choice.1 == "image", let image = value as? UIImage, let data = image.pngData() {
                        try self.checkSize(data.count, video: false)
                        let target = self.folder!.appendingPathComponent("\(index).png")
                        try data.write(to: target, options: .atomic); path = target.path
                    } else if choice.1 == "image", let data = value as? Data {
                        guard let image = UIImage(data: data), let png = image.pngData() else { throw NSError(domain: "TBTShare", code: 2) }
                        try self.checkSize(png.count, video: false)
                        let target = self.folder!.appendingPathComponent("\(index).png")
                        try png.write(to: target, options: .atomic); path = target.path
                    } else { throw NSError(domain: "TBTShare", code: 3) }
                    DispatchQueue.main.async {
                        guard !self.cancelled else { return }
                        self.items.append(["path": path, "type": choice.1])
                        self.loadNext(index + 1)
                    }
                } catch {
                    DispatchQueue.main.async {
                        if !self.cancelled { self.status.text = "İçerik alınamadı. Fotoğraf en fazla 40 MB, toplam aktarım en fazla 250 MB olabilir." }
                    }
                }
            }
        }
    }
    private func checkSize(_ bytes: Int, video: Bool) throws {
        guard bytes > 0, bytes <= (video ? 250 : 40) * 1024 * 1024, totalBytes + bytes <= 250 * 1024 * 1024 else { throw NSError(domain: "TBTShare", code: 4) }
        totalBytes += bytes
    }
    @objc private func saveDraft() {
        if saved { extensionContext?.completeRequest(returningItems: nil); return }
        guard let defaults = UserDefaults(suiteName: groupID), let data = try? JSONSerialization.data(withJSONObject: items), !items.isEmpty else { return }
        defaults.set(data, forKey: "ShareKey"); defaults.set(caption.text, forKey: "ShareMessageKey")
        saved = true; save.isEnabled = false
        // Use the supported extension API. If this extension point declines,
        // the host consumes the saved draft the next time the user opens TBT.
        let url = URL(string: "ShareMedia-com.tbt.social:share")!
        extensionContext?.open(url, completionHandler: { [weak self] opened in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if opened { self.extensionContext?.completeRequest(returningItems: nil) }
                else { self.status.text = "Taslağın kaydedildi. TBT’yi açarak düzenleyip paylaşabilirsin."; self.save.setTitle("Tamam", for: .normal); self.save.isEnabled = true }
            }
        })
    }
    @objc private func close() {
        cancelled = true
        if !saved, let folder = folder { try? FileManager.default.removeItem(at: folder) }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
