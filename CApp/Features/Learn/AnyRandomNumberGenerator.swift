//
//  AnyRandomNumberGenerator.swift
//  CApp
//

import Foundation

/// Wraps any random number generator in a concrete type.
///
/// `BatchSelector` takes `inout some RandomNumberGenerator`, which an
/// existential cannot be passed to. Without this wrapper `LearnSessionModel`
/// would have to be generic over the generator — which would spread through
/// every view holding it — or create its own randomness, which is exactly
/// what phase 5 avoided so the selection stays reproducible.
///
/// Production uses the system generator, tests inject a seeded one.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var wrapped: any RandomNumberGenerator

    init(_ wrapped: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.wrapped = wrapped
    }

    mutating func next() -> UInt64 {
        wrapped.next()
    }
}
