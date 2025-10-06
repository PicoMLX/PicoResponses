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
    
    var body: some View {
        VStack {
            List(bonjourPico.servers, id: \.self) { server in
                let domain = "\(server.hostName):\(server.port)"
                let ip = "\(server.ipAddress):\(server.port)"
                Text("\(server.name): \(domain) \(ip)")
            }
            
            Button(bonjourPico.isScanning ? "Stop scanning" : "Scan for Pico AI Homelab servers") {
                bonjourPico.startStop()
            }
        }
        .padding()
    }
}
