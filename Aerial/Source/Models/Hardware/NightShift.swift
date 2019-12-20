//
//  NightShift.swift
//  Aerial
//
//  Created by Guillaume Louel on 19/12/2019.
//  Copyright © 2019 Guillaume Louel. All rights reserved.
//

import Foundation

struct NightShift {

    static var isNightShiftDataCached = false
    static var nightShiftAvailable = false
    static var nightShiftSunrise = Date()
    static var nightShiftSunset = Date()

    // MARK: Night Shift
    static func isAvailable() -> (Bool, reason: String) {
        if #available(OSX 10.12.4, *) {
            let (isAvailable, sunriseDate, sunsetDate, errorMessage) = NightShift.getInformation()

            if isAvailable {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm:ss", options: 0, locale: Locale.current)
                let sunriseString = dateFormatter.string(from: sunriseDate!)
                let sunsetString = dateFormatter.string(from: sunsetDate!)

                return (true, "Today’s sunrise: " + sunriseString + "  Today’s sunset: " + sunsetString)

            } else {
                isNightShiftDataCached = true
                return (false, errorMessage!)
            }
        } else {
            return (false, "macOS 10.12.4 or above is required")
        }
    }

    // siftlint:disable:next large_tuple
    // swiftlint:disable:next cyclomatic_complexity large_tuple
    static func getInformation() -> (Bool, sunrise: Date?, sunset: Date?, error: String?) {
        if isNightShiftDataCached {
            return (nightShiftAvailable, nightShiftSunrise, nightShiftSunset, nil)
        }

        // On Catalina, corebrightnessdiag was moved to /usr/libexec/ !
        var cbdpath = "/usr/bin/corebrightnessdiag"
        if #available(OSX 10.15, *) {
            cbdpath = "/usr/libexec/corebrightnessdiag"
        }

        let (nsInfo, ts) = shell(launchPath: cbdpath, arguments: ["nightshift-internal"])

        if ts != 0 {
            // Task didn't return correctly ? Abort
            return (false, nil, nil, "Your Mac does not support Night Shift")
        }
        let lines = nsInfo?.split(separator: "\n")
        if lines!.count < 5 {
            // We get a couple of lines of output on unsupported Macs
            return (false, nil, nil, "Your Mac does not support Night Shift")
        }
        var sunrise: Date?, sunset: Date?

        for line in lines ?? [""] {
            if line.contains("sunrise") {
                let tmp = line.split(separator: "\"")
                if tmp.count > 1 {
                    let dateFormatter = DateFormatter()
                    // Catalina fix, this seems to be the correct way to parse the date
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"

                    if let dateObj = dateFormatter.date(from: String(tmp[1])) {
                        sunrise = dateObj
                    }
                }
            } else if line.contains("sunset") {
                let tmp = line.split(separator: "\"")
                if tmp.count > 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"

                    if let dateObj = dateFormatter.date(from: String(tmp[1])) {
                        sunset = dateObj
                    }
                }
            }
        }

        if sunset != nil && sunrise != nil {
            nightShiftSunrise = sunrise!
            nightShiftSunset = sunset!
            nightShiftAvailable = true
            isNightShiftDataCached = true

            return (true, sunrise, sunset, nil)
        }

        // /usr/bin/corebrightnessdiag nightshift-internal | grep nextSunset | cut -d \" -f2
        warnLog("Location services may be disabled, Night Shift can't detect Sunrise and Sunset times without them")
        return (false, nil, nil, "Location services may be disabled")
    }

    private static func shell(launchPath: String, arguments: [String] = []) -> (String?, Int32) {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        task.waitUntilExit()

        return (output, task.terminationStatus)
    }

}