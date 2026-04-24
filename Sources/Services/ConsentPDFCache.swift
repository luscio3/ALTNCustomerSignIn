import Foundation

/// Local cache of consent-template PDFs. Downloads once, re-downloads only when server
/// `updatedAt` is newer than the local copy.
///
/// Layout on disk:
///   <Application Support>/ConsentPDFs/<formType>.pdf
///   <Application Support>/ConsentPDFs/metadata.json   (map: formType → updatedAt + id + pagesCount)
actor ConsentPDFCache {
    static let shared = ConsentPDFCache()
    private init() {}

    // MARK: - Metadata (in-memory mirror of metadata.json)

    struct Entry: Codable {
        let id: Int
        let pagesCount: Int
        let updatedAt: Date?
    }
    private var metadata: [ConsentFormType: Entry] = [:]
    private var metadataLoaded = false

    // MARK: - Paths

    private var rootDir: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("ConsentPDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var metaFile: URL { rootDir.appendingPathComponent("metadata.json") }
    private func pdfFile(_ type: ConsentFormType) -> URL {
        rootDir.appendingPathComponent("\(type.rawValue).pdf")
    }

    // MARK: - Public API

    /// Re-download any template whose server `updatedAt` is newer than the local copy.
    /// Returns the list of form types that were refreshed (useful for logging).
    @discardableResult
    func refreshAll() async -> [ConsentFormType] {
        await ensureMetadataLoaded()
        let api = ConsentFormsAPI()
        let templates: [ConsentForm]
        do {
            templates = try await api.fetchTemplates()
        } catch {
            return []
        }

        // Split into "just update metadata" vs "actually download".
        var toDownload: [(ConsentForm, ConsentFormType)] = []
        for t in templates {
            guard let formType = t.formType else { continue }
            let oldUpdated = metadata[formType]?.updatedAt
            let newUpdated = t.updatedAt
            let shouldDownload =
                !fileExists(formType) ||
                (oldUpdated == nil) ||
                (newUpdated.map { (oldUpdated ?? .distantPast) < $0 } ?? false)
            if shouldDownload {
                toDownload.append((t, formType))
            } else {
                metadata[formType] = Entry(id: t.id, pagesCount: t.pagesCount, updatedAt: oldUpdated ?? newUpdated)
            }
        }

        // Download the needed templates in parallel.
        let results: [(ConsentFormType, Data, ConsentForm)] = await withTaskGroup(
            of: (ConsentFormType, Data, ConsentForm)?.self
        ) { group in
            for (template, formType) in toDownload {
                group.addTask {
                    guard let data = try? await api.downloadTemplatePdf(from: template.fileUrl) else { return nil }
                    return (formType, data, template)
                }
            }
            var out: [(ConsentFormType, Data, ConsentForm)] = []
            for await item in group { if let item { out.append(item) } }
            return out
        }

        var refreshed: [ConsentFormType] = []
        for (formType, data, template) in results {
            do {
                try data.write(to: pdfFile(formType), options: .atomic)
                metadata[formType] = Entry(id: template.id, pagesCount: template.pagesCount, updatedAt: template.updatedAt)
                refreshed.append(formType)
            } catch {
                continue
            }
        }
        saveMetadata()
        return refreshed
    }

    func pdfData(_ type: ConsentFormType) async -> Data? {
        await ensureMetadataLoaded()
        let f = pdfFile(type)
        return try? Data(contentsOf: f)
    }

    func pdfURL(_ type: ConsentFormType) async -> URL? {
        await ensureMetadataLoaded()
        let f = pdfFile(type)
        return FileManager.default.fileExists(atPath: f.path) ? f : nil
    }

    func entry(_ type: ConsentFormType) async -> Entry? {
        await ensureMetadataLoaded()
        return metadata[type]
    }

    // MARK: - Internals

    private func ensureMetadataLoaded() async {
        guard !metadataLoaded else { return }
        metadataLoaded = true
        guard let data = try? Data(contentsOf: metaFile),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }
        var out: [ConsentFormType: Entry] = [:]
        for (k, v) in dict {
            if let t = ConsentFormType(rawValue: k) { out[t] = v }
        }
        metadata = out
    }

    private func saveMetadata() {
        let dict = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: metaFile, options: .atomic)
        }
    }

    private func fileExists(_ type: ConsentFormType) -> Bool {
        FileManager.default.fileExists(atPath: pdfFile(type).path)
    }
}
