import SwiftUI

struct PagedBudgetDetailView: View {
    let budget: Budget
    
    @EnvironmentObject var dbManager: DatabaseManager  // para buscar issuer & client + ruta del logo
    
    // MAX filas
    let maxRowsPerPage = 25
    
    // Column labels (por defecto)
    @State private var labelConcept  = "Concepto"
    @State private var labelModel    = "Modelo"
    @State private var labelBastidor = "Bastidor"
    @State private var labelDate     = "Fecha"
    @State private var labelAmount   = "Importe"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            Divider()
            Text("Detalle del Presupuesto")
                .font(.title3)
            
            // Dividir items en páginas
            let pages = buildPages(from: budget.items, maxRows: maxRowsPerPage)
            
            ForEach(pages.indices, id: \.self) { pageIndex in
                VStack(alignment: .leading, spacing: 0) {
                    tableHeader()  // ← Usa labels personalizados
                    ForEach(pages[pageIndex], id: \.id) { item in
                        rowView(item)
                            .frame(height: 24)
                    }
                }
                .padding(.vertical, 6)
                .border(Color.black.opacity(0.2), width: 1)
                .padding(.bottom, 20)
            }
            
            if !budget.observaciones.isEmpty {
                Divider()
                Text("Observaciones:").font(.headline)
                Text(budget.observaciones)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // Mismo sistema: logo custom o etm.png
            let customLogoPath = dbManager.getSettingValue(forKey: "custom_logo_path")
            if !customLogoPath.isEmpty {
                let fileURL = URL(fileURLWithPath: customLogoPath)
                if let nsimg = NSImage(contentsOf: fileURL) {
                    ImageViewRepresentable(nsImage: nsimg, width: 200, height: 80)
                        .padding(.vertical, 8)
                } else {
                    Text("[No se pudo cargar el logo personalizado]")
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
            } else {
                if let url = Bundle.main.url(forResource: "etm", withExtension: "png"),
                   let nsimg = NSImage(contentsOf: url) {
                    ImageViewRepresentable(nsImage: nsimg, width: 200, height: 80)
                        .padding(.vertical, 8)
                } else {
                    Text("[No se encontró etm.png en el bundle]")
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
            }
            
            totalsView
        }
        .padding()
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .onAppear {
            loadColumnLabels()
        }
    }
    
    // Cargar labels de DB
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
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bloque 1: Emisor y Cliente
            HStack(alignment: .top) {
                // Emisor
                VStack(alignment: .leading, spacing: 2) {
                    if let issuer = dbManager.fetchAllIssuers().first(where: { $0.id == budget.issuerId }) {
                        Text(issuer.name).font(.headline)
                        Text(issuer.address)
                        Text("NIF: \(issuer.nif)")
                        if !issuer.phone.isEmpty {
                            Text("Tel: \(issuer.phone)")
                        }
                    } else {
                        Text("(Sin Emisor seleccionado)")
                            .font(.subheadline)
                    }
                }
                Spacer()
                
                // Cliente
                VStack(alignment: .trailing, spacing: 2) {
                    if let client = dbManager.clients.first(where: { $0.id == budget.clientId }) {
                        Text("Cliente: \(client.name)").font(.headline)
                        Text(client.address)
                        Text("NIF/CIF: \(client.nif)")
                        if !client.nick.isEmpty {
                            Text("(Nick: \(client.nick))")
                        }
                    } else {
                        Text("(Sin Cliente seleccionado)")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.bottom, 6)
            
            // Bloque 2: Título y fecha del presupuesto
            VStack(alignment: .leading) {
                Text("Presupuesto N.º \(budget.budgetNumber)")
                    .font(.headline)
                Text("Fecha: \(budget.budgetDate)")
            }
        }
    }
    
    private func tableHeader() -> some View {
        HStack {
            Text(labelConcept).bold().frame(width: 100, alignment: .leading)
            Text(labelModel).bold().frame(width: 80, alignment: .leading)
            Text(labelBastidor).bold().frame(width: 80, alignment: .leading)
            Text(labelDate).bold().frame(width: 80, alignment: .leading)
            Text(labelAmount).bold().frame(width: 80, alignment: .trailing)
        }
        .padding(.bottom, 2)
    }
    
    private func rowView(_ item: BudgetItem) -> some View {
        HStack {
            Text(item.concept).frame(width: 100, alignment: .leading)
            Text(item.model).frame(width: 80, alignment: .leading)
            Text(item.bastidor).frame(width: 80, alignment: .leading)
            Text(item.itemDate).frame(width: 80, alignment: .leading)
            Text(String(format: "%.2f", item.amount)).frame(width: 80, alignment: .trailing)
        }
    }
    
    private var totalsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "Base: %.2f €", budget.baseImponible))
            Text(String(format: "IVA: %.2f €", budget.totalIVA))
            Text(String(format: "IRPF: %.2f €", budget.totalIRPF))
            Text(String(format: "TOTAL: %.2f €", budget.totalBudget))
                .fontWeight(.bold)
        }
        .padding(.top, 6)
    }
    
    // Partir items en páginas
    private func buildPages(from items: [BudgetItem], maxRows: Int) -> [[BudgetItem]] {
        var result: [[BudgetItem]] = []
        var startIndex = 0
        while startIndex < items.count {
            let endIndex = min(startIndex + maxRows, items.count)
            let slice = Array(items[startIndex..<endIndex])
            result.append(slice)
            startIndex += maxRows
        }
        if items.isEmpty {
            result = [[]]
        }
        return result
    }
}
