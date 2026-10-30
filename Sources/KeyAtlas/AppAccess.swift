import Foundation

enum ReadScope: String, Codable, CaseIterable, Identifiable {
    case preferences, menus, settings
    var id: String {rawValue}
    var title: String {
        switch self {case .preferences: "快捷键配置"; case .menus: "应用菜单"; case .settings: "已打开的快捷键设置页"}
    }
}

struct AppGrant: Codable, Equatable {
    let bundleID: String
    let name: String
    let scopes: Set<ReadScope>
    let grantedAt: Date
}

// App-level consent, not an OS security boundary. Every reader takes a snapshot
// and checks its revision before each external read and again before publishing.
final class AppAccess: @unchecked Sendable {
    private let lock = NSLock()
    private var grants: [String: AppGrant] = [:]
    private var revision = UUID()
    let url: URL
    private(set) var loadError: String?
    private struct File: Codable {let version: Int; let grants: [AppGrant]}

    init(storage: URL) {
        url = storage.appendingPathComponent("app-consent.json")
        if FileManager.default.fileExists(atPath:url.path) {
            do {
                let file = try JSONDecoder().decode(File.self,from:Data(contentsOf:url))
                guard file.version == 1 else {throw CocoaError(.coderReadCorrupt)}
                for grant in file.grants {grants[grant.bundleID] = grant}
            } catch {loadError = "应用授权记录无法读取，已按全部未授权处理。"}
        }
    }
    var all: [AppGrant] {lock.lock();defer {lock.unlock()};return Array(grants.values)}
    func snapshot() -> AccessSnapshot {
        lock.lock();defer {lock.unlock()}
        return AccessSnapshot(owner:self,revision:revision,grants:grants)
    }
    fileprivate func isCurrent(_ id: UUID) -> Bool {lock.lock();defer {lock.unlock()};return revision == id}
    func set(_ grant: AppGrant?, for id: String) throws {
        lock.lock();defer {lock.unlock()}
        var updated = grants
        updated[id] = grant
        // Revocation (including removal of just one method) takes effect in
        // memory even if disk persistence fails. New methods require a save.
        if grant == nil {grants = updated;revision = UUID()}
        else if let previous = grants[id], let grant, !previous.scopes.isSubset(of:grant.scopes) {
            let retained = previous.scopes.intersection(grant.scopes)
            grants[id] = retained.isEmpty ? nil : AppGrant(bundleID:id,name:previous.name,scopes:retained,grantedAt:previous.grantedAt)
            revision = UUID()
        }
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(File(version:1,grants:updated.values.sorted {$0.bundleID < $1.bundleID})).write(to:url,options:.atomic)
        grants = updated;revision = UUID();loadError = nil
    }
}

struct AccessSnapshot: @unchecked Sendable {
    fileprivate let owner: AppAccess
    fileprivate let revision: UUID
    let grants: [String: AppGrant]
    var isCurrent: Bool {owner.isCurrent(revision)}
    func allows(_ id: String,_ scope: ReadScope) -> Bool {isCurrent && grants[id]?.scopes.contains(scope) == true}
    func permits(_ item: Shortcut) -> Bool {
        if item.origin == .manual || ["system","services","all-app-menus"].contains(item.bundleID) {return true}
        return allows(item.bundleID,item.origin == .menu ? .menus : item.origin == .settings ? .settings : .preferences)
    }
}
