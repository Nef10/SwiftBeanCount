//
//  ParserBenchmarks.swift
//  SwiftBeanCountParserBenchmarks
//
//  Created by GitHub Copilot
//

import Benchmark
import Foundation
import SwiftBeanCountParser

private func loadBigFile() -> URL {
    guard let fileURL = Bundle.module.url(
        forResource: "Big",
        withExtension: "beancount",
        subdirectory: "Resources"
    ) else {
        fatalError("Could not find Big.beancount file")
    }
    return fileURL
}

let benchmarks = {
    let config = Benchmark.Configuration(
        metrics: [.wallClock, .throughput],
        warmupIterations: 1,
        scalingFactor: .kilo,
        maxDuration: .seconds(10),
        maxIterations: 10
    )

    Benchmark("Parse Big File", configuration: config) { benchmark in
        let fileURL = loadBigFile()
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            _ = try Parser.parse(contentOf: fileURL)
        }
    }

    Benchmark("Parse Big File (String)", configuration: config) { benchmark in
        let fileURL = loadBigFile()
        // Load file content before measurement to benchmark only parsing, not I/O
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            _ = Parser.parse(string: text)
        }
    }
}
