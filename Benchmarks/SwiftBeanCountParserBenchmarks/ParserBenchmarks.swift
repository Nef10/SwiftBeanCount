//
//  ParserBenchmarks.swift
//  SwiftBeanCountParserBenchmarks
//
//  Created by GitHub Copilot
//

import Benchmark
import Foundation
import SwiftBeanCountParser

let benchmarks = {
    Benchmark("Parse Big File",
              configuration: Benchmark.Configuration(
                metrics: [.wallClock, .throughput],
                warmupIterations: 1,
                scalingFactor: .kilo,
                maxDuration: .seconds(10),
                maxIterations: 10
              )) { benchmark in
        guard let fileURL = Bundle.module.url(forResource: "Big", withExtension: "beancount", subdirectory: "Resources") else {
            fatalError("Could not find Big.beancount file")
        }
        
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            _ = try Parser.parse(contentOf: fileURL)
        }
    }
    
    Benchmark("Parse Big File (String)",
              configuration: Benchmark.Configuration(
                metrics: [.wallClock, .throughput],
                warmupIterations: 1,
                scalingFactor: .kilo,
                maxDuration: .seconds(10),
                maxIterations: 10
              )) { benchmark in
        guard let fileURL = Bundle.module.url(forResource: "Big", withExtension: "beancount", subdirectory: "Resources") else {
            fatalError("Could not find Big.beancount file")
        }
        
        let text: String
        if #available(macOS 15, iOS 18, *) {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } else {
            text = try String(contentsOf: fileURL)
        }
        
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            _ = Parser.parse(string: text)
        }
    }
}
