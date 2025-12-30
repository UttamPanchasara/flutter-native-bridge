import Flutter
import UIKit

/// Flutter Native Bridge Plugin for iOS
///
/// Bridges Flutter and native iOS code using Objective-C runtime.
/// Supports both MethodChannel (request-response) and EventChannel (streams).
@objc(FlutterNativeBridgePlugin)
public class FlutterNativeBridgePlugin: NSObject, FlutterPlugin {

    private static var registeredObjects: [String: AnyObject] = [:]
    private static var registrar: FlutterPluginRegistrar?

    // Track active event channels and their sinks
    private static var activeEventChannels: [String: FlutterEventChannel] = [:]
    static var activeStreamSinks: [String: EventSinkWrapper] = [:]
    private static var streamHandlers: [String: StreamHandler] = [:]

    static let eventChannelPrefix = "flutter_native_bridge/events/"

    public static func register(with registrar: FlutterPluginRegistrar) {
        self.registrar = registrar

        let channel = FlutterMethodChannel(
            name: "flutter_native_bridge",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterNativeBridgePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Setup event channels for all registered stream methods
        setupEventChannels()
    }

    /// Setup EventChannels for all stream methods in registered objects.
    private static func setupEventChannels() {
        guard let registrar = registrar else { return }

        for (className, target) in registeredObjects {
            let streamMethods = getStreamMethods(target: target)
            for methodName in streamMethods {
                let channelName = "\(eventChannelPrefix)\(className).\(methodName)"

                // Skip if already setup
                if activeEventChannels[channelName] != nil { continue }

                let eventChannel = FlutterEventChannel(
                    name: channelName,
                    binaryMessenger: registrar.messenger()
                )

                let handler = StreamHandler(className: className, methodName: methodName, target: target)
                eventChannel.setStreamHandler(handler)

                activeEventChannels[channelName] = eventChannel
                streamHandlers[channelName] = handler

                NSLog("FlutterNativeBridge: Setup EventChannel: \(channelName)")
            }
        }
    }

    // MARK: - Registration Methods (Called from FlutterNativeBridge helper)

    static func registerObject(name: String, object: AnyObject) {
        registeredObjects[name] = object
        // Setup event channels for any stream methods in this object
        setupEventChannels()
    }

    static func registerObject(_ object: AnyObject) {
        let name = String(describing: type(of: object))
            .components(separatedBy: ".").last ?? String(describing: type(of: object))
        registeredObjects[name] = object
        // Setup event channels for any stream methods in this object
        setupEventChannels()
    }

    static func unregisterObject(name: String) {
        // Clean up any event channels for this object
        let prefix = "\(eventChannelPrefix)\(name)."
        for channelName in activeEventChannels.keys where channelName.hasPrefix(prefix) {
            activeEventChannels[channelName]?.setStreamHandler(nil)
            activeEventChannels.removeValue(forKey: channelName)
            activeStreamSinks.removeValue(forKey: channelName)
            streamHandlers.removeValue(forKey: channelName)
        }
        registeredObjects.removeValue(forKey: name)
    }

    static func isRegistered(name: String) -> Bool {
        return registeredObjects[name] != nil
    }

    // MARK: - Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Discovery methods
        switch call.method {
        case "_getRegisteredClasses":
            result(Array(FlutterNativeBridgePlugin.registeredObjects.keys))
            return

        case "_getMethods":
            guard let className = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Class name required", details: nil))
                return
            }
            guard let target = FlutterNativeBridgePlugin.registeredObjects[className] else {
                result(FlutterError(code: "NOT_FOUND", message: "Class '\(className)' not registered", details: nil))
                return
            }
            result(getExposedMethods(target: target))
            return

        case "_discover":
            var discovery: [String: [String]] = [:]
            for (name, obj) in FlutterNativeBridgePlugin.registeredObjects {
                discovery[name] = getExposedMethods(target: obj)
            }
            result(discovery)
            return

        case "_getStreams":
            guard let className = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Class name required", details: nil))
                return
            }
            guard let target = FlutterNativeBridgePlugin.registeredObjects[className] else {
                result(FlutterError(code: "NOT_FOUND", message: "Class '\(className)' not registered", details: nil))
                return
            }
            result(FlutterNativeBridgePlugin.getStreamMethods(target: target))
            return

