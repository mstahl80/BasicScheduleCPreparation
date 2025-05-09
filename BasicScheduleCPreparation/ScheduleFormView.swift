// ScheduleFormView.swift
import SwiftUI

struct ScheduleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    
    // Simple state variables
    @State private var date = Date()
    @State private var amount = Decimal(0)
    @State private var store = ""
    @State private var selectedCategory = ""
    @State private var notes = ""
    @State private var photoURL: String? = nil
    
    // Non-state properties
    let userId: String
    let editingItem: Schedule?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Store Name", text: $store)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Text("$")
                        TextField("Amount", value: $amount, format: .currency(code: "USD"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Text("Category")
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ScheduleViewModel.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text("Notes")
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))
                    
                    Text("Receipt")
                    PhotoPicker(selectedPhotoURL: $photoURL)
                }
                .padding()
            }
            .navigationTitle(editingItem == nil ? "New Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveForm()
                    }
                    .disabled(store.isEmpty)
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        if let item = editingItem {
            date = item.date ?? Date()
            amount = item.amount?.decimalValue ?? Decimal(0)
            store = item.store ?? ""
            selectedCategory = item.category ?? ScheduleViewModel.categories.first ?? ""
            notes = item.notes ?? ""
            photoURL = item.photoURL
        } else {
            selectedCategory = ScheduleViewModel.categories.first ?? ""
        }
    }
    
    private func saveForm() {
        if let item = editingItem {
            viewModel.updateScheduleItem(
                item,
                date: date,
                amount: amount,
                store: store,
                category: selectedCategory,
                notes: notes.isEmpty ? nil : notes,
                photoURL: photoURL,
                userId: userId
            )
        } else {
            viewModel.addScheduleItem(
                date: date,
                amount: amount,
                store: store,
                category: selectedCategory,
                notes: notes.isEmpty ? nil : notes,
                photoURL: photoURL,
                userId: userId
            )
        }
        dismiss()
    }
}
