import SwiftUI
import AppKit

/// Vista "paginada" que divide los items en bloques de 25
/// y así no corta filas entre páginas.
struct PagedInvoiceDetailView: View {
    let invoice: Invoice
    
    // Ajusta cuántas filas por página quieras
    let maxRowsPerPage = 25

    // Para ejemplo, cada fila la dibujaremos con un alto fijo ~ 24-30
    let rowHeight: CGFloat = 30

    // NUEVO: para acceder a la ruta del logo
    @EnvironmentObject var dbManager: DatabaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // CABECERA (emisor / cliente)
            headerView

            Divider()
            Text("Detalle de Factura")
                .font(.title3)
            
            // Dividimos items en bloques
            let pages = buildPages(from: invoice.items, maxRows: maxRowsPerPage)
            
            // Dibujamos cada "página" (bloque)
            ForEach(pages.indices, id: \.self) { pageIndex in
                VStack(alignment: .leading, spacing: 0) {
                    // Cabecera de tabla
                    tableHeader()

                    // Filas de esta "página"
                    ForEach(pages[pageIndex], id: \.localUUID) { item in
                        rowView(item)
                            .frame(height: rowHeight)
                    }
                }
                .padding(.vertical, 8)
                .border(Color.black.opacity(0.2), width: 1)
                .padding(.bottom, 20) // espaciado entre páginas
            }

            // Observaciones
            if !invoice.observaciones.isEmpty {
                Divider()
                Text("Observaciones:").font(.headline)
                Text(invoice.observaciones)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // AQUÍ cambiamos para cargar logo personalizado o etm.png
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
                // Si no hay ruta => usar etm.png por defecto
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

            // TOTALES
            totalsView
        }
        .padding()
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // -------------- Vistas Auxiliares --------------
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.issuerName).font(.headline)
                Text(invoice.issuerAddress)
                Text("NIF: \(invoice.issuerNIF)")
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Factura N.º \(invoice.invoiceNumber)").font(.headline)
                Text("Fecha: \(invoice.invoiceDate)")
                Text("Cliente: \(invoice.clientName)")
                Text(invoice.clientAddress)
                Text("NIF/CIF: \(invoice.clientNIF)")
            }
        }
    }

    private func tableHeader() -> some View {
        HStack {
            Text("Concepto").bold().frame(width: 100, alignment: .leading)
            Text("Modelo").bold().frame(width: 100, alignment: .leading)
            Text("Bastidor").bold().frame(width: 100, alignment: .leading)
            Text("Fecha").bold().frame(width: 80, alignment: .leading)
            Text("Importe").bold().frame(width: 80, alignment: .trailing)
        }
        .padding(.bottom, 4)
    }

    private func rowView(_ item: InvoiceItem) -> some View {
        HStack {
            Text(item.concept)
                .frame(width: 100, alignment: .leading)
            Text(item.model)
                .frame(width: 100, alignment: .leading)
            Text(item.bastidor)
                .frame(width: 100, alignment: .leading)
            Text(item.date)
                .frame(width: 80, alignment: .leading)
            Text(String(format: "%.2f", item.amount))
                .frame(width: 80, alignment: .trailing)
        }
    }

    private var totalsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Base Imponible:")
                Spacer()
                Text(String(format: "%.2f €", invoice.baseImponible))
            }
            HStack {
                Text("IVA (\(invoice.ivaPercentage, specifier: "%.2f")%)")
                Spacer()
                Text(String(format: "%.2f €", invoice.totalIVA))
            }
            HStack {
                Text("IRPF (\(invoice.irpfPercentage, specifier: "%.2f")%)")
                Spacer()
                Text(String(format: "%.2f €", invoice.totalIRPF))
            }
            HStack {
                Text("Total Factura:").fontWeight(.bold)
                Spacer()
                Text(String(format: "%.2f €", invoice.totalFactura))
                    .fontWeight(.bold)
            }
        }
        .padding(.top, 6)
    }

    // -------------- Partir items en bloques --------------
    private func buildPages(from items: [InvoiceItem],
                            maxRows: Int) -> [[InvoiceItem]] {
        var result: [[InvoiceItem]] = []
        var startIndex = 0
        while startIndex < items.count {
            let endIndex = min(startIndex + maxRows, items.count)
            let slice = Array(items[startIndex..<endIndex])
            result.append(slice)
            startIndex += maxRows
        }
        return result
    }
}
