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

/// Dispatch Queues to Send and Receive Messages
let sem = DispatchSemaphore(value: 0)
let queue = DispatchQueue(label: "a", qos: .background)

class DemoClient: MQTTClientDelegate {

    /// Azure IoT Client
    private var AzureIoTClientSwift : AzureIoTClient! = nil

    /// MQTT Client
    private var mqttClient: MQTTClient! = nil
    
    var delegateDispatchQueue: DispatchQueue {
        queue
    }

    init(iothub: String, deviceId: String)
    {
        AzureIoTClientSwift = AzureIoTClient(iothubUrl: iothub, deviceId: deviceId)

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
            host: "\(iothub)",
            port: 8883,
            clientID: "\(deviceId)",
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
        let swiftString = AzureIoTClientSwift.GetTelemetryPublishTopic()

        let telem_payload = "Hello iOS"
        print("Sending a message: \(telem_payload)")

        mqttClient.publish(topic: swiftString, retain: false, qos: QOS.0, payload: telem_payload)
    }

    //Connect the device to iothub
    func connectToIoTHub() {
        mqttClient.connect()
    }

    func disconnectFromIoTHub() {
        mqttClient.disconnect();
    }
}

private var myDeviceId: String = "ios"
private var myHubURL: String = "dawalton-hub.azure-devices.net"

var hubDemoClient = DemoClient(iothub: myHubURL, deviceId: myDeviceId)

hubDemoClient.connectToIoTHub()

while(!sendTelemetry)
{
    //Waiting
}

for x in 0...5
{
    queue.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(x))
    {
        hubDemoClient.sendMessage()
    }
}

queue.asyncAfter(deadline: .now() + 20) {
    print("Ending")
    hubDemoClient.disconnectFromIoTHub()
}

sem.wait()
