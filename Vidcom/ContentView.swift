//
//  ContentView.swift
//  Vidcom
//
//  Created by Teema Khawjit on 11/6/23.
//

import SwiftUI
import Photos
import PhotosUI
import AVKit
import AVFoundation

struct Video: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appendingPathComponent(UUID.init().uuidString.appending(".mp4"))
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

struct VidData {
    var duration: Double
    var time: String
    var location: String
}

struct ContentView: View {
    enum LoadState {
        case unknown, loading, loaded, failed
    }
    
    @State var videoURLs: [URL] = []
    
    @State var duration: Double = 0.00000
    @State var time: String = ""
    @State var location = ""
    @State var vidDatas: [VidData] = []
    @State var cum: [Double] = []
        
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadState = LoadState.unknown
    @State private var mergedVideoURL: URL?
    
    @State private var showAlert = false
    @State private var userInput: Int = 0
 
    private var combinedText: String {
        vidDatas.map { "\(secondToTimestamp(seconds: $0.duration)) - \(convertTo12HourFormat($0.time) ?? "") - \($0.location)" }
                      .joined(separator: "\n")
        }
                
    var body: some View {
        ZStack {
            NavigationStack {
                HStack {
                    PhotosPicker("Upload", selection: $selectedItems, matching: .videos)
                    Spacer()
                    Button("Copy") {
                        showAlert = true
                    }
                    .fontWeight(.bold)
                    .alert("Cut to Black", isPresented: $showAlert) {
                        TextField("After video number...", value: $userInput, formatter: NumberFormatter())
                        HStack {
                            Button("OK") {
                                // Handle the OK button action
                                print("Videos after video  \(userInput) is added by 1 second")
                                
                                if userInput != 0 {
                                    for i in userInput...(vidDatas.count - 1) {
                                        vidDatas[i].duration += 1
                                    }
                                }
                                
                                // Perform the copy all action
                                UIPasteboard.general.string = combinedText
                            }
                            Button("Cancel", role: .cancel) {
                            }
                        }
                    }
                    
                }
                .padding()
                
                switch loadState {
                case .unknown:
                    EmptyView()
                case .loading:
                    ProgressView()
                case .loaded:
                    List(videoURLs, id: \.self) { videoURL in
                        NavigationLink("Done") {
                            VideoPlayer(player: AVPlayer(url: videoURL))
                                .frame(width: 300)
                                //.allowsHitTesting(false)
                        }
                    }
                    
                case .failed:
                    Text("Import failed")
                }
                
                }
            VStack {
                Spacer()
                Button("Make timestamps list") {
                    cum = []
                    //Cumulative addition sequence
                    var current: Double = 0.00000
                    
                    for vidData in vidDatas {
                        cum.append(current)
                        current += vidData.duration
                    }
    //                print(cum)
                    
                    //replace each cumulative (timestamp) to duration array
                    var i = 0
                    for timestamp in cum {
                        vidDatas[i].duration = timestamp
                        i += 1
                    }
//                    print(vidDatas)
                }
                .frame(width: 300, height: 50)
                .background(.blue)
                .cornerRadius(10)
                .foregroundColor(.white)
                .fontWeight(.medium)
            }
        }
            .onChange(of: selectedItems) {
                videoURLs = []
                vidDatas = []
                
                //------------------------------------------------------------------------------
                // Load videos' URL
                //------------------------------------------------------------------------------
                
                Task {
                    for item in selectedItems {
                        do {
                            loadState = .loading
                            
                            if let video = try await item.loadTransferable(type: Video.self) {
                                loadState = .loaded
                                self.videoURLs.append(video.url)
                                Task {
                                    try await loadData(video.url)
                                }
                            } else {
                                loadState = .failed
                            }
                        } catch {
                            loadState = .failed
                        }
                    }
                }
            }
    }

    
    func loadData(_ videoURL: URL) async throws {
        let asset = AVAsset(url: videoURL)
        
        // A CMTime value and an array of AVMetadataItem.
        
        //------------------------------------------------------------------------------
        // Load video's duration
        //------------------------------------------------------------------------------
        
        Task {
            let durationData = try await asset.load(.duration)
            
            // Determine the loaded status of the duration property.
            switch asset.status(of: .duration) {
            case .notYetLoaded:
                // The initial state of a property.
                print("notYetLoaded")
            case .loading:
                // The asset is actively loading the property value.
                print("loading")
            case .loaded(let durationData):
                // The property is ready to use.
                let value = durationData.value
                let second = CMTime(value: value, timescale: 600)
                duration = Double(CMTimeGetSeconds(second))
                print(duration)
            case .failed(let error):
                // The property value fails to load.
                print(error)
            }
            
            //------------------------------------------------------------------------------
            // Load video's timestamp
            //------------------------------------------------------------------------------
            
            let metadata = try await asset.load(.metadata)
            
            // Find the title in the common key space.
            let timeData = AVMetadataItem.metadataItems(from: metadata,
                                                         filteredByIdentifier: .commonIdentifierCreationDate)
            
            guard let item = try await timeData.first?.load(.value) else { return }
            time = timestamp(from: String(item as! Substring))!
            print(time)
            
            //------------------------------------------------------------------------------
            // Load video's location
            //------------------------------------------------------------------------------
                        
            // Find the title in the common key space.
            let locationData = AVMetadataItem.metadataItems(from: metadata,
                                                          filteredByIdentifier: .commonIdentifierLocation)
            
            guard let item = try await locationData.first?.load(.value) else { return }
            print(coordinate(String(item as! Substring)))

            vidDatas.append(VidData(duration: duration, time: time, location: location))
//            print(dur)
        }
    }
    
    // The rest are function
    
    func timestamp(from input: String) -> String? {
        let pattern = "\\d{2}:\\d{2}:\\d{2}"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
            
            if let match = matches.first {
                let range = Range(match.range, in: input)
                return range.map { String(input[$0]) }
            }
        } catch {
            print("Error creating regex: \(error)")
        }
        
        return nil
    }
    
    func coordinate(_ input: String) -> String {

        // Define a regular expression pattern
        let pattern = "\\+([\\d.]+)\\+([\\d.]+)"

        // Create a regular expression object
        let regex = try! NSRegularExpression(pattern: pattern)

        // Find matches in the input string
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))

        // Extract latitude and longitude if there is at least one match
        if let match = matches.first {
            let latitudeRange = Range(match.range(at: 1), in: input)!
            let longitudeRange = Range(match.range(at: 2), in: input)!

            let latitude = String(input[latitudeRange])
            let longitude = String(input[longitudeRange])

            location = "\(latitude), \(longitude)"
        } else {
            location = "No match found."
        }
        return location
    }
    
    func secondToTimestamp(seconds: Double) -> String {
        let date = Date(timeIntervalSince1970: seconds)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "m:ss"
        return dateFormatter.string(from: date)
    }
    
    func convertTo12HourFormat(_ timeString: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        if let date = dateFormatter.date(from: timeString) {
            dateFormatter.dateFormat = "h:mm:ss a"
            return dateFormatter.string(from: date)
        }

        return nil // Return nil if the conversion fails
    }
}

func cutToBlack() {
    
}

#Preview {
    ContentView()
}
