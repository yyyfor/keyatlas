import AppKit
let destination = CommandLine.arguments[1]
let image = NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSColor(calibratedRed:0.38,green:0.33,blue:0.78,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:70,y:70,width:884,height:884),xRadius:200,yRadius:200).fill()
let attrs: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:590,weight:.light),.foregroundColor:NSColor.white]
let text = NSAttributedString(string:"⌘",attributes:attrs)
let size = text.size()
text.draw(at:NSPoint(x:(1024-size.width)/2,y:(1024-size.height)/2+3))
image.unlockFocus()
func integer(_ value: Int) -> Data {
    var big = UInt32(value).bigEndian
    return withUnsafeBytes(of:&big) {Data($0)}
}
var body = Data()
for (tag,pixels) in [("icp4",16),("icp5",32),("icp6",64),("ic07",128),("ic08",256),("ic09",512),("ic10",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    image.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels))
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using:.png,properties:[:])!
    body.append(tag.data(using:.ascii)!);body.append(integer(png.count+8));body.append(png)
}
var output = "icns".data(using:.ascii)!;output.append(integer(body.count+8));output.append(body)
try output.write(to:URL(fileURLWithPath:destination))
