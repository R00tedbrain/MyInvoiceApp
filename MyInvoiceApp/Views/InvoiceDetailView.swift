import SwiftUI
import AppKit

struct InvoiceDetailView: View {
    let invoice: Invoice
    
    // Para acceder a la ruta custom del logo
    @EnvironmentObject var dbManager: DatabaseManager

    var body: some View {
        ScrollView { // Se agrega un ScrollView para permitir el desplazamiento vertical
            VStack(alignment: .leading, spacing: 8) {
                
                // ENCABEZADO
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
                
                Divider()
                
                Text("Detalle de Factura")
                    .font(.title3)
                    .padding(.vertical, 4)
                
                // CABECERA DE TABLA
                HStack(alignment: .top) {
                    Text("Concepto").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("Modelo").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("Bastidor").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("Fecha").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("Importe").bold().frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                Divider()
                
                // FILAS DE ITEMS
                ForEach(invoice.items, id: \.localUUID) { item in
                    HStack(alignment: .top) {
                        Text(item.concept)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(item.model)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(item.bastidor)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(item.date)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(String(format: "%.2f", item.amount))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                
                // OBSERVACIONES
                if !invoice.observaciones.isEmpty {
                    Divider()
                    Text("Observaciones:").font(.headline).padding(.top, 6)
                    Text(invoice.observaciones)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }
                
                Divider()
                
                // Logo: custom path o etm.png
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
                        Text("[No se encontró etm.png en el main bundle]")
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    }
                }
                
                // TOTALES
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
            .padding()
            .background(Color.white)
            .environment(\.colorScheme, .light)
        }
    }
}

// -----------------------------------------------------
// Definición de ImageViewRepresentable
// -----------------------------------------------------
struct ImageViewRepresentable: NSViewRepresentable {
    let nsImage: NSImage
    let width:  CGFloat
    let height: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = nsImage
        
        container.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: width),
            imageView.heightAnchor.constraint(equalToConstant: height),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            
            container.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            container.trailingAnchor.constraint(greaterThanOrEqualTo: imageView.trailingAnchor)
        ])
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // no-op
    }
}
