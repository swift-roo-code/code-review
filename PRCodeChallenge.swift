//
//  AntiPatternShowcase.swift
//  PR Code Challenge — What NOT to do
//
//  This file intentionally contains multiple issues for a review exercise.
//  Some are compile-time errors, others are dangerous runtime bugs.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - 1) Misleading Access, Incorrect Overrides, and Open Types

// ❌ `open` in an app target invites extension/subclassing; unnecessary here.
// ❌ Declares designated init as `required` without a superclass requirement.
// ❌ Attempts to override a non-overridable method later.
open class DataFetcher: NSObject {
    public var urlString: String? = "https://example.com/data.json"

    // ❌ Designated initializer that doesn't fully initialize stored properties before use.
    required public override init() {
        super.init()
        if urlString!.isEmpty { // ❌ Force unwrap — unsafe
            fatalError("Not expected") // pointless check
        }
        // ❌ Starts a task that captures self strongly (retain cycle with timer later)
        Task.detached { [self] in
            try? await self.fetchData(completion: { _ in
                // ❌ mixing async/await with callback without good reason
            })
        }
    }

    // ❌ Async API that also takes a completion handler — confusing contract
    // ❌ `completion` incorrectly marked @escaping while also suspending (fine, but poor design)
    open func fetchData(completion: @escaping (Result<Data, Error>) -> Void) async throws {
        let url = URL(string: urlString!)! // ❌ Force unwraps
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: url) { data, _, error in
            // ❌ Ignores error typing, force unwraps data
            if let e = error {
                completion(.failure(e))
                return
            }
            completion(.success(data!)) // ❌ data force unwrap
        }
        task.resume()
        // ❌ Function declares `async throws` but neither awaits nor throws here; misleading signature
    }

    // ❌ Attempts to "override" a final method from NSObject (compile-time error)
    public override func isEqual(_ object: Any?) -> Bool { // NSObject's isEqual is not final, but this example is still poor design to flag
        // ❌ nonsensical equality
        return false
    }
}

// MARK: - 2) Concurrency Hazards & Non-Sendable State

// ❌ Mutable container used concurrently without synchronization.
final class GlobalCache {
    static let shared = GlobalCache()
    var items: [String] = [] // ❌ Non-thread-safe access

    // ❌ Misleading method name; returns reference to internal state
    func unsafeItemsReference() -> [String] {
        return items
    }
}

// ❌ Actor meant to provide safety, but leaks non-sendable references and breaks isolation.
actor MetricsRecorder {
    var counters: [String: Int] = [:]

    // ❌ Exposes a mutable reference type to outside world by escaping closure capturing self
    func increment(_ key: String) {
        counters[key, default: 0] += 1
    }

    // ❌ Dangerous: returns internal mutable dictionary by value, inviting race-y copies usage assumptions
    func snapshot() -> [String: Int] {
        counters
    }
}

// MARK: - 3) UIKit + SwiftUI Misuse & Memory Leaks

// ❌ UIViewController that creates a Timer retaining self, never invalidates it (retain cycle).
class LeakyViewController: UIViewController {
    private var timer: Timer?
    private var observer: Any? // ❌ Stored observer not removed for KVO-style API below

    deinit {
        // ❌ Timer not invalidated => retain cycle if scheduled with target/selector
        // ❌ Attempts async work in deinit (not allowed): uncommenting will not compile
        // Task { await doSomething() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // ❌ Schedules timer with target/selector retaining self strongly.
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(tick),
                                     userInfo: nil,
                                     repeats: true)

        // ❌ Adds a NotificationCenter observer without removing (for block-based it's fine to auto-clean on token dealloc, but here we keep a strong ref)
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, // legacy signal
            object: nil,
            queue: .main
        ) { [unowned self] _ in // ❌ `unowned self` can crash if VC deallocs
            self.didReceiveMemoryWarning()
        }

        // ❌ KVO without removal (classic leak/crash territory if the observed deallocs)
        addObserver(self, forKeyPath: "title", options: [.new], context: nil) // ❌ observing self.title is useless and risky
    }

    @objc private func tick() {
        // ❌ Force-try disk IO on main thread
        let path = NSTemporaryDirectory().appending("counter.txt")
        let old = (try? String(contentsOfFile: path)) ?? "0"
        let val = (Int(old) ?? 0) + 1
        try! "\(val)".write(toFile: path, atomically: true, encoding: .utf8) // ❌ try!
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // ❌ Does nothing but still set up KVO
    }

    // ❌ Shadowing UIKit’s memory warning hook with custom method name (confusing intent)
    func didReceiveMemoryWarning() {
        // ❌ Allocate a huge array on memory warning (the worst reaction)
        let _ = [UInt8](repeating: 0xFF, count: 200_000_000) // likely memory pressure
    }
}

