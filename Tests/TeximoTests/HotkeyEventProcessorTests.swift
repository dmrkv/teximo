import CoreGraphics
import XCTest
@testable import teximo

final class HotkeyEventProcessorTests: XCTestCase {
    private let commandSpace: [HotkeyAction: HotkeyConfig] = [
        .switchLayout: HotkeyConfig(modifiers: [.command], keyCode: 49)
    ]

    func testCommandAloneDoesNotTriggerCommandSpace() {
        var processor = HotkeyEventProcessor()

        let result = processor.process(
            event(.flagsChanged, modifiers: [.command], keyCode: 55),
            configurations: commandSpace
        )

        XCTAssertEqual(result.disposition, .passThrough)
        XCTAssertTrue(result.invocations.isEmpty)
    }

    func testCommandSpaceTriggersExactlyOnce() {
        var processor = HotkeyEventProcessor()

        let keyDown = processor.process(
            event(.keyDown, modifiers: [.command], keyCode: 49),
            configurations: commandSpace
        )
        let repeatedKeyDown = processor.process(
            event(.keyDown, modifiers: [.command], keyCode: 49, isRepeat: true),
            configurations: commandSpace
        )
        let keyUp = processor.process(
            event(.keyUp, modifiers: [.command], keyCode: 49),
            configurations: commandSpace
        )

        XCTAssertEqual(
            keyDown.invocations,
            [HotkeyInvocation(action: .switchLayout, phase: .pressed, source: .keyed)]
        )
        XCTAssertTrue(repeatedKeyDown.invocations.isEmpty)
        XCTAssertTrue(keyUp.invocations.isEmpty)
    }

    func testReleasingCommandDoesNotTrigger() {
        var processor = HotkeyEventProcessor()

        let commandPressed = processor.process(
            event(.flagsChanged, modifiers: [.command], keyCode: 55),
            configurations: commandSpace
        )
        let commandReleased = processor.process(
            event(.flagsChanged, modifiers: [], keyCode: 55),
            configurations: commandSpace
        )

        XCTAssertEqual(commandPressed.disposition, .passThrough)
        XCTAssertTrue(commandPressed.invocations.isEmpty)
        XCTAssertEqual(commandReleased.disposition, .passThrough)
        XCTAssertTrue(commandReleased.invocations.isEmpty)
    }

    func testUnrelatedKeyWithCommandDoesNotTrigger() {
        var processor = HotkeyEventProcessor()

        let result = processor.process(
            event(.keyDown, modifiers: [.command], keyCode: 0),
            configurations: commandSpace
        )

        XCTAssertEqual(result.disposition, .passThrough)
        XCTAssertTrue(result.invocations.isEmpty)
    }

    func testSameKeyWithExtraModifierDoesNotTrigger() {
        var processor = HotkeyEventProcessor()

        let result = processor.process(
            event(.keyDown, modifiers: [.command, .shift], keyCode: 49),
            configurations: commandSpace
        )

        XCTAssertEqual(result.disposition, .passThrough)
        XCTAssertTrue(result.invocations.isEmpty)
    }

    func testMatchedShortcutEventsAreConsumed() {
        var processor = HotkeyEventProcessor()

        let keyDown = processor.process(
            event(.keyDown, modifiers: [.command], keyCode: 49),
            configurations: commandSpace
        )
        let repeatedKeyDown = processor.process(
            event(.keyDown, modifiers: [.command], keyCode: 49, isRepeat: true),
            configurations: commandSpace
        )
        let keyUp = processor.process(
            event(.keyUp, modifiers: [], keyCode: 49),
            configurations: commandSpace
        )

        XCTAssertEqual(keyDown.disposition, .consume)
        XCTAssertEqual(repeatedKeyDown.disposition, .consume)
        XCTAssertEqual(keyUp.disposition, .consume)
    }

    func testConsumeDispositionReturnsNilFromEventTapAdapter() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)
        )

        XCTAssertNil(HotkeyManager.tapReturnValue(for: .consume, event: event))
        XCTAssertNotNil(HotkeyManager.tapReturnValue(for: .passThrough, event: event))
    }

    func testModifierOnlyShortcutStillTriggersOnPressAndRelease() {
        var processor = HotkeyEventProcessor()
        let configurations: [HotkeyAction: HotkeyConfig] = [
            .switchLayout: HotkeyConfig(modifiers: [.command, .shift])
        ]

        let pressed = processor.process(
            event(.flagsChanged, modifiers: [.command, .shift], keyCode: 56),
            configurations: configurations
        )
        let unchanged = processor.process(
            event(.flagsChanged, modifiers: [.command, .shift], keyCode: 55),
            configurations: configurations
        )
        let released = processor.process(
            event(.flagsChanged, modifiers: [.command], keyCode: 56),
            configurations: configurations
        )

        XCTAssertEqual(pressed.disposition, .passThrough)
        XCTAssertEqual(
            pressed.invocations,
            [HotkeyInvocation(action: .switchLayout, phase: .pressed, source: .modifierOnly)]
        )
        XCTAssertTrue(unchanged.invocations.isEmpty)
        XCTAssertEqual(
            released.invocations,
            [HotkeyInvocation(action: .switchLayout, phase: .released, source: .modifierOnly)]
        )
    }

    func testClearedModifierOnlyShortcutDoesNotTriggerOnRelease() {
        var processor = HotkeyEventProcessor()
        let configurations: [HotkeyAction: HotkeyConfig] = [
            .switchLayout: HotkeyConfig(modifiers: [.command, .shift])
        ]

        _ = processor.process(
            event(.flagsChanged, modifiers: [.command, .shift], keyCode: 56),
            configurations: configurations
        )
        let releasedAfterClearing = processor.process(
            event(.flagsChanged, modifiers: [.command], keyCode: 56),
            configurations: [:]
        )

        XCTAssertTrue(releasedAfterClearing.invocations.isEmpty)
    }

    private func event(
        _ kind: HotkeyInputEventKind,
        modifiers: Set<ModifierKey>,
        keyCode: UInt16,
        isRepeat: Bool = false
    ) -> HotkeyInputEvent {
        HotkeyInputEvent(
            kind: kind,
            modifiers: modifiers,
            keyCode: keyCode,
            isRepeat: isRepeat
        )
    }
}
