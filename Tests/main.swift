import Foundation
import AppKit

var passed = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {fputs("FAIL: \(message)\n",stderr);exit(1)}
    passed += 1
}
func item(_ id: String,_ chord: KeyChord,scope: String = "app",app: String = "test",enabled: Bool = true) -> Shortcut {
    Shortcut(id:id,title:"测试截屏",source:"Test App",bundleID:app,category:"测试",chord:chord,enabled:enabled,scope:scope,origin:.preference,detail:"",location:"")
}

check(KeyChord.carbon(code:18,flags:2560).display == "⌥ ⇧ 1","Carbon and Cocoa modifier masks must not be mixed")
check(KeyChord.cocoa(code:49,flags:262144).display == "⌃ 空格","Control-space decoding")
check(KeyChord.cocoa(code:63,flags:0).display == "fn","Fn virtual key decoding")
check(KeyChord.cocoa(code:61,flags:0).display == "右 ⌥","Sided Option must stay distinct")
check(KeyChord.cocoa(code:123,flags:8650752).display == "fn ⌃ ←","Preserve raw Fn flags without hiding them")
check(KeyChord.menuEquivalent("@$") == nil,"Modifier-only invalid menu binding")
check(KeyChord.menuEquivalent("@~k")?.display == "⌥ ⌘ K","App menu modifier order")
check(KeyChord.menuEquivalent("@K")?.display == "⇧ ⌘ K","Uppercase menu key implies Shift")
check(KeyChord.menuEquivalent("@\u{f704}")?.display == "⌘ F1","Function character decoding")
check(KeyChord.menuEquivalent("^ ")?.display == "⌃ 空格","Whitespace key is a real key")
check(KeyChord.menuEquivalent("") == nil,"Empty key equivalent")

let commandK = KeyChord(key:"K",modifiers:["⌘"])
let a = item("a",commandK,app:"a")
let b = item("b",commandK,app:"b")
let global = item("g",commandK,scope:"global")
check(ShortcutLogic.duplicates([a,b]).isEmpty,"Different application scopes are not conflicts")
check(ShortcutLogic.duplicates([a,b,global]) == Set(["a","b","g"]),"Global binding overlaps app bindings")
check(ShortcutLogic.duplicates([a,item("b",commandK,app:"a")]).count == 2,"Same app duplicates")
check(ShortcutLogic.duplicates([a,item("b",commandK,scope:"global",enabled:false)]).isEmpty,"Disabled entries do not conflict")
check(ShortcutLogic.duplicates([a,item("b",commandK,scope:"unknown")]).isEmpty,"Unknown scope cannot prove duplicates")
check(ShortcutLogic.duplicates([a,item("b",KeyChord(key:"K",modifiers:["⌘"],trigger:"长按"),scope:"global")]).isEmpty,"Hold and press are different triggers")
check(KeyChord(key:"fn",modifiers:[],trigger:"长按").signature == KeyChord(key:"",modifiers:["fn"],trigger:"长按").signature,"Modifier-only manual records normalize")
check(KeyChord(key:"右 ⌥",modifiers:[]).signature != KeyChord(key:"⌥",modifiers:[]).signature,"Sided modifiers are not collapsed")

let shot = item("shot",KeyChord(key:"3",modifiers:["⇧","⌘"]))
for query in ["cmd+shift+3","⌘⇧3","command shift","截图","test app"] {
    check(ShortcutLogic.filtered([shot],query:query,source:"all",filter:"全部",modifier:"",favorites:[]).count == 1,"Search handles \(query)")
}
check(ShortcutLogic.filtered([shot],query:"unmatched",source:"all",filter:"全部",modifier:"",favorites:[]).isEmpty,"Nonmatching search")
check(ShortcutLogic.filtered([a,b],query:"",source:"favorites",filter:"全部",modifier:"",favorites:["b"]).map(\.id) == ["b"],"Favorite filtering")
check(ShortcutLogic.filtered([shot],query:"",source:"all",filter:"全部",modifier:"fn",favorites:[]).isEmpty,"Modifier filtering")

