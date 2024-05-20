//
//  TestView.swift
//  Vidcom
//
//  Created by Teema Khawjit on 11/6/23.
//

import AVKit
import PhotosUI
import Photos
import SwiftUI

struct TestView: View {

    var body: some View {
        VStack {
            Text("S")
        }
    }
}

extension ContentView {
    func merge(videoURLs: [URL], completion: @escaping (URL?, Error?) -> Void) async throws {
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        print("test")
        var count = 0
        
        let dispatchGroup = DispatchGroup()
        
        for videoURL in videoURLs {
            dispatchGroup.enter()
            let asset = AVAsset(url: videoURL)
            let tracks = try await asset.loadTracks(withMediaType: .video)[0]
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)[0]
            let duration = try await asset.load(.duration)
            count += 1
            print(count)
            do {
                
                let track = composition.addMutableTrack(withMediaType: .video,
                                                        preferredTrackID: kCMPersistentTrackID_Invalid)
                
                try track?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: tracks,
                    at: currentTime)
                
                if let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                                preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: audioTracks,
                        at: currentTime)
                }
                
                currentTime = CMTimeAdd(currentTime, duration)
                
            } catch {
                completion(nil, error)
                return
            }
            dispatchGroup.leave()
        }
        
        //------------------------------------------------------------------------------
        // EXPORT
        //------------------------------------------------------------------------------
        
        guard let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("mergedVideo.mp4") as URL? else {
            completion(nil, NSError(domain: "Error creating export URL", code: 0, userInfo: nil))
            return
        }
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = .mp4
        
        exporter?.exportAsynchronously {
            switch exporter?.status {
            case .completed:
                completion(exportURL, nil)
            case .failed, .cancelled:
                completion(nil, exporter?.error)
            default:
                break
            }
        }
    }
    
    func saveVideoToPhotos(url: URL) {
        print("Workiing")
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if success {
                    print("Video saved to Photos successfully.")
                } else if let error = error {
                    print("Error saving video to Photos: \(error.localizedDescription)")
                }
            }
        }
}

#Preview {
    TestView()
}
