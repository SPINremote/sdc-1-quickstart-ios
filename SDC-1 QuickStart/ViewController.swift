//
//  ViewController.swift
//  SPIN remote SDC-1 QuickStart
//  
//  Created by Corjan van Hamersveld on 31/01/2017.
//  Copyright © 2017 SPIN remote B.V. All rights reserved.
//
//
// This class handles both the communication with the SPIN remote and updating the GUI.
// 
// In chronological order, this is what happens:
//
// 1. The ViewController is created from the view in the Main storyboard
// 2. A CBCentralManager object is created during the initialization phase of the ViewController.
//    The CBCentralManager will handle all bluetooth communciation.
// 3. The CBCentralManager will invoke a callback where it will report its state (centralManagerDidUpdateState function)
// 4. We will start a bluetooth scan when the CBCentralManager notifies us that bluetooth is powered on and ready to use.
//    We tell the scan to only report bluetooth devices which have a specific SPIN remote bluetooth service (let discoverServiceUUID)
// 5. The CBCentralManager will invoke the didDiscover function. We will try to connect to this bluetooth peripheral and stop scanning.
// 6. Once connected the didConnect function will be called. We will tell the peripheral to discover the SPIN remote services we are interested in.
// 7. The didDiscoverServices function will be called when that succeeds. In that case we request the characteristics that we are interested in.
// 8. The didDiscoverCharacteristicsFor function will be called when that succeeds.
// 9. We will set flag Force Action Notification to true on the SPIN remote via the Command characteristic. This will force the SPIN remote to notify us with all user gestures (rotate, swipe, touchpad etc.)
// 10. The didUpdateValueFor function will be called when we receive a new action from spin
//
// Action ID's:
// 0  : rotate_right_side_up_clockwise
// 1  : rotate_right_side_up_counterclockwise
// 2  : rotate_sideways_clockwise
// 3  : rotate_sideways_counterclockwise
// 4  : rotate_upside_down_clockwise
// 5  : rotate_upside_down_counterclockwise
// 6  : touchpad_swipe_up
// 7  : touchpad_swipe_down
// 8  : touchpad_swipe_left
// 9  : touchpad_swipe_right
// 10 : touchpad_press_north
// 11 : touchpad_press_south
// 12 : touchpad_press_east
// 13 : touchpad_press_west
// 14 : touchpad_press_center
// 15 : touchpad_long_press_north
// 16 : touchpad_long_press_south
// 17 : touchpad_long_press_east
// 18 : touchpad_long_press_west
// 19 : touchpad_long_press_center
// 20 : touchpad_scroll_clockwise
// 21 : touchpad_scroll_counterclockwise
// 22 : reserved
// 23 : reserved
// 24 : spin_wake_up

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // GUI views
    @IBOutlet weak var scanningLabel: UILabel!
    @IBOutlet weak var connectedLabel: UILabel!
    @IBOutlet weak var lastActionIdLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    
    // This bluetooth service UUID is used to discover the SPIN remote (only the SPIN remote has this service)
    let discoverServiceUUID = CBUUID(string: "9DFACA9D-7801-22A0-9540-F0BB65E824FC")
    // This custom SPIN remote service is used to communicate with the SPIN remote (the SPIN Service)
    let spinServiceUUID = CBUUID(string: "5E5A10D3-6EC7-17AF-D743-3CF1679C1CC7")
    // This characteristic is used to receive actions (guestures)
    let actionCharacteristicUUID = CBUUID(string: "182BEC1F-51A4-458E-4B48-C431EA701A3B")
    // This characteristic is used to send commands to the SPIN remote
    let spinCommandCharacteristicUUID = CBUUID(string: "92E92B18-FA20-D486-5E43-099387C61A71")
    
    // Apple's central manager is used to handle all bluetooth communication
    fileprivate var centralManager: CBCentralManager?
    
    // Reference to the active bluetooth peripheral (the SPIN)
    var spinRemotePeripheral : CBPeripheral? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a CBCentralManager object
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop scan when this view is disappearing
        centralManager?.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Store the peripheral object locally and register its delegate
        spinRemotePeripheral = peripheral
        spinRemotePeripheral?.delegate = self
        
        // We found a SPIN remote. No need to keep scanning at this point
        centralManager?.stopScan()
        
        // Try to connect to this SPIN remote
        central.connect(peripheral, options: nil)
        
        // Update GUI
        rssiLabel.text = "\(RSSI.intValue) dB"
        scanningLabel.text = "false"
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        // Now that we are connected we can start discovering the services we need
        peripheral.discoverServices([CBUUID](arrayLiteral: spinServiceUUID))
        
        // Request a new RSSI
        peripheral.readRSSI()
        
        // update GUI
        connectedLabel.text = "true"
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        // Remove peripheral object and unsubscribe from its delegate
        spinRemotePeripheral?.delegate = nil
        spinRemotePeripheral = nil
        
        // Start scanning again
        centralManager?.scanForPeripherals(withServices: [CBUUID](arrayLiteral: discoverServiceUUID), options: nil)
        
        // update GUI
        connectedLabel.text = "false"
        lastActionIdLabel.text = ""
        rssiLabel.text = ""
        scanningLabel.text = "true"
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // We will initiate a bluetooth scan when bluetooth booted up
            centralManager?.scanForPeripherals(withServices: [CBUUID](arrayLiteral: discoverServiceUUID), options: nil)
            scanningLabel.text = "true"
        }
        else {
            // Stop bluetooth scan when bluetooth is disabled
            centralManager?.stopScan()
            scanningLabel.text = "false"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        
        // Update GUI
        rssiLabel.text = "\(RSSI.intValue) dB"
        
        // Request a new RSSI right away. This way iOS will keep calling this function every +/- 1 second
        peripheral.readRSSI()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            
            // Check if we discovered the SPIN service
            if service.uuid == spinServiceUUID {
                
                // Now that we have discovered the SPIN service, we can start discovering the characteristics we need for this service
                peripheral.discoverCharacteristics([CBUUID](arrayLiteral: actionCharacteristicUUID, spinCommandCharacteristicUUID), for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
            if characteristic.uuid == actionCharacteristicUUID {
                // Enable notification
                // We are able to receive the actions from the SPIN remote now
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == spinCommandCharacteristicUUID {
                // We will set flag Force Action Notification to true on the SPIN remote via the Command characteristic
                // This will force the SPIN remote to notify us with all user gestures (rotate, swipe, touchpad etc.)

                var data = Data(bytes: UnsafePointer<UInt8>(
                    [0x08,  // commandId = force action notification (8)
                     0x01]  // enable = false (0) or true (1)
                ), count: 2)
                
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
                
                
                // Set the color of the SPIN remote
                let color = UIColor.green
                
                // Get the RGB components from the UIColor
                var red : CGFloat = 0.0
                var green : CGFloat = 0.0
                var blue : CGFloat = 0.0
                color.getRed(&red, green: &green, blue: &blue, alpha: nil)
                
                // Translate them into RGB bytes
                let redByte = UInt8(red * 255)
                let greenByte = UInt8(green * 255)
                let blueByte = UInt8(blue * 255)
                data = Data(bytes: UnsafePointer<UInt8>(
                    [0x09,      // commandId = set color (9)
                     redByte,   // red component (0-255)
                     greenByte, // green component (0-255)
                     blueByte]  // blue component (0-255)
                ), count: 4)
                
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == actionCharacteristicUUID {
            // Looks like we got a new value for the action characteristic
            
            // The action characteristic sends us 1 byte. The action id.
            var id = UInt8()
            characteristic.value?.copyBytes(to: &id, count: 1)
            
            let actionStrings = [String](arrayLiteral:
                "rotate_right_side_up_clockwise",
                "rotate_right_side_up_counterclockwise",
                "rotate_sideways_clockwise",
                "rotate_sideways_counterclockwise",
                "rotate_upside_down_clockwise",
                "rotate_upside_down_counterclockwise",
                "touchpad_swipe_up",
                "touchpad_swipe_down",
                "touchpad_swipe_left",
                "touchpad_swipe_right",
                "touchpad_press_north",
                "touchpad_press_south",
                "touchpad_press_east",
                "touchpad_press_west",
                "touchpad_press_center",
                "touchpad_long_press_north",
                "touchpad_long_press_south",
                "touchpad_long_press_east",
                "touchpad_long_press_west",
                "touchpad_long_press_center",
                "touchpad_scroll_clockwise",
                "touchpad_scroll_counterclockwise",
                "reserved",
                "reserved",
                "spin_wake_up")
            
            let actionAsString = Int(id) < actionStrings.count ? actionStrings[Int(id)] : "unknown"
            
            // update GUI
            lastActionIdLabel.text = "\(id.description) - \(actionAsString)"
        }
    }
    
}
