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

struct VidData: Identifiable {
    var id: Int
    var thumbnail: UIImage
    var url: URL
    var duration: Double
    var time: String
    var location: String
}

struct ContentView: View {
    enum LoadState {
        case unknown, loading, loaded, failed
    }
    
    enum AllLoadState {
        case unknown, loading, loaded, failed
    }
    
    @State var videoURLs: [URL] = []
    
    @State var id: Int = 0
    @State private var count: Int = 0
    @State var frame: UIImage = UIImage(named: "kbv")!
    @State var duration: Double = 0.00000
    @State var time: String = ""
    @State var location = ""
    @State var vidDatas: [VidData] = []
    @State var cum: [Double] = []
        
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadState = LoadState.unknown
    @State private var allLoadState = AllLoadState.unknown
    @State private var mergedVideoURL: URL?
    @State private var withDate: Bool = false
 
    private var combinedText: String {
        vidDatas.map { "\(secondToTimestamp(seconds: $0.duration)) \($0.time) \($0.location)" }
                      .joined(separator: "\n")
        }
                
    var body: some View {
        ZStack {
            NavigationStack {
                HStack {
                    if selectedItems != [] {
                        Button("Reset") {
                            selectedItems = []
                            vidDatas = []
                            loadState = .unknown
                            allLoadState = .unknown
                            count = 0
                            duration = 0.0000
                            time = ""
                            location = ""
                            cum = []
                        }
                    } else {
                        PhotosPicker("Upload", selection: $selectedItems, matching: .videos)
                    }
                    
                    Spacer()
                    if allLoadState == .loading {
                        Text("\(count) Uploaded")
                    }
                    Spacer()
                    
                    Toggle("Date", isOn: $withDate)
                                .toggleStyle(.button)
                }
                .padding()
                Spacer()
                
                if allLoadState == .loaded {
                    List(vidDatas) { vidData in
                        ZStack {
                            Image(uiImage: vidData.thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hue: 0, saturation: 0, brightness: 0, opacity: 0.90), .clear]),
                                       startPoint: .bottom,
                                       endPoint: .top
                                   )

                            VStack {
                                Spacer()
                                
                                HStack(alignment: .bottom) {
                                    
                                    if withDate {
                                        VStack(alignment: .leading) {
                                            Text("\(vidData.duration)")
                                            Text("\(vidData.time)")
                                                .opacity(0.5)
                                        }
                                    } else {
                                        Text("\(vidData.duration)")
                                        Text("\(vidData.time)")
                                            .opacity(0.5)
                                    }
                                    
                                    Spacer()
                                    if vidData.id != vidDatas.count {
                                        Button("Split") {
                                            print("Videos after video  \(vidData.id) is added by 1 second")
                                            
                                            for i in vidData.id...(vidDatas.count - 1) {
                                                vidDatas[i].duration += 1
                                            }
                                            
                                            // Perform the copy all action
                                            UIPasteboard.general.string = combinedText
                                        }
                                        .frame(width: 80, height: 30)
                                        .background(.white)
                                        .cornerRadius(20)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding(20)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            VStack {
                Spacer()
                Button("Make timestamps list") {
                    
                    //sort by time
                    vidDatas.sort {
                        $0.time < $1.time
                    }
                    makeTimestampsList()
                    UIPasteboard.general.string = combinedText
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
                    allLoadState = .loading
                    UIApplication.shared.isIdleTimerDisabled = true
                    for item in selectedItems {
                        do {
                            loadState = .loading
                            
                            if let video = try await item.loadTransferable(type: Video.self) {
                                loadState = .loaded
                                self.videoURLs.append(video.url)
                                Task {
                                    try await loadData(video.url)
                                    count += 1
                                }
                            } else {
                                loadState = .failed
                            }
                        } catch {
                            loadState = .failed
                        }
                    }
                    allLoadState = .loaded
                }
            }
    }

    
    func loadData(_ videoURL: URL) async throws {
        let asset = AVAsset(url: videoURL)
        
        // A CMTime value and an array of AVMetadataItem.
        
        Task {
            
            id += 1
            
            //------------------------------------------------------------------------------
            // Load video's first frame
            //------------------------------------------------------------------------------
            
            // Create an AVAssetImageGenerator
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true // Adjust for video orientation

                // Define the time for the first frame (0 seconds)
            let frameTime = CMTimeMake(value: 0, timescale: 1)
                
                do {
                    // Generate the CGImage for the first frame
                    let cgImage = try imageGenerator.copyCGImage(at: frameTime, actualTime: nil)
                    
                    // Convert the CGImage to a UIImage
                    frame = UIImage(cgImage: cgImage)
                } catch {
                    print("Error generating thumbnail: \(error.localizedDescription)")
                }
            
            //------------------------------------------------------------------------------
            // Load video's duration
            //------------------------------------------------------------------------------
            
            
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
            
            if withDate {
                time = timestampWithDate(String(item as! Substring))!
            } else {
                time = timestamp(String(item as! Substring))!
            }
            print(time)
            
            //------------------------------------------------------------------------------
            // Load video's location
            //------------------------------------------------------------------------------
                        
            // Find the title in the common key space.
            let locationData = AVMetadataItem.metadataItems(from: metadata,
                                                          filteredByIdentifier: .commonIdentifierLocation)
            
            guard let item = try await locationData.first?.load(.value) else { return }
            print(coordinate(String(item as! Substring)))

            vidDatas.append(VidData(id: id, thumbnail: frame, url: videoURL, duration: duration, time: time, location: location))
//            print(dur)
        }
    }
    
    // The rest are function
    
    func timestamp(_ input: String) -> String? {
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

    func timestampWithDate(_ input: String) -> String? {
        let pattern = #"(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2}:\d{2})[+-]\d{4}"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                if let yearRange = Range(match.range(at: 1), in: input),
                   let monthRange = Range(match.range(at: 2), in: input),
                   let dayRange = Range(match.range(at: 3), in: input),
                   let timeRange = Range(match.range(at: 4), in: input) {
                    
                    let year = String(input[yearRange])
                    let month = String(input[monthRange])
                    let day = String(input[dayRange])
                    let time = String(input[timeRange])
                    
                    // Construct the new date format
                    let transformedDate = "\(year.suffix(2))\(month)\(day) \(time)"
                    return transformedDate
                }
            }
        } catch {
            print("Invalid regex pattern")
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
    
    func makeTimestampsList() {
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
    }
}

func cutToBlack() {
    
}

#Preview {
    ContentView()
}
