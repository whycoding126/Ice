//
//  OutputTransformer.swift
//  CLI
//
//  Created by Jake Heiser on 8/30/17.
//

import Foundation

public class OutputTransformer {
    
    let out: Hose
    let error: Hose
    
    private var prefix: String? = nil
    private var suffix: String? = nil
    
    private var outGenerators: [ResponseGenerator] = []
    private var errorGenerators: [ResponseGenerator] = []
    
    private var currentResponse: Response?
    
    init() {
        self.out = Hose()
        self.error = Hose()
        
        self.out.onLine = { [weak self] in self?.readLine(stream: .out, line: $0) }
        self.error.onLine = { [weak self] in self?.readLine(stream: .err, line: $0) }
    }
    
    private func readLine(stream: StdStream, line: String) {
        if let currentResponse = currentResponse {
            if currentResponse.contine(on: line) {
                return
            }
            currentResponse.stop()
        }
        let generators = stream == .out ? outGenerators : errorGenerators
        for responseGenerator in generators {
            if responseGenerator.matches(line) {
                currentResponse = responseGenerator.generateResponse(to: line)
                return
            }
        }
        stream.output(line)
    }
    
    public func first(_ str: String) {
        self.prefix = str
    }
    
    public func respond(on stream: StdStream, with generator: ResponseGenerator) {
        if stream == .out {
            outGenerators.append(generator)
        } else {
            errorGenerators.append(generator)
        }
    }
    
    public func replace(_ matcher: StaticString, on stream: StdStream = .out, _ translation: @escaping CaptureTranslation) {
        let generator = ResponseGenerator(matcher: matcher, generate: {
            return ReplaceResponse(stream: stream, translation: translation)
        })
        respond(on: stream, with: generator)
    }
    
    public func spin(_ matcher: StaticString, _ during: @escaping CaptureTranslation, _ done: @escaping SpinnerResponse.Completion) {
        let generator = ResponseGenerator(matcher: matcher, generate: {
            return SpinnerResponse(during: during, after: done)
        })
        respond(on: .out, with: generator)
    }
    
    public func ignore(_ matcher: StaticString, on stream: StdStream = .out) {
        let generator = ResponseGenerator(matcher: matcher) {
            return IgnoreResponse()
        }
        respond(on: stream, with: generator)
    }
    
    public func last(_ str: String) {
        self.suffix = str
    }
    
    public func attach(_ process: Process) {
        out.attach(.out, process)
        error.attach(.err, process)
    }
    
    func printPrefix() {
        if let prefix = prefix {
            print(prefix, terminator: "")
        }
    }
    
    func printSuffix() {
        currentResponse?.stop()
        currentResponse = nil
        
        if let suffix = suffix {
            print(suffix, terminator: "")
        }
    }
    
}
