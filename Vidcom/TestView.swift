//
//  TestView.swift
//  Vidcom
//
//  Created by Teema Khawjit on 11/6/23.
//

import SwiftUI
import PhotosUI

struct TestView: View {
    @State private var selectedFile: PhotoPickerItem? = nil

    var body: some View {
        VStack {
            if let item = selectedFile {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)

                Text("File Name: \(item.fileURL?.lastPathComponent ?? "N/A")")

                // If you want to display the full file URL:
                Text("File URL: \(item.fileURL?.absoluteString ?? "N/A")")
            } else {
                Text("No file selected")
            }

            PhotoPicker(selection: $selectedFile)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


#Preview {
    TestView()
}
