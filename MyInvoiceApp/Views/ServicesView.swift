import SwiftUI

struct ServicesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var newName: String = ""
    @State private var newDesc: String = ""
    @State private var newPrice: Double = 0.0
    
    @State private var services: [Service] = []
    
    // Para edición
    @State private var editService: Service? = nil
    @State private var editName: String = ""
    @State private var editDesc: String = ""
    @State private var editPrice: Double = 0.0
    
    @State private var showEditSheet = false
    
    var body: some View {
        VStack {
            Text("Servicios / Productos")
                .font(.largeTitle)
            
            HStack(alignment: .top) {
                // FORM para añadir
                VStack(alignment: .leading) {
                    TextField("Nombre del Servicio", text: $newName)
                    TextField("Descripción", text: $newDesc)
                    TextField("Precio", value: $newPrice, formatter: NumberFormatter())
                    
                    Button("Añadir Servicio") {
                        let s = Service(
                            serviceName: newName,
                            serviceDescription: newDesc,
                            servicePrice: newPrice
                        )
                        dbManager.insertService(s)
                        loadServices()
                        clearNewFields()
                    }
                    .disabled(newName.isEmpty)
                }
                .frame(width: 250)
                
                Divider()
                
                // LISTA
                List {
                    ForEach(services) { svc in
                        VStack(alignment: .leading) {
                            Text(svc.serviceName).font(.headline)
                            Text(svc.serviceDescription).font(.subheadline)
                            Text(String(format: "%.2f €", svc.servicePrice))
                                .font(.footnote)
                        }
                        .contextMenu {
                            Button("Editar") {
                                editService = svc
                                editName  = svc.serviceName
                                editDesc  = svc.serviceDescription
                                editPrice = svc.servicePrice
                                showEditSheet = true
                            }
                            Button("Borrar", role: .destructive) {
                                dbManager.deleteService(svc)
                                loadServices()
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
                }.padding(.top)
            }
        }
        .padding()
        .onAppear {
            loadServices()
        }
        .sheet(isPresented: $showEditSheet) {
            editView
        }
    }
    
    private func loadServices() {
        services = dbManager.fetchAllServices()
    }
    
    private func clearNewFields() {
        newName = ""
        newDesc = ""
        newPrice = 0.0
    }
    
    @ViewBuilder
    private var editView: some View {
        if let svc = editService {
            VStack {
                Text("Editar Servicio").font(.headline)
                TextField("Nombre", text: $editName)
                TextField("Descripción", text: $editDesc)
                TextField("Precio", value: $editPrice, formatter: NumberFormatter())
                
                HStack {
                    Spacer()
                    Button("Guardar") {
                        let updated = Service(
                            id: svc.id,
                            serviceName: editName,
                            serviceDescription: editDesc,
                            servicePrice: editPrice
                        )
                        dbManager.updateService(updated)
                        loadServices()
                        showEditSheet = false
                    }
                    Button("Cancelar") {
                        showEditSheet = false
                    }
                }.padding(.top)
            }
            .padding()
            .frame(width: 300)
        }
    }
}
