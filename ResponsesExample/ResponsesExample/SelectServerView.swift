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
    @Binding var server: (URL, String?)?
    
    var body: some View {
        VStack {
            List {
                Section("Hosted servers") {
                    Button("OpenAI API") {
                        server = (URL(string: "https://api.openai.com/v1")!, "sk-proj-xxxxx")
                    }
                    Button("Groq") {
                        server = (URL(string: "https://api.groq.com/openai/v1")!, "gsk-xxxxx")
                    }
                }
                Section("Local Pico AI Servers") {
                    if bonjourPico.servers.isEmpty {
                        Text("No Pico AI servers found on this network")
                        Text("Turn on Bonjour in `Pico -> Settings -> Server -> Bonjour` if your server isn't listed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bonjourPico.servers, id: \.self) { server in
                        Button("\(server.name)") {
                            guard let url = URL(string: "http://\(server.ipAddress):\(server.port)") else {
                                print("Invalid url: http://\(server.ipAddress):\(server.port)")
                                return
                            }
                            self.server = (url.appendingPathExtension("v1"), nil)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            
            Button(bonjourPico.isScanning ? "Stop scanning for Pico AI Servers" : "Scan for Pico AI Servers") {
                bonjourPico.startStop()
            }
        }
        .padding()
        .onAppear {
            bonjourPico.startStop()
        }
    }
}
