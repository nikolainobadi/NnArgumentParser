//
//  NnOutputInterruptTests.swift
//  NnArgumentParser
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
@testable import NnArgumentParser
import NnArgumentParserTesting

struct NnOutputInterruptTests {
    @Test
    func `Once interrupted, output never reaches the run's buffer`() {
        let buffer = NnOutputBuffer()

        withIsolatedState {
            installBuffer(buffer)
            installCoordinator(isInterrupting: true)

            NnOutput.write("dropped")
        }

        #expect(buffer.contents.isEmpty)
    }

    @Test
    func `Once interrupted, output never reaches the registered writer`() {
        let writer = InterruptRecordingWriter()

        withIsolatedState {
            NnOutput.register(writer: writer)
            installCoordinator(isInterrupting: true)

            NnOutput.write("dropped")
        }

        #expect(writer.lines.isEmpty)
    }

    @Test
    func `A coordinator that reports no interrupt leaves output alone`() {
        let buffer = NnOutputBuffer()

        withIsolatedState {
            installBuffer(buffer)
            installCoordinator(isInterrupting: false)

            NnOutput.write("kept")
        }

        #expect(buffer.contents == "kept\n")
    }

    @Test
    func `One run's interrupt never mutes another run`() {
        let buffer = NnOutputBuffer()

        withIsolatedState {
            installCoordinator(isInterrupting: true)
        }

        withIsolatedState {
            installBuffer(buffer)
            NnOutput.write("kept")
        }

        #expect(buffer.contents == "kept\n")
    }
}


// MARK: - SUT
private extension NnOutputInterruptTests {
    var currentBox: NnStateBox {
        return NnStateScope.requiredBox(for: "NnOutputInterruptTests")
    }

    func installBuffer(_ buffer: NnOutputBuffer) {
        currentBox[NnOutputBuffer.storageKey] = buffer
    }

    /// Puts a coordinator into the current box the way `install()` does, without touching signals.
    func installCoordinator(isInterrupting: Bool) {
        let box = currentBox

        box[NnInterruptCoordinator.storageKey] = NnInterruptCoordinator(box: box, isInterrupting: { isInterrupting }, terminate: { _ in }, writeError: { _ in })
    }
}


// MARK: - Test Doubles
private final class InterruptRecordingWriter: NnOutputWriter, @unchecked Sendable {
    private let lock = NSLock()
    private var written: [String] = []

    var lines: [String] {
        return lock.withLock { written }
    }

    func write(_ text: String) {
        lock.withLock { written.append(text) }
    }
}
