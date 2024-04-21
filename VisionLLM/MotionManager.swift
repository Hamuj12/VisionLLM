//
//  MotionManager.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import CoreMotion
import Foundation

class MotionManager {
    private let motionManager = CMMotionManager()
    var motionHandler: (() -> Void)?
    
    init() {
        motionManager.deviceMotionUpdateInterval = 0.5 // Update every 0.2 seconds
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let motion = motion, error == nil else { return }
            
            // Define a threshold to trigger the motion handler
            let threshold: Double = 0.25 // This value may need to be adjusted
            
            // Check for significant movement
            if abs(motion.userAcceleration.x) > threshold ||
               abs(motion.userAcceleration.y) > threshold ||
               abs(motion.userAcceleration.z) > threshold {
                self?.motionHandler?()
            }
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
