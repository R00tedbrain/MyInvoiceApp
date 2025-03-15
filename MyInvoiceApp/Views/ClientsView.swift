import SwiftUI

struct ClientsView: View {
    
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var newName: String = ""
    @State private var newAddress: String = ""
    @State private var newNif: String = ""
    @State private var newNick: String = "" // ← Nuevo
    
    // Para editar
    @State private var editClient: Client? = nil
    @State private var editName: String = ""
    @State private var editAddress: String = ""
    @State private var editNif: String = ""
    @State private var editNick: String = "" // ← Nuevo
    
    @State private var showEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Gestión de Clientes")
                .font(.title)
                .padding(.bottom, 8)
            
            HStack {
                // Formulario rápido para añadir un nuevo cliente
                VStack(alignment: .leading) {
                    TextField("Nombre / Razón Social", text: $newName)
                    TextField("Dirección", text: $newAddress)
                    TextField("NIF/CIF", text: $newNif)
                    
                    // Campo Nick
                    TextField("Nick (opcional)", text: $newNick)
                    
                    Button("Añadir Cliente") {
                        addClient()
                    }
                    .disabled(newName.isEmpty || newAddress.isEmpty)
                }
                .frame(maxWidth: 300)
                
                Divider()
                
                // Lista de clientes existentes
                List {
                    ForEach(dbManager.clients) { client in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .font(.headline)
                                Text(client.address)
                                    .font(.subheadline)
                                Text("NIF: \(client.nif)")
                                    .font(.footnote)
                                
                                if !client.nick.isEmpty {
                                    Text("Nick: \(client.nick)")
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            Button("Editar") {
                                editClient = client
                                editName = client.name
                                editAddress = client.address
                                editNif = client.nif
                                editNick = client.nick
                                showEditSheet = true
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Button("Borrar", role: .destructive) {
                                dbManager.deleteClient(client)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                .frame(minWidth: 400, minHeight: 400)
            }
            
            HStack {
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
                .padding()
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 500) // Ajuste de tamaño
        .sheet(isPresented: $showEditSheet) {
            editView
        }
    }
    
    private func addClient() {
        let client = Client(
            name: newName,
            address: newAddress,
            nif: newNif,
            nick: newNick  // ← guardamos
        )
        dbManager.insertClient(client)
        newName = ""
        newAddress = ""
        newNif = ""
        newNick = ""   // limpiamos
    }
    
    @ViewBuilder
    private var editView: some View {
        if let editing = editClient {
            VStack(alignment: .leading, spacing: 8) {
                Text("Editar Cliente").font(.title2).padding(.bottom, 5)
                
                TextField("Nombre / Razón Social", text: $editName)
                TextField("Dirección", text: $editAddress)
                TextField("NIF/CIF", text: $editNif)
                TextField("Nick (opcional)", text: $editNick)
                
                HStack {
                    Spacer()
                    Button("Guardar cambios") {
                        let updated = Client(
                            id: editing.id,
                            name: editName,
                            address: editAddress,
                            nif: editNif,
                            nick: editNick
                        )
                        dbManager.updateClient(updated)
                        showEditSheet = false
                    }
                    .padding(.trailing, 10)
                    
                    Button("Cancelar") {
                        showEditSheet = false
                    }
                }
                .padding(.top, 10)
            }
            .padding()
            .frame(minWidth: 400, minHeight: 200)
        }
    }
}
