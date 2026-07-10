import CoreGraphics
import Foundation
import UIBridgeProtocol

public enum WindowDiscovery {
    public static func listWindows(pid: Int32? = nil) -> [WindowDescriptor] {
        guard let rawList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
            as? [[String: Any]] else {
            return []
        }

        return rawList.compactMap { info in
            guard
                let ownerPID = number(info[kCGWindowOwnerPID as String])?.int32Value,
                pid == nil || ownerPID == pid,
                let windowNumber = number(info[kCGWindowNumber as String])?.uint32Value,
                let boundsValue = info[kCGWindowBounds as String],
                let bounds = CGRect(dictionaryRepresentation: boundsValue as! CFDictionary)
            else {
                return nil
            }

            let alpha = number(info[kCGWindowAlpha as String])?.doubleValue ?? 1
            let layer = number(info[kCGWindowLayer as String])?.intValue ?? 0
            let isOnScreen = (info[kCGWindowIsOnscreen as String] as? Bool) ?? false
            let title = info[kCGWindowName as String] as? String ?? ""

            return WindowDescriptor(
                windowID: windowNumber,
                pid: ownerPID,
                title: title,
                bounds: UIBRect(
                    x: bounds.origin.x,
                    y: bounds.origin.y,
                    width: bounds.size.width,
                    height: bounds.size.height
                ),
                isVisible: isOnScreen && alpha > 0,
                isCapturable: layer == 0 && bounds.width > 1 && bounds.height > 1
            )
        }
        .sorted {
            if $0.isVisible != $1.isVisible { return $0.isVisible }
            let leftArea = $0.bounds.size.width * $0.bounds.size.height
            let rightArea = $1.bounds.size.width * $1.bounds.size.height
            return leftArea > rightArea
        }
    }

    private static func number(_ value: Any?) -> NSNumber? {
        value as? NSNumber
    }
}
