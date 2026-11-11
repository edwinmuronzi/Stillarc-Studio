import Foundation

enum SliderDefaults {
    static func reset(_ layer:inout LocalMask,key:WritableKeyPath<LocalMask,Double>) {
        layer[keyPath:key] = LocalMask(kind:layer.kind)[keyPath:key]
    }
    static func resetSelection(_ layer:inout LocalMask,key:WritableKeyPath<MaskSelection,Double>) {
        var value = layer.selection ?? MaskSelection();value[keyPath:key] = MaskSelection()[keyPath:key]
        if key == \MaskSelection.lower { value.upper = max(value.upper,value.lower) }
        if key == \MaskSelection.upper { value.lower = min(value.lower,value.upper) }
        layer.selection = value
    }
}
