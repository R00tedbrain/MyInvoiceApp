import SwiftUI

struct IssuersView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    // Campos para crear un nuevo emisor
    @State private var newName: String = ""
    @State private var newAddress: String = ""
    @State private var newNif: String = ""
    @State private var newPhone: String = ""
    
    // Para edición
    @State private var editIssuer: Issuer? = nil
    @State private var editName: String = ""
    @State private var editAddress: String = ""
    @State private var editNif: String = ""
    @State private var editPhone: String = ""
    @State private var showEditSheet = false
    
    // Listado local
    @State private var issuers: [Issuer] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Gestión de Emisores")
                .font(.title)
                .padding(.bottom, 8)
            
            HStack(alignment: .top) {
                // Formulario para añadir un emisor
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Nombre/Razón Social", text: $newName)
                    TextField("Dirección", text: $newAddress)
                    TextField("NIF/CIF", text: $newNif)
                    TextField("Teléfono", text: $newPhone)
                    
                    Button("Añadir Emisor") {
                        addIssuer()
                    }
                    .disabled(newName.isEmpty || newAddress.isEmpty)
                }
                .frame(width: 300)
                
                Divider()
                
                // Lista de emisores
                List {
                    ForEach(issuers) { issuer in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issuer.name).font(.headline)
                            Text(issuer.address).font(.subheadline)
                            Text("NIF: \(issuer.nif)").font(.footnote)
                            if !issuer.phone.isEmpty {
                                Text("Tel: \(issuer.phone)")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                            }
                        }
                        .contextMenu {
                            Button("Editar") {
                                editIssuer = issuer
                                editName = issuer.name
                                editAddress = issuer.address
                                editNif = issuer.nif
                                editPhone = issuer.phone
                                showEditSheet = true
                            }
                            Button("Borrar", role: .destructive) {
                                dbManager.deleteIssuer(issuer)
                                loadIssuers()
                            }
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
        .frame(minWidth: 900, minHeight: 500)
        .onAppear {
            loadIssuers()
        }
        .sheet(isPresented: $showEditSheet) {
            editView
        }
    }
    
    private func addIssuer() {
        dbManager.insertIssuer(name: newName,
                               address: newAddress,
                               nif: newNif,
                               phone: newPhone)
        loadIssuers()
        newName = ""
        newAddress = ""
        newNif = ""
        newPhone = ""
    }
    
    private func loadIssuers() {
        issuers = dbManager.fetchAllIssuers()
    }
    
    @ViewBuilder
    private var editView: some View {
        if let issuer = editIssuer {
            VStack(alignment: .leading) {
                Text("Editar Emisor").font(.title2)
                
                TextField("Nombre/Razón Social", text: $editName)
                TextField("Dirección", text: $editAddress)
                TextField("NIF/CIF", text: $editNif)
                TextField("Teléfono", text: $editPhone)
                
                HStack {
                    Spacer()
                    Button("Guardar") {
                        let updated = Issuer(
                            id: issuer.id,
                            name: editName,
                            address: editAddress,
                            nif: editNif,
                            phone: editPhone
                        )
                        dbManager.updateIssuer(updated)
                        showEditSheet = false
                        loadIssuers()
                    }
                    Button("Cancelar") {
                        showEditSheet = false
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(width: 350)
        }
    }
}