        case "_discoverStreams":
            var discovery: [String: [String]] = [:]
            for (name, obj) in FlutterNativeBridgePlugin.registeredObjects {
                discovery[name] = FlutterNativeBridgePlugin.getStreamMethods(target: obj)
            }
            result(discovery)
            return

        default:
            break
        }

        // Regular method calls (ClassName.methodName)
        let parts = call.method.components(separatedBy: ".")
        guard parts.count == 2 else {
            result(FlutterError(code: "INVALID_FORMAT", message: "Method must be 'ClassName.methodName'", details: nil))
            return
        }

        let className = parts[0]
        let methodName = parts[1]

        guard let target = FlutterNativeBridgePlugin.registeredObjects[className] else {
            result(FlutterError(code: "NOT_FOUND", message: "Class '\(className)' not registered", details: nil))
            return
        }

        // Find and call the method
        let returnValue = invokeMethod(target: target, methodName: methodName, arguments: call.arguments)

        if let error = returnValue as? FlutterError {
            result(error)
        } else if returnValue == nil || returnValue is NSNull {
            result(nil)
        } else {
            result(returnValue)
        }
    }

    // MARK: - Method Invocation

    private func invokeMethod(target: AnyObject, methodName: String, arguments: Any?) -> Any? {
        // Try to find a matching selector
        let selectors = buildSelectors(methodName: methodName, arguments: arguments)

        for selector in selectors {
            if target.responds(to: selector) {
                return performSelector(target: target, selector: selector, arguments: arguments)
            }
        }
        return FlutterError(
            code: "NOT_FOUND",
            message: "Method '\(methodName)' not found. Make sure it's marked with @objc",
            details: nil
        )
    }

    private func buildSelectors(methodName: String, arguments: Any?) -> [Selector] {
        var selectors: [Selector] = []

        if arguments == nil {
            // No arguments
            selectors.append(Selector(methodName))
        } else if let dict = arguments as? [String: Any] {
            // Dictionary arguments - try with parameter names
            let keys = dict.keys.sorted()
            if keys.count == 1 {
                selectors.append(Selector("\(methodName)With\(keys[0].capitalized):"))
                selectors.append(Selector("\(methodName):"))
            } else {
                // Multiple parameters
                var selectorName = methodName
                for (i, key) in keys.enumerated() {
                    if i == 0 {
                        selectorName += "With\(key.capitalized):"
                    } else {
                        selectorName += "\(key):"
                    }
                }
                selectors.append(Selector(selectorName))
                selectors.append(Selector("\(methodName):"))
            }
        } else {
            // Single argument
            selectors.append(Selector("\(methodName):"))
            selectors.append(Selector("\(methodName)With:"))
        }

        return selectors
    }

    private func performSelector(target: AnyObject, selector: Selector, arguments: Any?) -> Any? {
        // Get method return type to handle primitives correctly
        guard let method = class_getInstanceMethod(type(of: target), selector) else {
            return nil
        }

        let returnType = method_copyReturnType(method)
        let fullReturnType = String(cString: returnType)
        free(returnType)

        // Get just the first character which is the actual type encoding
        let returnTypeString = String(fullReturnType.prefix(1))

        // Type encodings: v=void, @=object, c/B=bool, i/s/l/q=int, f/d=float/double

        // Handle void and primitive return types with IMP-based calling
        if returnTypeString != "@" {
            return performPrimitiveSelector(target: target, selector: selector, returnType: returnTypeString, arguments: arguments)
        }

        // Object return type - safe to use perform/takeUnretainedValue
        if arguments == nil {
            let result = target.perform(selector)
            return unwrapResult(result?.takeUnretainedValue())
        }

        // Handle dictionary with single value
        if let dict = arguments as? [String: Any], dict.count == 1, let value = dict.values.first {
            let result = target.perform(selector, with: value)
            return unwrapResult(result?.takeUnretainedValue())
        }

        // Pass arguments directly
        let result = target.perform(selector, with: arguments)
        return unwrapResult(result?.takeUnretainedValue())
    }

    private func performPrimitiveSelector(target: AnyObject, selector: Selector, returnType: String, arguments: Any?) -> Any? {
        // Get IMP for direct calling
        guard let imp = class_getMethodImplementation(type(of: target), selector) else {
            return nil
        }

        switch returnType {
        case "v": // void
            typealias VoidIMP = @convention(c) (AnyObject, Selector) -> Void
            let fn = unsafeBitCast(imp, to: VoidIMP.self)
            fn(target, selector)
            return nil

        case "c", "B": // char/Bool
            typealias BoolIMP = @convention(c) (AnyObject, Selector) -> Bool
            let fn = unsafeBitCast(imp, to: BoolIMP.self)
            return fn(target, selector)

        case "i", "s", "l", "q": // signed int types
            typealias IntIMP = @convention(c) (AnyObject, Selector) -> Int
            let fn = unsafeBitCast(imp, to: IntIMP.self)
            return fn(target, selector)

        case "I", "S", "L", "Q": // unsigned int types
            typealias UIntIMP = @convention(c) (AnyObject, Selector) -> UInt
            let fn = unsafeBitCast(imp, to: UIntIMP.self)
            return Int(fn(target, selector))

        case "f": // float
            typealias FloatIMP = @convention(c) (AnyObject, Selector) -> Float
            let fn = unsafeBitCast(imp, to: FloatIMP.self)
            return Double(fn(target, selector))

        case "d": // double
            typealias DoubleIMP = @convention(c) (AnyObject, Selector) -> Double
            let fn = unsafeBitCast(imp, to: DoubleIMP.self)
            return fn(target, selector)

        default:
            return nil
        }
    }

    private func unwrapResult(_ value: Any?) -> Any? {
        guard let value = value else { return nil }

        // Convert NSNumber to appropriate Swift types
        if let number = value as? NSNumber {
            let type = String(cString: number.objCType)
            switch type {
            case "c", "B": return number.boolValue
            case "i", "s", "l", "q": return number.intValue
            case "f", "d": return number.doubleValue
            default: return number
            }
        }

        return value
    }

    // MARK: - Method Discovery

    private func getExposedMethods(target: AnyObject) -> [String] {
        var methods: Set<String> = []
        let streamMethods = FlutterNativeBridgePlugin.getStreamMethods(target: target)

        var methodCount: UInt32 = 0
        guard let methodList = class_copyMethodList(type(of: target), &methodCount) else {
            return []
        }

        for i in 0..<Int(methodCount) {
            let method = methodList[i]
            let selector = method_getName(method)
            var name = NSStringFromSelector(selector)

            // Filter out system methods
            if name.hasPrefix("_") || name.hasPrefix(".") { continue }
            if name.contains("init") || name.contains("dealloc") { continue }
            if name.contains(".cxx") { continue }

            // Extract method name (before first colon)
            if let colonIndex = name.firstIndex(of: ":") {
                name = String(name[..<colonIndex])
            }

            // Remove "With" suffix if present
            if name.hasSuffix("With") {
                name = String(name.dropLast(4))
            }

            // Exclude stream methods from regular methods
            if streamMethods.contains(name) { continue }

            // Only include user-defined methods
            if !name.isEmpty && name.first?.isLowercase == true {
                methods.insert(name)
            }
        }

        free(methodList)
        return Array(methods).sorted()
    }

    // MARK: - Stream Discovery

    /// Get all stream methods for a target object.
    /// Stream methods are identified by having a StreamSink parameter.
    private static func getStreamMethods(target: AnyObject) -> [String] {
        var methods: Set<String> = []

        var methodCount: UInt32 = 0
        guard let methodList = class_copyMethodList(type(of: target), &methodCount) else {
            return []
        }

        for i in 0..<Int(methodCount) {
            let method = methodList[i]
            let selector = method_getName(method)
            let selectorName = NSStringFromSelector(selector)

            // Filter out system methods
            if selectorName.hasPrefix("_") || selectorName.hasPrefix(".") { continue }
            if selectorName.contains("init") || selectorName.contains("dealloc") { continue }
            if selectorName.contains(".cxx") { continue }

            // Check if this method has a StreamSink parameter
            // Methods with StreamSink will have selector like "methodNameWithSink:" or "methodName:"
            // We check the method signature for StreamSink type
            let numberOfArgs = method_getNumberOfArguments(method)

            // Check each argument type (skip self and _cmd which are first 2)
            var hasStreamSink = false
            for argIndex in 2..<numberOfArgs {
                if let argType = method_copyArgumentType(method, argIndex) {
                    let typeString = String(cString: argType)
                    free(argType)

                    // Check if argument is an object that conforms to StreamSink
                    // The type encoding for id<StreamSink> or similar will contain "@"
                    if typeString.contains("@") {
                        // We need to check if the selector contains "sink" (case insensitive)
                        // This is a heuristic since we can't directly check protocol conformance at runtime
                        let lowerSelector = selectorName.lowercased()
                        if lowerSelector.contains("sink") {
                            hasStreamSink = true
                            break
                        }
                    }
                }
            }

            if hasStreamSink {
                var name = selectorName

                // Extract method name (before first colon)
                if let colonIndex = name.firstIndex(of: ":") {
                    name = String(name[..<colonIndex])
                }

                // Remove "WithSink" suffix if present
                if name.hasSuffix("WithSink") {
                    name = String(name.dropLast(8))
                }

                if !name.isEmpty && name.first?.isLowercase == true {
                    methods.insert(name)
                }
            }
        }

        free(methodList)
        return Array(methods).sorted()
    }

    /// Find and invoke a stream method on a target.
    static func invokeStreamMethod(target: AnyObject, methodName: String, sink: StreamSink, arguments: Any?) {
        // Build possible selectors for stream methods
        let selectors = [
            Selector("\(methodName)WithSink:"),
            Selector("\(methodName):"),
            Selector("\(methodName)WithSink:arguments:"),
            Selector("\(methodName):arguments:")
        ]

        for selector in selectors {
            if target.responds(to: selector) {
                if selector.description.contains("arguments") {
                    _ = target.perform(selector, with: sink, with: arguments)
                } else {
                    _ = target.perform(selector, with: sink)
                }
                return
            }
        }

        // Method not found - send error
        sink.error(code: "NOT_FOUND", message: "Stream method '\(methodName)' not found", details: nil)
    }
}

