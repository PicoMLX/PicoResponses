//
//  ConnectServerView.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/6/25.
//

import SwiftUI
import BonjourPico

struct SelectServerView: View {
    
    @State var bonjourPico = BonjourPico()
    @Binding var serverURL: URL?
    @State private var selection: PicoHomelabModel?
    
    var body: some View {
        VStack {
            List(bonjourPico.servers, id: \.self, selection: $selection) { server in
                Text("\(server.name)")
            }
            
            Button(bonjourPico.isScanning ? "Stop scanning" : "Scan for Pico AI Homelab servers") {
                bonjourPico.startStop()
            }
        }
        .padding()
        .onChange(of: selection) { _, server in
            guard let server else { return }
            guard let url = URL(string: "http://\(server.ipAddress):\(server.port)") else {
                print("Invalid url: http://\(server.ipAddress):\(server.port)")
                return
            }
            serverURL = url.appendingPathExtension("v1")
        }
        .onAppear {
            bonjourPico.startStop()
        }
    }
}
