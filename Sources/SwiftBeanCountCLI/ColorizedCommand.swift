import ArgumentParser
import Foundation
import Rainbow

protocol ColorizedCommand: ParsableCommand {
    var noColor: Bool { get }
}

extension ColorizedCommand {

    static func noColorHelp() -> ArgumentHelp {
        """
        Disable colors in output.
        Note: When output is not connected to a terminal, colorization is disabled automatically.
        You can also use the NO_COLOR environment variable.
        """
    }

    func adjustColorization() {
        if noColor || ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
            Rainbow.enabled = false
        }
    }

}