// ❌ SwiftUI view that tries to own a UIKit controller strongly and manages its lifecycle manually.
struct MixedView: View {
    // ❌ `@StateObject` for a UIKit controller is wrong; also causes retain cycles via self-capture
    @StateObject var vc = LeakyViewController() as! ObservableObject // ❌ Force-cast to ObservableObject (compile-time error)

    // ❌ Infinite recursion in computed var
    var badTitle: String {
        return badTitle // ❌ boom (runtime stack overflow if ever called)
    }

    var body: some View {
        VStack {
            Text("Hello")
            Button("Do work") {
                // ❌ Access shared mutable state from multiple tasks without synchronization
                Task.detached {
                    for _ in 0..<10_000 {
                        GlobalCache.shared.items.append(UUID().uuidString) // ❌ data race
                    }
                }
                Task.detached {
                    for _ in 0..<10_000 {
                        _ = GlobalCache.shared.items.randomElement() // ❌ data race
                    }
                }
            }
        }
        .onAppear {
            // ❌ Deadlock risk: waiting on semaphore on main thread while scheduling main work
            let sema = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                sema.signal()
            }
            sema.wait() // could deadlock if main queue blocked earlier
        }
    }
}

// MARK: - 4) Protocol/Generics Abuse

// ❌ Protocol with associated type used as existential (compile-time error)
protocol Parser {
    associatedtype Output
    func parse(_ data: Data) -> Output
}

// ❌ Using `Parser` as a type requires `any Parser` in Swift 5.7+, but even then, associatedtype prevents simple use
struct ParserManager {
    var parsers: [Parser] = [] // ❌ error: protocol 'Parser' can only be used as a generic constraint

    mutating func runAll(_ data: Data) -> [Any] {
        // ❌ Can't call parse without knowing Output; this is unsound by design
        return parsers.map { parser in
            // ❌ Pretend we can call it (won't compile)
            return parser.parse(data) // ❌ compile error
        }
    }
}

// MARK: - 5) Random Logic Errors and Unsafe Ops

func unsafeArrayAccess() {
    let numbers = [1, 2, 3]
    // ❌ Out-of-bounds access (runtime crash)
    print(numbers[3])
}

// ❌ Misuse of inout with escaping closure (compile error)
func mutateLater(_ value: inout Int, closure: @escaping () -> Void) {
    // ❌ Escaping closure cannot capture inout parameter; won't compile.
    DispatchQueue.global().async {
        _ = value // ❌ illegal capture
        closure()
    }
}

// ❌ Force-bridging Foundation types without checks
func forceCastExample(_ obj: Any) {
    let dict = obj as! NSDictionary // ❌ force cast
    print(dict["foo"]!)
}

// MARK: - 6) Entrypoint that stitches issues together (not actually used)

final class AppCoordinator {
    private let fetcher = DataFetcher()
    private let metrics = MetricsRecorder()

    func start() {
        // ❌ Ignore result/error, misuse async on non-async context
        Task {
            try? await fetcher.fetchData { result in
                switch result {
                case .success(let data):
                    // ❌ UI update on background thread (if we were in UI)
                    GlobalCache.shared.items.append("size=\(data.count)")
                case .failure:
                    break
                }
            }
        }

        // ❌ Snapshot used as if it were live reference; encourages stale data use
        Task {
            let snap = await metrics.snapshot()
            print("metrics snapshot: \(snap)")
        }

        // ❌ Logic that depends on undefined symbol (won’t compile)
        if shouldUseAdvancedMode { // ❌ 'shouldUseAdvancedMode' not defined
            print("Advanced mode!")
        }
    }
}
