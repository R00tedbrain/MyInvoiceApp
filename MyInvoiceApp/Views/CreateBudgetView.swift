import SwiftUI

struct CreateBudgetView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    var budgetToEdit: Budget?
    
    // Campos principales
    @State private var budgetNumber: Int = 0
    @State private var budgetDate: String = ""
    @State private var issuerId: Int? = nil
    @State private var clientId: Int? = nil
    @State private var observaciones: String = ""
    
    // Items
    @State private var items: [BudgetItem] = []
    
    // Impuestos
    @State private var ivaPercentage: Double = 21.0
    @State private var irpfPercentage: Double = 0.0
    
    // Totales
    @State private var baseImponible: Double = 0.0
    @State private var totalIVA: Double = 0.0
    @State private var totalIRPF: Double = 0.0
    @State private var totalBudget: Double = 0.0
    
    // Estados para columnas personalizadas
    @State private var labelConcept  = "Concepto"
    @State private var labelModel    = "Modelo"
    @State private var labelBastidor = "Bastidor"
    @State private var labelDate     = "Fecha"
    @State private var labelAmount   = "Importe"

    // Para abrir la hoja de configuración de columnas
    @State private var showColumnsSettings = false
    
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
        VStack(alignment: .leading, spacing: 10) {
            Text(budgetToEdit == nil ? "Nuevo Presupuesto" : "Editar Presupuesto")
                .font(.title)
            
            // Datos principales
            HStack {
                Text("N.º Presupuesto:")
                TextField("", value: $budgetNumber, formatter: NumberFormatter())
                    .frame(width: 60)
            }
            HStack {
                Text("Fecha:")
                TextField("dd/MM/yyyy", text: $budgetDate)
                    .frame(width: 120)
            }
            
            // Emisor
            Text("Seleccionar Emisor").font(.headline)
            Picker("Emisor", selection: $issuerId) {
                Text("-- Ninguno --").tag(Int?.none)
                ForEach(dbManager.fetchAllIssuers()) { issuer in
                    Text("\(issuer.name)")
                        .tag(issuer.id as Int?)
                }
            }
            
            // Cliente
            Text("Seleccionar Cliente").font(.headline)
            Picker("Cliente", selection: $clientId) {
                Text("-- Ninguno --").tag(Int?.none)
                ForEach(dbManager.clients) { c in
                    if c.nick.isEmpty {
                        Text(c.name).tag(c.id as Int?)
                    } else {
                        Text("\(c.name) (\(c.nick))")
                            .tag(c.id as Int?)
                    }
                }
            }
            
            // Observaciones
            Text("Observaciones")
            TextEditor(text: $observaciones)
                .frame(minHeight: 60)
                .border(Color.gray.opacity(0.5))
            
            // Lineas del Presupuesto
            HStack {
                Text("Líneas del Presupuesto").font(.headline)
                Spacer()
                Button("Editar Columnas") {
                    showColumnsSettings = true
                }
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Cabecera (usa labels personalizadas)
                    HStack {
                        Text(labelConcept)
                            .frame(width: 120, alignment: .leading)
                        Text(labelModel)
                            .frame(width: 80, alignment: .leading)
                        Text(labelBastidor)
                            .frame(width: 80, alignment: .leading)
                        Text(labelDate)
                            .frame(width: 60, alignment: .leading)
                        Text(labelAmount)
                            .frame(width: 80, alignment: .trailing)
                        Spacer().frame(width: 30)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    // Filas
                    ForEach($items, id: \.id) { $item in
                        HStack {
                            TextField("", text: $item.concept)
                                .frame(width: 120)
                            TextField("", text: $item.model)
                                .frame(width: 80)
                            TextField("", text: $item.bastidor)
                                .frame(width: 80)
                            TextField("", text: $item.itemDate)
                                .frame(width: 60)
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
                            .frame(width: 30)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    Button("Añadir línea") {
                        let newItem = BudgetItem(
                            id: nil,
                            concept: "",
                            model: "",
                            bastidor: "",
                            itemDate: "",
                            amount: 0.0
                        )
                        items.append(newItem)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 150, maxHeight: 250)
            .border(Color.gray)
            
            // Impuestos
            VStack(alignment: .leading) {
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
            
            // Totales
            VStack(alignment: .leading) {
                Text(String(format: "Base: %.2f €", baseImponible))
                Text(String(format: "IVA: %.2f €", totalIVA))
                Text(String(format: "IRPF: %.2f €", totalIRPF))
                Text(String(format: "TOTAL: %.2f €", totalBudget))
                    .fontWeight(.bold)
            }
            .padding(.top, 4)
            
            // Botón Guardar
            HStack {
                Spacer()
                Button("Guardar") {
                    saveBudget()
                }
            }
        }
        .padding()
        .onAppear {
            print("DEBUG CreateBudgetView onAppear - Empezamos setupView()")
            setupView()
            loadColumnLabels()
        }
        .onChange(of: items) { _ in recalcTotals() }
        .onChange(of: ivaPercentage) { _ in recalcTotals() }
        .onChange(of: irpfPercentage) { _ in recalcTotals() }

        // Sheet para editar columnas
        .sheet(isPresented: $showColumnsSettings, onDismiss: loadColumnLabels) {
            ItemColumnsSettingsView()
                .environmentObject(dbManager)
        }
    }
    
    private func setupView() {
        if let b = budgetToEdit {
            budgetNumber   = b.budgetNumber
            budgetDate     = b.budgetDate
            issuerId       = b.issuerId == 0 ? nil : b.issuerId
            clientId       = b.clientId == 0 ? nil : b.clientId
            observaciones  = b.observaciones
            items          = b.items
            ivaPercentage  = b.ivaPercentage
            irpfPercentage = b.irpfPercentage
            baseImponible  = b.baseImponible
            totalIVA       = b.totalIVA
            totalIRPF      = b.totalIRPF
            totalBudget    = b.totalBudget
        } else {
            let df = DateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            budgetDate = df.string(from: Date())
        }
        recalcTotals()
    }
    
    private func loadColumnLabels() {
        let c1 = dbManager.getSettingValue(forKey: "column_concept_label")
        labelConcept  = c1.isEmpty ? "Concepto" : c1

        let c2 = dbManager.getSettingValue(forKey: "column_model_label")
        labelModel    = c2.isEmpty ? "Modelo" : c2

        let c3 = dbManager.getSettingValue(forKey: "column_bastidor_label")
        labelBastidor = c3.isEmpty ? "Bastidor" : c3

        let c4 = dbManager.getSettingValue(forKey: "column_date_label")
        labelDate     = c4.isEmpty ? "Fecha" : c4

        let c5 = dbManager.getSettingValue(forKey: "column_amount_label")
        labelAmount   = c5.isEmpty ? "Importe" : c5
    }
    
    private func removeItem(_ target: BudgetItem) {
        if let idx = items.firstIndex(where: { $0.id == target.id }) {
            items.remove(at: idx)
            recalcTotals()
        }
    }
    
    private func recalcTotals() {
        let base = items.reduce(0.0) { $0 + $1.amount }
        baseImponible = base
        
        let iva = base * (ivaPercentage / 100.0)
        totalIVA = iva
        
        let irpf = base * (irpfPercentage / 100.0)
        totalIRPF = irpf
        
        totalBudget = base + iva - irpf
    }
    
    private func saveBudget() {
        recalcTotals()
        let b = Budget(
            id: budgetToEdit?.id,
            budgetNumber: budgetNumber,
            budgetDate: budgetDate,
            issuerId: issuerId ?? 0,
            clientId: clientId ?? 0,
            observaciones: observaciones,
            items: items,
            ivaPercentage: ivaPercentage,
            irpfPercentage: irpfPercentage,
            baseImponible: baseImponible,
            totalIVA: totalIVA,
            totalIRPF: totalIRPF,
            totalBudget: totalBudget
        )
        if budgetToEdit == nil {
            dbManager.insertBudget(b)
        } else {
            dbManager.updateBudget(b)
        }
        dismiss()
    }
}
