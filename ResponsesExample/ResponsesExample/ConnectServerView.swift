//
//  ConnectServerView.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/6/25.
//

import SwiftUI
import BonjourPico

struct ConnectServerView: View {
    
    @State var bonjourPico = BonjourPico()
    @Binding var serverURL: String?
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
            serverURL = "http://\(server.ipAddress):\(server.port)"
        }
        .onAppear {
            bonjourPico.startStop()
        }
    }
}
