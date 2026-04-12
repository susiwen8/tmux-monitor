import Foundation

enum SharedSnapshotStoreError: Error {
    case suiteUnavailable(String)
    case encodeFailed
    case decodeFailed
}

struct SharedSnapshotStore {
    private let userDefaults: UserDefaults?
    private let suiteName: String
    private let key: String
    private let fileManager: FileManager

    init(
        suiteName: String = AppConstants.appGroupID,
        key: String = AppConstants.snapshotDefaultsKey,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = UserDefaults(suiteName: suiteName)
        self.suiteName = suiteName
        self.key = key
        self.fileManager = fileManager
    }

    func load() throws -> TmuxSnapshot? {
        var sawFile = false

        for fileURL in readCandidateFileURLs() where fileManager.fileExists(atPath: fileURL.path) {
            sawFile = true
            do {
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(TmuxSnapshot.self, from: data)
            } catch {
                continue
            }
        }

        guard let userDefaults else {
            if sawFile {
                throw SharedSnapshotStoreError.decodeFailed
            }
            throw SharedSnapshotStoreError.suiteUnavailable(suiteName)
        }

        guard let data = userDefaults.data(forKey: key) else {
            if sawFile {
                throw SharedSnapshotStoreError.decodeFailed
            }
            return nil
        }

        do {
            return try JSONDecoder().decode(TmuxSnapshot.self, from: data)
        } catch {
            throw SharedSnapshotStoreError.decodeFailed
        }
    }

    func save(_ snapshot: TmuxSnapshot) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            throw SharedSnapshotStoreError.encodeFailed
        }

        var wroteFile = false
        for fileURL in writeCandidateFileURLs() {
            do {
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try data.write(to: fileURL, options: .atomic)
                wroteFile = true
            } catch {
                continue
            }
        }

        guard let userDefaults else {
            if wroteFile {
                return
            }
            throw SharedSnapshotStoreError.suiteUnavailable(suiteName)
        }

        userDefaults.set(data, forKey: key)
    }

    private func readCandidateFileURLs() -> [URL] {
        var urls: [URL] = []
        if let groupURL = groupContainerSnapshotURL() {
            urls.append(groupURL)
        }
        urls.append(contentsOf: auxiliaryContainerSnapshotURLs())
        return uniqueURLs(urls)
    }

    private func writeCandidateFileURLs() -> [URL] {
        var urls: [URL] = []
        if let groupURL = groupContainerSnapshotURL() {
            urls.append(groupURL)
        }
        urls.append(contentsOf: auxiliaryContainerSnapshotURLs())
        return uniqueURLs(urls)
    }

    private func groupContainerSnapshotURL() -> URL? {
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            return snapshotFileURL(inside: containerURL)
        }

        let fallbackBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers", isDirectory: true)
            .appendingPathComponent(suiteName, isDirectory: true)
        if fileManager.fileExists(atPath: fallbackBase.path) {
            return snapshotFileURL(inside: fallbackBase)
        }
        return nil
    }

    private func auxiliaryContainerSnapshotURLs() -> [URL] {
        let base = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers", isDirectory: true)
        let bundleIDs = [
            AppConstants.appBundleID,
            AppConstants.widgetBundleID,
        ]

        return bundleIDs.compactMap { bundleID in
            let containerURL = base
                .appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent("Data", isDirectory: true)
            guard fileManager.fileExists(atPath: containerURL.path) else {
                return nil
            }
            return snapshotFileURL(inside: containerURL)
        }
    }

    private func snapshotFileURL(inside containerURL: URL) -> URL {
        containerURL
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(AppConstants.snapshotFileName)
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            if seen.contains(path) {
                return false
            }
            seen.insert(path)
            return true
        }
    }
}
