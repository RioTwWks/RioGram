import AVFoundation
import CallKit
import Flutter
import UIKit

final class CallPlatformPlugin: NSObject, FlutterPlugin, CXProviderDelegate {
  private var channel: FlutterMethodChannel?
  private let provider: CXProvider
  private let callController = CXCallController()
  private var activeCalls: [UUID: UUID] = [:]

  override init() {
    let config = CXProviderConfiguration(localizedName: "RioGram")
    config.supportsVideo = true
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    provider = CXProvider(configuration: config)
    super.init()
    provider.setDelegate(self, queue: nil)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CallPlatformPlugin()
    let channel = FlutterMethodChannel(
      name: "riogram/call_platform",
      binaryMessenger: registrar.messenger()
    )
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startActiveCall":
      guard let args = call.arguments as? [String: Any],
            let uuidString = args["callUuid"] as? String,
            let handle = args["handle"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
        result(nil)
        return
      }
      let isIncoming = args["isIncoming"] as? Bool ?? false
      if isIncoming {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = args["isVideo"] as? Bool ?? false
        provider.reportNewIncomingCall(with: uuid, update: update) { _ in
          result(nil)
        }
      } else {
        let startAction = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: handle))
        startAction.isVideo = args["isVideo"] as? Bool ?? false
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { _ in
          result(nil)
        }
      }
      activeCalls[uuid] = uuid
    case "reportIncomingCall":
      guard let args = call.arguments as? [String: Any],
            let uuidString = args["callUuid"] as? String,
            let handle = args["handle"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
        result(nil)
        return
      }
      let update = CXCallUpdate()
      update.remoteHandle = CXHandle(type: .generic, value: handle)
      update.hasVideo = args["isVideo"] as? Bool ?? false
      provider.reportNewIncomingCall(with: uuid, update: update) { _ in
        result(nil)
      }
      activeCalls[uuid] = uuid
    case "setCallConnected":
      result(nil)
    case "endActiveCall":
      guard let args = call.arguments as? [String: Any],
            let uuidString = args["callUuid"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
        result(nil)
        return
      }
      provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
      activeCalls.removeValue(forKey: uuid)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    channel?.invokeMethod("onCallKitAccept", arguments: action.callUUID.uuidString)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    channel?.invokeMethod("onCallKitEnd", arguments: action.callUUID.uuidString)
    activeCalls.removeValue(forKey: action.callUUID)
    action.fulfill()
  }

  func providerDidReset(_ provider: CXProvider) {
    activeCalls.removeAll()
  }
}