let valid = AppReader.parsePreference("KeyboardShortcuts_openSettings",value:"{\"carbonKeyCode\":43,\"carbonModifiers\":256}",domain:"a",name:"A")
check(valid?.chord?.display == "⌘ ,","Actual KeyboardShortcuts JSON format")
check(valid?.scope == "unknown","Do not assume app config is global")
check(AppReader.parsePreference("KeyboardShortcuts_toggle",value:false,domain:"a",name:"A") == nil,"Disabled/unset preference is not a binding")
check(AppReader.parsePreference("KeyboardShortcuts_bad",value:"{broken",domain:"a",name:"A") == nil,"Malformed JSON does not crash")
check(AppReader.parsePreference("KeyboardShortcuts_bad",value:["carbonKeyCode":-1,"carbonModifiers":256],domain:"a",name:"A") == nil,"Unassigned negative code skipped")
check(AppReader.parsePreference("random",value:["keyCode":4,"modifierFlags":1048576],domain:"a",name:"A") == nil,"Unrelated dictionaries are not shortcuts")
check(AppReader.parsePreference("leftHalf",value:["keyCode":123,"modifierFlags":786432],domain:"com.knollsoft.Rectangle",name:"Rectangle")?.scope == "global","Rectangle adapter knows its scope")
let roundTrip = try JSONDecoder().decode(Shortcut.self,from:JSONEncoder().encode(shot))
check(roundTrip == shot,"Export round trip preserves data")
check(Set(SystemReader.actions.map(\.id)).count == SystemReader.actions.count,"System catalog contains no duplicate IDs")
check(!AppReader.canReadPreferenceDomain("com.apple.Music"),"Protected Music preferences must never be opened")
check(!AppReader.canReadPreferenceDomain("com.apple.Safari"),"Protected Apple app preference files are excluded")
check(AppReader.canReadPreferenceDomain("com.knollsoft.Rectangle"),"Supported third-party preference domain remains available")
let consentDir = FileManager.default.temporaryDirectory.appendingPathComponent("keyatlas-access-tests-\(UUID().uuidString)")
defer {try? FileManager.default.removeItem(at:consentDir)}
let access = AppAccess(storage:consentDir)
let none = access.snapshot()
check(!none.allows("test.app",.preferences),"New installs authorize no app")
var reads = 0
let fakeURL = consentDir.appendingPathComponent("never-read.plist")
_ = AppReader.authorizedPreferences(fakeURL,domain:"test.app",access:none,read:{_ in reads += 1;return [:]})
check(reads == 0,"Unapproved preferences never invoke the file reader")
try access.set(AppGrant(bundleID:"test.app",name:"Test",scopes:[.preferences],grantedAt:Date()),for:"test.app")
let allowed = access.snapshot()
check(allowed.allows("test.app",.preferences) && !allowed.allows("test.app",.menus) && !allowed.allows("other.app",.preferences),"Consent is per app and per method")
check(!none.isCurrent,"A policy change invalidates in-flight snapshots")
check(AppAccess(storage:consentDir).snapshot().allows("test.app",.preferences),"Consent survives relaunch")
_ = AppReader.authorizedPreferences(fakeURL,domain:"test.app",access:allowed,read:{_ in reads += 1;return ["safe":"value"]})
check(reads == 1,"Approved preference reader is called")
let raced = AppReader.authorizedPreferences(fakeURL,domain:"test.app",access:allowed,read:{_ in try! access.set(nil,for:"test.app");return ["late":"data"]})
check(raced.isEmpty && !allowed.allows("test.app",.preferences),"Revocation discards a file result already in flight")
check(AppAccess(storage:consentDir).all.isEmpty,"Revocation survives relaunch")
try Data("{broken".utf8).write(to:access.url)
let corruptedAccess = AppAccess(storage:consentDir)
check(corruptedAccess.all.isEmpty && corruptedAccess.loadError != nil,"Corrupt consent fails closed")
let voice = SettingsReader.parse([SettingsText(role:"AXStaticText",text:"语音输入模式 长按模式 按住说话，松手结束 右⌥"),SettingsText(role:"AXStaticText",text:"免按模式 按一次即可开始说话，再按任意键可结束 点击设置 麦克风选择")],bundleID:SettingsReader.doubao)
check(voice.count == 1 && voice[0].chord?.trigger == "长按" && voice[0].chord?.display == "右 ⌥","Observed Doubao settings: right Option hold; unset hands-free omitted")
check(voice[0].scope == "unknown","Doubao global-voice toggle is not inferred")
let ray = SettingsReader.parse([SettingsText(role:"AXStaticText",text:"Startup Raycast Hotkey ⌥ Space")],bundleID:SettingsReader.raycast)
check(ray.count == 1 && ray[0].chord?.display == "⌥ 空格","Observed Raycast General launcher field")
let unsetRows = SettingsReader.parse([SettingsText(role:"AXRow",text:"Record Hotkey\nSearch Files\nCommand"),SettingsText(role:"AXRow",text:"Raycast\nExtension\n--\n--")],bundleID:SettingsReader.raycast)
check(unsetRows.isEmpty,"Unassigned and group rows do not become shortcuts")
check(SettingsReader.chord("点击设置") == nil && SettingsReader.chord("麦克风选择") == nil && SettingsReader.chord("Record Hotkey") == nil,"Ordinary labels are rejected as keys")
check(SettingsReader.chord("fn",trigger:"长按")?.display == "fn","Bare Fn preserves hold trigger")
check(SettingsReader.parse([SettingsText(role:"AXStaticText",text:"Startup Raycast Hotkey ⌥ Space")],bundleID:"unknown").isEmpty,"Settings parser is restricted to supported apps")
check(SettingsReader.scan(bundleID:SettingsReader.doubao,access:none).shortcuts.isEmpty,"Settings scan exits before AX access without consent")
check(ShortcutLogic.filtered(voice,query:"",source:"all",filter:"已启用",modifier:"",favorites:[]).isEmpty,"Settings-page bindings are not falsely marked enabled")
check(ShortcutLogic.filtered(voice,query:"",source:"all",filter:"待确认",modifier:"",favorites:[]).count == 1,"Unverified activation has its own filter")
let unknownExport = try JSONSerialization.jsonObject(with:JSONEncoder().encode(voice[0])) as! [String:Any]
check(voice[0].enabled == nil && unknownExport["enabled"] == nil,"Export does not invent an enabled state for settings observations")
print("PASS: \(passed) focused checks")
