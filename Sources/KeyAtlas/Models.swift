import Foundation
import AppKit

enum Origin: String, Codable, CaseIterable {
    case system = "系统读取", preference = "应用配置", menu = "应用菜单", settings = "设置页读取", manual = "手动记录"
}

struct KeyChord: Codable, Hashable {
    var key: String
    var modifiers: [String]
    var trigger: String = "按下"
    var keyCode: Int? = nil

    var tokens: [String] { modifiers + (key.isEmpty ? [] : [key]) }
    var display: String { tokens.joined(separator: " ") }
    var signature: String {
        // Keep sided modifiers and hold/double-tap distinct. Do not claim they collide.
        var canonicalModifiers = modifiers
        let canonicalKey: String
        if ["fn","⌃","⌥","⇧","⌘"].contains(key) {
            canonicalModifiers.append(key); canonicalKey = ""
        } else { canonicalKey = key.uppercased() }
        return "\(Set(canonicalModifiers).sorted().joined(separator: "+"))|\(canonicalKey)|\(trigger)"
    }
    static func cocoa(code: Int, flags: UInt64, character: String? = nil) -> KeyChord {
        let mods: [(UInt64, String)] = [(1 << 23,"fn"),(1 << 18,"⌃"),(1 << 19,"⌥"),(1 << 17,"⇧"),(1 << 20,"⌘")]
        return KeyChord(key: KeyNames.name(code, character: character), modifiers: mods.filter { flags & $0.0 != 0 }.map(\.1), keyCode: code)
    }
    static func carbon(code: Int, flags: UInt64) -> KeyChord {
        var cocoa: UInt64 = 0
        for (old, new): (UInt64, UInt64) in [(256,1 << 20),(512,1 << 17),(2048,1 << 19),(4096,1 << 18),(131072,1 << 23)] {
            if flags & old != 0 { cocoa |= new }
        }
        return .cocoa(code: code, flags: cocoa)
    }
    static func menuEquivalent(_ value: String) -> KeyChord? {
        guard !value.isEmpty else { return nil }
        var rest = value[...]; var mods: [String] = []
        let symbols: [Character: String] = ["@":"⌘","~":"⌥","^":"⌃","$":"⇧"]
        while let c = rest.first, let m = symbols[c] { mods.append(m); rest.removeFirst() }
        guard !rest.isEmpty else { return nil }
        let raw = String(rest)
        if raw.count == 1, raw.lowercased() != raw, !mods.contains("⇧") { mods.append("⇧") }
        let normalized = KeyNames.character(raw)
        return KeyChord(key: normalized, modifiers: ["fn","⌃","⌥","⇧","⌘"].filter { mods.contains($0) })
    }
}

enum KeyNames {
    static let names: [Int: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"空格",50:"`",51:"⌫",53:"Esc",54:"右 ⌘",55:"⌘",56:"⇧",57:"⇪",58:"⌥",59:"⌃",60:"右 ⇧",61:"右 ⌥",62:"右 ⌃",63:"fn",64:"F17",65:"小键盘 .",67:"小键盘 ×",69:"小键盘 +",71:"Clear",75:"小键盘 ÷",76:"⌤",78:"小键盘 −",79:"F18",80:"F19",81:"小键盘 =",82:"小键盘 0",83:"小键盘 1",84:"小键盘 2",85:"小键盘 3",86:"小键盘 4",87:"小键盘 5",88:"小键盘 6",89:"小键盘 7",90:"F20",91:"小键盘 8",92:"小键盘 9",96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",105:"F13",106:"F16",107:"F14",109:"F10",111:"F12",113:"F15",114:"Help",115:"Home",116:"Page ↑",117:"⌦",118:"F4",119:"End",120:"F2",121:"Page ↓",122:"F1",123:"←",124:"→",125:"↓",126:"↑"]
    static func name(_ code: Int, character: String? = nil) -> String {
        if let character, !character.isEmpty, character.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value < 0xF700 }), code != 49 { return character.uppercased() }
        return names[code] ?? "键码 \(code)"
    }
    static func character(_ raw: String) -> String {
        let special = [" ":"空格","\r":"↩","\t":"⇥","\u{1b}":"Esc","\u{7f}":"⌫","\u{f700}":"↑","\u{f701}":"↓","\u{f702}":"←","\u{f703}":"→","\u{f728}":"⌦"]
        if let s = special[raw] { return s }
        if let v = raw.unicodeScalars.first?.value, raw.count == 1, (0xF704...0xF717).contains(v) { return "F\(v - 0xF703)" }
        return raw.uppercased()
    }
}

struct Shortcut: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var source: String
    var bundleID: String
    var category: String
    var chord: KeyChord?
    var enabled: Bool?
    var scope: String // "global", "app", or "unknown"
    var origin: Origin
    var detail: String
    var location: String
    var condition: String = ""
    var searchText: String {
        let keys = chord?.display ?? ""
        let aliases = keys.replacingOccurrences(of: "⌘", with: " cmd command ").replacingOccurrences(of: "⌥", with: " option alt ").replacingOccurrences(of: "⌃", with: " ctrl control ").replacingOccurrences(of: "⇧", with: " shift ")
        return [title,source,category,keys,aliases,condition].joined(separator: " ").lowercased()
    }
}

struct Coverage: Identifiable, Codable {
    var id: String
    var title: String
    var count: Int
    var status: String
    var detail: String
}

struct ScanResult {
    var shortcuts: [Shortcut] = []
    var coverage: [Coverage] = []
    var fnAction = "尚未读取"
    var dictation = "未知"
    var functionKeys = "未知"
}

enum ShortcutLogic {
    static func searchWords(_ query: String) -> [String] {
        var text = query.lowercased().replacingOccurrences(of:"+",with:" ")
        for (key,value) in [("⌘"," cmd "),("⌥"," option "),("⌃"," ctrl "),("⇧"," shift "),("space","空格"),("截图","截屏")] {text = text.replacingOccurrences(of:key,with:value)}
        return text.split(whereSeparator:\.isWhitespace).map(String.init)
    }
    static func duplicates(_ items: [Shortcut]) -> Set<String> {
        let groups = Dictionary(grouping: items.filter { $0.enabled == true && $0.chord != nil && $0.scope != "unknown" }, by: { $0.chord!.signature })
        var result = Set<String>()
        for group in groups.values where group.count > 1 {
            for a in group {
                if group.contains(where: { b in
                    a.id != b.id && (a.scope == "global" || b.scope == "global" || a.bundleID == b.bundleID || a.bundleID == "all-app-menus" || b.bundleID == "all-app-menus")
                }) { result.insert(a.id) }
            }
        }
        return result
    }
    static func filtered(_ items: [Shortcut], query: String, source: String, filter: String, modifier: String, favorites: Set<String>) -> [Shortcut] {
        let duplicates = duplicates(items)
        let words = searchWords(query)
        return items.filter { s in
            (source == "all" || source == s.bundleID || (source == "favorites" && favorites.contains(s.id)) || (source == "manual" && s.origin == .manual) || (source == "duplicates" && duplicates.contains(s.id))) &&
            (filter == "全部" || (filter == "已启用" && s.enabled == true) || (filter == "待确认" && s.enabled == nil) || (filter == "已停用" && s.enabled == false)) &&
            (modifier.isEmpty || s.chord?.tokens.contains(modifier) == true) &&
            words.allSatisfy { s.searchText.contains($0) }
        }
    }
}
