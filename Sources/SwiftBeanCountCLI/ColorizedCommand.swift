import ArgumentParser
import Foundation
import Rainbow

struct ColorizedCommandOptions: ParsableCommand {
    // swiftlint:disable:next line_length
    @ArgumentParser.Flag(help: "Disable colors in output.\nNote: When output is not connected to a terminal, colorization is disabled automatically.\nYou can also use the NO_COLOR environment variable.")
    var noColor = false
}

protocol ColorizedCommand: ParsableCommand {
    var colorOptions: ColorizedCommandOptions { get }
}

extension ColorizedCommand {

    func adjustColorization() {
        if colorOptions.noColor || ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
            Rainbow.enabled = false
        }
    }

}
