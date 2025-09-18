//
//  EventCardView.swift
//  LSE Now
//
//  Created by Pietro Canovari on 9/17/25.
//


import SwiftUI

struct EventCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color("LSERed").opacity(0.2))
                .frame(height: 100)
                .overlay(
                    Text("📅")
                        .font(.largeTitle)
                )
            
            Text(post.title)
                .font(.headline)

            Text(post.startTime, style: .date)   // <-- use this instead of post.date
                .font(.subheadline)
                .foregroundColor(.secondary)

        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}
