import SwiftUI

struct CreateInvoiceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    var invoiceToEdit: Invoice?
    
    // Factura
    @State private var invoiceNumber: Int = 0
    @State private var invoiceDate: String = ""
    
    // Emisor
    @State private var issuerName: String = ""
    @State private var issuerAddress: String = ""
    @State private var issuerNIF: String = ""
    @State private var selectedIssuerId: Int? = nil  // ← nuevo

    // Cliente
    @State private var clientName: String = ""
    @State private var clientAddress: String = ""
    @State private var clientNIF: String = ""
    @State private var selectedClientId: Int? = nil
    
    // Observaciones
    @State private var observaciones: String = ""
    
    // IVA e IRPF
    @State private var ivaPercentage: Double = 21.0
    @State private var irpfPercentage: Double = 0.0
    
    // Items
    @State private var items: [InvoiceItem] = []
    
    // Totales
    @State private var baseImponible: Double = 0.0
    @State private var totalIVA: Double = 0.0
    @State private var totalIRPF: Double = 0.0
    @State private var totalFactura: Double = 0.0
    
    // Para abrir la vista de clientes
    @State private var showClientsView = false
    
    // Para editar columnas
    @State private var showColumnsSettings = false
    
    // Para popover de servicios
    @State private var showServicesPopOver = false
    
    // Column labels (cargadas/guardadas en app_settings)
    @State private var labelConcept  = "Concepto"
    @State private var labelModel    = "Modelo"
    @State private var labelBastidor = "Bastidor"
    @State private var labelDate     = "Fecha"
    @State private var labelAmount   = "Importe"
    
    private var numberFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "es_ES")
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.usesGroupingSeparator = false
        nf.generatesDecimalNumbers = true
        return nf
    }
    
    var body: some View {
        // SCROLLVIEW para toda la pantalla
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                
                Text(invoiceToEdit == nil ? "Nueva Factura" : "Editar Factura")
                    .font(.title)
                
                // Datos de la factura
                Group {
                    Text("Datos de la factura").font(.headline)
                    HStack {
                        Text("N.º de factura:")
                        TextField("", value: $invoiceNumber, formatter: NumberFormatter())
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Fecha factura:")
                        TextField("dd/MM/yyyy", text: $invoiceDate)
                            .frame(width: 140)
                    }
                }
                Divider()
                
                // Datos Emisor
                Group {
                    Text("Datos Emisor").font(.headline)
                    
                    // NUEVO PICKER (opcional)
                    Picker("Seleccionar Emisor (guardado)", selection: $selectedIssuerId) {
                        Text("-- Sin seleccionar --").tag(Int?.none)
                        ForEach(dbManager.fetchAllIssuers()) { issuer in
                            Text("\(issuer.name)")
                                .tag(issuer.id as Int?)
                        }
                    }
                    .onChange(of: selectedIssuerId) { newValue in
                        if let emId = newValue,
                           let found = dbManager.fetchAllIssuers().first(where: { $0.id == emId }) {
                            issuerName = found.name
                            issuerAddress = found.address
                            issuerNIF = found.nif
                        }
                    }
                    
                    TextField("Razón Social / Nombre", text: $issuerName)
                    TextField("Dirección", text: $issuerAddress)
                    TextField("NIF/CIF", text: $issuerNIF)
                }
                Divider()
                
                // Datos Cliente
                Group {
                    Text("Datos Cliente").font(.headline)
                    
                    Picker("Seleccionar cliente guardado", selection: $selectedClientId) {
                        Text("-- Sin seleccionar --").tag(Int?.none)
                        ForEach(dbManager.clients) { client in
                            if client.nick.isEmpty {
                                Text(client.name).tag(client.id as Int?)
                            } else {
                                Text("\(client.name) (\(client.nick))")
                                    .tag(client.id as Int?)
                            }
                        }
                    }
                    .onChange(of: selectedClientId) { newValue in
                        if let cid = newValue,
                           let found = dbManager.clients.first(where: { $0.id == cid }) {
                            clientName = found.name
                            clientAddress = found.address
                            clientNIF = found.nif
                        }
                    }
                    
                    Button("Gestionar Clientes") {
                        showClientsView = true
                    }
                    
                    TextField("Razón Social / Nombre", text: $clientName)
                    TextField("Dirección", text: $clientAddress)
                    TextField("NIF/CIF", text: $clientNIF)
                }
                Divider()
                
                // Observaciones
                Group {
                    Text("Observaciones").font(.headline)
                    TextEditor(text: $observaciones)
                        .frame(minHeight: 60)
                }
                Divider()
                
                // CONCEPTOS
                Group {
                    HStack {
                        Text("Conceptos de la Factura").font(.headline)
                        Spacer()
                        Button("Editar Columnas") {
                            showColumnsSettings = true
                        }
                    }
                    
                    HStack {
                        Button("Insertar Servicio") {
                            showServicesPopOver = true
                        }
                        Spacer()
                    }
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Cabecera
                            HStack {
                                Text(labelConcept)
                                    .frame(width: 120, alignment: .leading)
                                Text(labelModel)
                                    .frame(width: 100, alignment: .leading)
                                Text(labelBastidor)
                                    .frame(width: 100, alignment: .leading)
                                Text(labelDate)
                                    .frame(width: 80, alignment: .leading)
                                Text(labelAmount)
                                    .frame(width: 80, alignment: .trailing)
                                Spacer().frame(width: 30)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 4)
                            
                            Divider()
                            
                            // Filas
                            ForEach($items, id: \.localUUID) { $item in
                                HStack {
                                    TextField("", text: $item.concept)
                                        .frame(width: 120)
                                    TextField("", text: $item.model)
                                        .frame(width: 100)
                                    TextField("", text: $item.bastidor)
                                        .frame(width: 100)
                                    TextField("", text: $item.date)
                                        .frame(width: 80)
                                    
                                    TextField("", value: $item.amount, formatter: numberFormatter)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.trailing)
                                    
                                    Button {
                                        removeItem(item)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .frame(width: 30, alignment: .center)
                                }
                                .padding(.vertical, 2)
                            }
                            
                            // Añadir Fila
                            Button("Añadir Fila") {
                                let newItem = InvoiceItem(
                                    id: nil,
                                    localUUID: UUID(),
                                    concept: "",
                                    model: "",
                                    bastidor: "",
                                    date: "",
                                    amount: 0.0
                                )
                                items.append(newItem)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .border(Color.gray)
                    .frame(minHeight: 200, maxHeight: 300)
                }
                Divider()
                
                // IMPUESTOS
                Group {
                    Text("Impuestos").font(.headline)
                    HStack {
                        Text("IVA (%)")
                        TextField("", value: $ivaPercentage, formatter: numberFormatter)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("IRPF (%)")
                        TextField("", value: $irpfPercentage, formatter: numberFormatter)
                            .frame(width: 60)
                    }
                }
                Divider()
                
                // TOTALES
                Group {
                    Text("Totales").font(.headline)
                    HStack {
                        Text("Base Imponible:")
                        Spacer()
                        Text(String(format: "%.2f €", baseImponible))
                    }
                    HStack {
                        Text("IVA (\(ivaPercentage, specifier: "%.2f")%)")
                        Spacer()
                        Text(String(format: "%.2f €", totalIVA))
                    }
                    HStack {
                        Text("IRPF (\(irpfPercentage, specifier: "%.2f")%)")
                        Spacer()
                        Text(String(format: "%.2f €", totalIRPF))
                    }
                    HStack {
                        Text("TOTAL Factura:")
                            .fontWeight(.bold)
                        Spacer()
                        Text(String(format: "%.2f €", totalFactura))
                            .fontWeight(.bold)
                    }
                }
                
                // Botón Guardar
                HStack {
                    Spacer()
                    Button("Guardar") {
                        saveInvoice()
                    }
                    .padding(.vertical, 6)
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        // Tamaño mínimo ventana
        .frame(minWidth: 900, minHeight: 600)
        
        // HOJAS emergentes
        .sheet(isPresented: $showClientsView) {
            ClientsView()
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showColumnsSettings, onDismiss: loadColumnLabels) {
            ItemColumnsSettingsView()
                .environmentObject(dbManager)
        }
        .popover(isPresented: $showServicesPopOver) {
            ServicesPopoverView { selectedService in
                // Al seleccionar un Service, se añade un item con su precio
                let newItem = InvoiceItem(
                    id: nil,
                    localUUID: UUID(),
                    concept: selectedService.serviceName,
                    model: "",
                    bastidor: "",
                    date: "",
                    amount: selectedService.servicePrice
                )
                items.append(newItem)
                showServicesPopOver = false
            }
            .environmentObject(dbManager)
        }
        .onAppear {
            setupView()
            loadColumnLabels()
        }
        .onChange(of: items) { _ in recalcTotals() }
        .onChange(of: ivaPercentage) { _ in recalcTotals() }
        .onChange(of: irpfPercentage) { _ in recalcTotals() }
    }
    
    // Eliminar fila
    private func removeItem(_ target: InvoiceItem) {
        if let idx = items.firstIndex(where: { $0.localUUID == target.localUUID }) {
            items.remove(at: idx)
            recalcTotals()
        }
    }
    
    // Cargar la factura si es edición
    private func setupView() {
        if let existing = invoiceToEdit {
            invoiceNumber   = existing.invoiceNumber
            invoiceDate     = existing.invoiceDate
            issuerName      = existing.issuerName
            issuerAddress   = existing.issuerAddress
            issuerNIF       = existing.issuerNIF
            clientName      = existing.clientName
            clientAddress   = existing.clientAddress
            clientNIF       = existing.clientNIF
            observaciones   = existing.observaciones
            ivaPercentage   = existing.ivaPercentage
            irpfPercentage  = existing.irpfPercentage
            items           = existing.items
            baseImponible   = existing.baseImponible
            totalIVA        = existing.totalIVA
            totalIRPF       = existing.totalIRPF
            totalFactura    = existing.totalFactura
            
            // issuerId
            selectedIssuerId = existing.issuerId
        } else {
            invoiceNumber = dbManager.getNextInvoiceNumber()
            let df = DateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            invoiceDate = df.string(from: Date())
            
            issuerName    = "ETM INSTANT WORK S.L"
            issuerAddress = "Calle Lluís Duran 40, 08100 Mollet del Valles (Barcelona)"
            issuerNIF     = ""
            ivaPercentage = 21.0
            irpfPercentage = 0.0
        }
    }
    
    // Leer las etiquetas personalizadas de la DB
    private func loadColumnLabels() {
        labelConcept  = dbManager.getSettingValue(forKey: "column_concept_label")
        labelModel    = dbManager.getSettingValue(forKey: "column_model_label")
        labelBastidor = dbManager.getSettingValue(forKey: "column_bastidor_label")
        labelDate     = dbManager.getSettingValue(forKey: "column_date_label")
        labelAmount   = dbManager.getSettingValue(forKey: "column_amount_label")

        print("DEBUG CreateInvoiceView.loadColumnLabels() -> [\(labelConcept), \(labelModel), \(labelBastidor), \(labelDate), \(labelAmount)]")
        
        // fallbacks
        if labelConcept.isEmpty  { labelConcept  = "Concepto"  }
        if labelModel.isEmpty    { labelModel    = "Modelo"    }
        if labelBastidor.isEmpty { labelBastidor = "Bastidor"  }
        if labelDate.isEmpty     { labelDate     = "Fecha"     }
        if labelAmount.isEmpty   { labelAmount   = "Importe"   }
    }
    
    // Recalcular totales
    private func recalcTotals() {
        let base = items.reduce(0.0) { $0 + $1.amount }
        baseImponible = base
        
        let iva = base * (ivaPercentage / 100.0)
        totalIVA = iva
        
        let irpf = base * (irpfPercentage / 100.0)
        totalIRPF = irpf
        
        totalFactura = base + iva - irpf
    }
    
    // Guardar la factura
    private func saveInvoice() {
        recalcTotals()
        let invoice = Invoice(
            id: invoiceToEdit?.id,
            issuerId: selectedIssuerId, // ← nuevo
            invoiceNumber: invoiceNumber,
            invoiceDate: invoiceDate,
            issuerName: issuerName,
            issuerAddress: issuerAddress,
            issuerNIF: issuerNIF,
            clientName: clientName,
            clientAddress: clientAddress,
            clientNIF: clientNIF,
            observaciones: observaciones,
            items: items,
            ivaPercentage: ivaPercentage,
            irpfPercentage: irpfPercentage,
            baseImponible: baseImponible,
            totalIVA: totalIVA,
            totalIRPF: totalIRPF,
            totalFactura: totalFactura
        )
        if invoiceToEdit == nil {
            dbManager.insertInvoice(invoice)
        } else {
            dbManager.updateInvoice(invoice)
        }
        dismiss()
    }
}

// Popover de servicios
struct ServicesPopoverView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let onSelect: (Service) -> Void
    
    var body: some View {
        List {
            ForEach(dbManager.fetchAllServices()) { svc in
                Button {
                    onSelect(svc)
                } label: {
                    Text("\(svc.serviceName) - \(svc.servicePrice, specifier: "%.2f")€")
                }
            }
        }
        .frame(width: 250, height: 300)
    }
}
