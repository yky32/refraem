import Foundation

enum DefaultHotkeys {
    static let bindings: [UtilityAction: GlobalHotkey] = [
        .window(.leftHalf): GlobalHotkey(keyCode: 123, modifiers: [.control, .option]),
        .window(.rightHalf): GlobalHotkey(keyCode: 124, modifiers: [.control, .option]),
        .window(.topHalf): GlobalHotkey(keyCode: 126, modifiers: [.control, .option]),
        .window(.bottomHalf): GlobalHotkey(keyCode: 125, modifiers: [.control, .option]),
        .window(.topLeft): GlobalHotkey(keyCode: 32, modifiers: [.control, .option], character: "u"),
        .window(.topRight): GlobalHotkey(keyCode: 34, modifiers: [.control, .option], character: "i"),
        .window(.bottomLeft): GlobalHotkey(keyCode: 38, modifiers: [.control, .option], character: "j"),
        .window(.bottomRight): GlobalHotkey(keyCode: 40, modifiers: [.control, .option], character: "k"),
        .window(.firstThird): GlobalHotkey(keyCode: 2, modifiers: [.control, .option], character: "d"),
        .window(.centerThird): GlobalHotkey(keyCode: 3, modifiers: [.control, .option], character: "f"),
        .window(.lastThird): GlobalHotkey(keyCode: 5, modifiers: [.control, .option], character: "g"),
        .window(.firstTwoThirds): GlobalHotkey(keyCode: 14, modifiers: [.control, .option], character: "e"),
        .window(.lastTwoThirds): GlobalHotkey(keyCode: 17, modifiers: [.control, .option], character: "t"),
        .capture(.screen): GlobalHotkey(keyCode: 18, modifiers: [.command, .shift], character: "1"),
        .capture(.area): GlobalHotkey(keyCode: 19, modifiers: [.command, .shift], character: "2"),
        .capture(.recognizeTextOrQR): GlobalHotkey(keyCode: 31, modifiers: [.control, .option, .command], character: "o"),
        .capture(.scrolling): GlobalHotkey(keyCode: 20, modifiers: [.command, .shift], character: "3"),
        .record(.screen): GlobalHotkey(keyCode: 15, modifiers: [.control, .option, .command], character: "r"),
        .record(.area): GlobalHotkey(keyCode: 21, modifiers: [.control, .option, .command], character: "4"),
    ]
}
