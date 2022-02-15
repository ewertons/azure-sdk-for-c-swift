//
//  AzureIoTSwiftViewController.swift
//  AzureIoTSwiftSample
//
//  Created by Dane Walton on 2/14/22.
//

import Foundation
import MQTT
import NIOSSL
import AzureSDKForCSwift
import CAzureSDKForCSwift

var sendTelemetry: Bool = false;

let base: String
if CommandLine.arguments.count > 1 {
    base = CommandLine.arguments[1]
} else {
    base = "."
}

let sem = DispatchSemaphore(value: 0)
let queue = DispatchQueue(label: "a", qos: .background)

class AzureIoTHubClientSwift: MQTTClientDelegate {

    private var iothub: String = ""
    private var deviceId: String = ""
    private var sasKey: String = ""
    
    private var connectionString: String = ""
    
    private(set) var numReceivedMessages: Int = 0
    
    private(set) var numSentMessages: Int = 0
    private(set) var numSentMessagesGood: Int = 0
    private(set) var numSentMessagesBad: Int = 0
    
    private(set) var isConnected: Bool = false
    private(set) var isSendingTelemetry: Bool = false
    
    private(set) var lastTempValue : String = ""
    private(set) var lastHumidityValue : String = ""
    private(set) var telemetryMessage : String = ""
    
    // Timers used to control message and polling rates
    var timerMsgRate: Timer!
    var timerDoWork: Timer!
    
    private var newClient : AzureIoTClient! = nil

    // IoT hub handle
    private var azIoTHubClient: az_iot_hub_client! = nil

    // MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    var delegateDispatchQueue: DispatchQueue {
        queue
    }
    
    func makeCString(from str: String) -> UnsafeMutablePointer<Int8> {
        let count = str.utf8CString.count
        let result: UnsafeMutableBufferPointer<Int8> = UnsafeMutableBufferPointer<Int8>.allocate(capacity: count)
        _ = result.initialize(from: str.utf8CString)
        return result.baseAddress!
    }

    init(iothub: String, deviceId: String)
    {
        self.iothub = iothub
        self.deviceId = deviceId
        azIoTHubClient = az_iot_hub_client()
        newClient = AzureIoTClient(iothubUrl: iothub, deviceId: deviceId)

        let iothubPointerString = makeCString(from: iothub)
        let deviceIdString = makeCString(from: deviceId)

        let iothubSpan: az_span = iothubPointerString.withMemoryRebound(to: UInt8.self, capacity: iothub.count) { hubPtr in
            return az_span_create(hubPtr, Int32(deviceId.count))
        }
        let deviceIdSpan: az_span = deviceIdString.withMemoryRebound(to: UInt8.self, capacity: deviceId.count) { devPtr in
            return az_span_create(devPtr, Int32(deviceId.count))
        }

        _ = az_iot_hub_client_init(&azIoTHubClient, iothubSpan, deviceIdSpan, nil)

        let caCert = "\(base)/certs/baltimore.pem"
        let clientCert = "\(base)/certs/client.pem"
        let keyCert = "\(base)/certs/client-key.pem"
        let tlsConfiguration = try! TLSConfiguration.forClient(minimumTLSVersion: .tlsv11,
                                                               maximumTLSVersion: .tlsv12,
                                                               certificateVerification: .noHostnameVerification,
                                                               trustRoots: NIOSSLTrustRoots.certificates(NIOSSLCertificate.fromPEMFile(caCert)),
                                                               certificateChain: NIOSSLCertificate.fromPEMFile(clientCert).map { .certificate($0) },
                                                               privateKey: .privateKey(.init(file: keyCert, format: .pem)))
        mqttClient = MQTTClient(
            host: "\(self.iothub)",
            port: 8883,
            clientID: "\(self.deviceId)",
            cleanSession: true,
            keepAlive: 30,
            username: "dawalton-hub.azure-devices.net/ios/?api-version=2018-06-30",
            password: "",
            tlsConfiguration: tlsConfiguration
        )
        mqttClient.tlsConfiguration = tlsConfiguration
        mqttClient.delegate = self
    }
    
/// Needed Functions for MQTTClientDelegate
    
    func mqttClient(_ client: MQTTClient, didReceive packet: MQTTPacket) {
        switch packet {
        case let packet as ConnAckPacket:
            print("Connack \(packet)")
            sendTelemetry = true;
            DispatchQueue.main.async { self.isConnected = true; }
        default:
            print(packet)
        }
    }

    func mqttClient(_: MQTTClient, didChange state: ConnectionState) {
        if state == .disconnected {
            sem.signal()
        }
        print(state)
    }

    func mqttClient(_: MQTTClient, didCatchError error: Error) {
        print("Error: \(error)")
    }

    /// Sends a message to the IoT hub
    public func sendMessage() {

        var topicCharArray = [CChar](repeating: 0, count: 50)
        var topicLength : Int = 0
        
        let _ : az_result = az_iot_hub_client_telemetry_get_publish_topic(&azIoTHubClient, nil, &topicCharArray, 100, &topicLength )
        
        let swiftString = newClient.GetTelemetryPublishTopic()

        let telem_payload = "Hello iOS"
        print("Sending a message: \(telem_payload)")
        mqttClient.publish(topic: String(cString: topicCharArray), retain: false, qos: QOS.0, payload: telem_payload)
        mqttClient.publish(topic: swiftString, retain: false, qos: QOS.0, payload: telem_payload)
    }
    
    public func disconnect()
    {
        mqttClient.disconnect();
    }

    func connect() throws {
        mqttClient.connect()
    }
    
    //Connect the device to iothub
    func connectToIoTHub() {
        
        do
        {
            try self.connect()
        }
        catch
        {
            print("Couldn't connect!")
        }
        
    }
    
    func disconectFromIoTHub() {
        stopSendTelemetryMessages()

        isConnected = false
    }
    
    func stopSendTelemetryMessages() {
        isSendingTelemetry = false
        if(timerMsgRate.isValid) {
            timerMsgRate.invalidate()
        }
    }
}

private var myDeviceId: String = "ios"
private var myHubURL: String = "dawalton-hub.azure-devices.net"

var hubClient = AzureIoTHubClientSwift(iothub: myHubURL, deviceId: myDeviceId)

hubClient.connectToIoTHub()

while(!sendTelemetry)
{
    //Waiting
}

for x in 0...5
{
    queue.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(x))
    {
        hubClient.sendMessage()
    }
}

queue.asyncAfter(deadline: .now() + 40) {
    print("Ending")
    hubClient.disconnect()
}

sem.wait()
