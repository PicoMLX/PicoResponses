//
//  ConnectServerView.swift
//  ResponsesExample
//
//  Created by Ronald Mannak on 10/6/25.
//

import Foundation
import SwiftUI
import BonjourPico

struct SelectServerView: View {
    
    @State var bonjourPico = BonjourPico()
    @Binding var server: (URL, String?, [String])?
    
    var body: some View {
        VStack {
            List {
                Section("Hosted servers") {
                    Button("OpenAI API") {
                        server = (URL(string: "https://api.openai.com/v1")!, "<#sk-proj-xxxxx#>", ["gpt-5-nano"])
                    }
                    Button("Groq") {
                        server = (URL(string: "https://api.groq.com/openai/v1")!, "<#gsk-xxxxx#>", ["openai/gpt-oss-20b"])
                    }
                }
                Section("Local Pico AI Servers") {
                    if bonjourPico.servers.isEmpty {
                        VStack(alignment: .leading) {
                            Text("No Pico AI servers found on this network")
                            Group {
                                Text("Turn on Bonjour in `Pico -> Settings -> Server -> Bonjour` if your server isn't listed")
                                Text("Or download Pico from the [Mac App Store](https://apps.apple.com/us/app/pico-ai-server-llm-vlm-mlx/id6738607769?mt=12)")
                            }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(bonjourPico.servers, id: \.self) { server in
                        Button("\(server.name)") {
                            guard let baseURL = URL(string: "http://\(server.ipAddress):\(server.port)") else {
                                print("Invalid url: http://\(server.ipAddress):\(server.port)")
                                return
                            }
                            let apiRoot = baseURL.appendingPathComponent("v1")
                            let modelsEndpoint = apiRoot.appendingPathComponent("models")

                            Task {
                                let models = await fetchModels(from: modelsEndpoint)
                                await MainActor.run {
                                    self.server = (apiRoot, nil, models)
                                }
                            }
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

private struct ModelListResponse: Decodable {
    struct ModelInfo: Decodable {
        let id: String
    }

    let data: [ModelInfo]
}

private func fetchModels(from endpoint: URL) async -> [String] {
    do {
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            print("Failed to load models: invalid status code")
            return []
        }
        let decoder = JSONDecoder()
        let modelList = try decoder.decode(ModelListResponse.self, from: data)
        return modelList.data.map { $0.id }
    } catch {
        print("Failed to load models from \(endpoint): \(error)")
        return []
    }
}