// MARK: - Stream Handler

/// Handles FlutterEventChannel stream lifecycle.
private class StreamHandler: NSObject, FlutterStreamHandler {
    let className: String
    let methodName: String
    weak var target: AnyObject?

    init(className: String, methodName: String, target: AnyObject) {
        self.className = className
        self.methodName = methodName
        self.target = target
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        guard let target = target else {
            return FlutterError(code: "TARGET_GONE", message: "Target object no longer exists", details: nil)
        }

        let channelName = "\(FlutterNativeBridgePlugin.eventChannelPrefix)\(className).\(methodName)"
        let sinkWrapper = EventSinkWrapper(eventSink: events)
        FlutterNativeBridgePlugin.activeStreamSinks[channelName] = sinkWrapper

        // Invoke the stream method with the sink
        FlutterNativeBridgePlugin.invokeStreamMethod(
            target: target,
            methodName: methodName,
            sink: sinkWrapper,
            arguments: arguments
        )

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let channelName = "\(FlutterNativeBridgePlugin.eventChannelPrefix)\(className).\(methodName)"
        FlutterNativeBridgePlugin.activeStreamSinks.removeValue(forKey: channelName)
        return nil
    }
}

// MARK: - Event Sink Wrapper

/// Wraps Flutter's EventSink to implement our StreamSink protocol.
class EventSinkWrapper: NSObject, StreamSink {
    private let eventSink: FlutterEventSink

    init(eventSink: @escaping FlutterEventSink) {
        self.eventSink = eventSink
        super.init()
    }

    func success(_ event: Any?) {
        eventSink(event)
    }

    func error(code: String, message: String?, details: Any?) {
        eventSink(FlutterError(code: code, message: message, details: details))
    }

    func endOfStream() {
        eventSink(FlutterEndOfEventStream)
    }
}
