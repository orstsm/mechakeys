import Foundation
import Combine

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ text: String) {
        let tag = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let fields = tag.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3 else { return nil }
        var numbers: [Int] = []
        for field in fields {
            guard !field.isEmpty, field.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                  let number = Int(field), number >= 0 else { return nil }
            numbers.append(number)
        }
        parts = numbers
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
    let draft: Bool
    let prerelease: Bool

    var safeURL: URL? {
        guard let url = URL(string: html_url), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.hasPrefix("/orstsm/mechakeys/releases/tag/") else { return nil }
        return url
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var message = "Check GitHub for a newer release."
    @Published private(set) var isChecking = false
    @Published private(set) var releaseURL: URL?
    @Published private(set) var availableVersion: String?
    @Published private(set) var automatic: Bool
    private let defaults: UserDefaults
    private let currentVersion: String
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var lastManualCheck = Date.distantPast
    private static let interval: TimeInterval = 86_400

    init(currentVersion: String, defaults: UserDefaults = .standard) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        automatic = defaults.bool(forKey: "automaticUpdateChecks")
    }

    func start() { schedule() }
    func stop() { timer?.invalidate(); timer = nil; task?.cancel(); task = nil }
    func setAutomatic(_ enabled: Bool) {
        automatic = enabled
        defaults.set(enabled, forKey: "automaticUpdateChecks")
        schedule()
    }
    private func schedule() {
        timer?.invalidate(); timer = nil
        guard automatic else { return }
        let last = defaults.object(forKey: "lastUpdateAttempt") as? Date ?? .distantPast
        let delay = max(1, min(Self.interval, Self.interval - Date().timeIntervalSince(last)))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.check(manual: false) }
        }
        timer.tolerance = min(60, delay / 10)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check(manual: Bool = true) {
        guard !isChecking else { return }
        guard manual || automatic else { return }
        if manual {
            guard Date().timeIntervalSince(lastManualCheck) >= 30 else { return }
            lastManualCheck = Date()
        }
        defaults.set(Date(), forKey: "lastUpdateAttempt")
        schedule()
        isChecking = true
        message = "Checking…"
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.isChecking = false; self.task = nil }
            let config = URLSessionConfiguration.ephemeral
            config.httpShouldSetCookies = false
            config.urlCache = nil
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 20
            let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            do {
                let endpoint = URL(string: "https://api.github.com/repos/orstsm/mechakeys/releases/latest")!
                var request = URLRequest(url: endpoint)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
                request.setValue("MechaKeys-UpdateChecker", forHTTPHeaderField: "User-Agent")
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if http.statusCode == 404 {
                    self.message = "No public release found (or repository is private)."
                    self.availableVersion = nil; self.releaseURL = nil
                    return
                }
                guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
                var data = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard data.count < 1_048_576 else { throw URLError(.dataLengthExceedsMaximum) }
                    data.append(byte)
                }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard !release.draft, !release.prerelease,
                      let remote = ReleaseVersion(release.tag_name),
                      let local = ReleaseVersion(self.currentVersion),
                      let url = release.safeURL else { throw URLError(.cannotParseResponse) }
                if remote > local {
                    self.availableVersion = release.tag_name
                    self.releaseURL = url
                    self.message = "\(release.tag_name) is available."
                } else {
                    self.availableVersion = nil; self.releaseURL = nil
                    self.message = "You’re up to date (\(self.currentVersion))."
                }
            } catch {
                if !Task.isCancelled { self.message = "Couldn’t check. Try again later." }
            }
        }
    }
}
