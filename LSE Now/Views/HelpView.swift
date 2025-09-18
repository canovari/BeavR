import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How to Post on BeavR")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 8)
                
                Group {
                    Text("📌 Step 1: Open the New Event tab")
                        .font(.headline)
                    Text("Go to the **New Event** tab in the bottom bar. This is where you’ll find the option to share an event.")
                    
                    Text("📝 Step 2: Tap 'Add Event'")
                        .font(.headline)
                    Text("Press the **Add Event** button to open the form for creating a new post.")
                    
                    Text("📍 Step 3: Drop a Pin on the Map")
                        .font(.headline)
                    Text("Select the event location on the map. This helps others find where the event is happening.")
                    
                    Text("🎭 Step 4: Fill in the Event Details")
                        .font(.headline)
                    Text("Add a title, date, time, and location. You can also include the host, a description, and a category to make the event stand out.")
                    
                    Text("📞 Step 5: Add Contact Info")
                        .font(.headline)
                    Text("Choose how people can reach you (Email, WhatsApp, Instagram, etc).")
                    
                    Text("🚀 Step 6: Send for Review")
                        .font(.headline)
                    Text("When you hit **Send**, your event will be reviewed by the admins. If approved, it will appear in the Feed and on the Map.")
                }
                .padding(.horizontal)
                
                Divider().padding(.vertical)
                
                Text("💡 Tips")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 12) {
                    Text("✔️ Use clear, short titles.")
                    Text("✔️ Add a description that answers *what, when, where, and why.*")
                    Text("✔️ Double-check your contact info so people can reach you.")
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}
