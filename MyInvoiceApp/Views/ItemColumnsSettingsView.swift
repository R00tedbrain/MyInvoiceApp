import SwiftUI

struct ItemColumnsSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var labelConcept:  String = ""
    @State private var labelModel:    String = ""
    @State private var labelBastidor: String = ""
    @State private var labelDate:     String = ""
    @State private var labelAmount:   String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Personalizar Columnas").font(.title2)
            
            TextField("Etiqueta para 'Concepto'", text: $labelConcept)
            TextField("Etiqueta para 'Modelo'", text: $labelModel)
            TextField("Etiqueta para 'Bastidor'", text: $labelBastidor)
            TextField("Etiqueta para 'Fecha'", text: $labelDate)
            TextField("Etiqueta para 'Importe'", text: $labelAmount)
            
            HStack {
                Spacer()
                Button("Guardar") {
                    print("DEBUG: Guardando => [\(labelConcept), \(labelModel), \(labelBastidor), \(labelDate), \(labelAmount)]")
                    
                    dbManager.setSettingValue(labelConcept,  forKey: "column_concept_label")
                    dbManager.setSettingValue(labelModel,    forKey: "column_model_label")
                    dbManager.setSettingValue(labelBastidor, forKey: "column_bastidor_label")
                    dbManager.setSettingValue(labelDate,     forKey: "column_date_label")
                    dbManager.setSettingValue(labelAmount,   forKey: "column_amount_label")
                    
                    dismiss()
                }
                Button("Cancelar") {
                    dismiss()
                }
            }
        }
        .padding()
        .onAppear {
            // Cargar valor actual
            labelConcept  = dbManager.getSettingValue(forKey: "column_concept_label")
            labelModel    = dbManager.getSettingValue(forKey: "column_model_label")
            labelBastidor = dbManager.getSettingValue(forKey: "column_bastidor_label")
            labelDate     = dbManager.getSettingValue(forKey: "column_date_label")
            labelAmount   = dbManager.getSettingValue(forKey: "column_amount_label")
            
            print("DEBUG onAppear -> [\(labelConcept), \(labelModel), \(labelBastidor), \(labelDate), \(labelAmount)]")
        }
    }
}
