import SwiftUI

struct PostListView: View {
    @ObservedObject var vm: PostListViewModel
    
    var body: some View {
        NavigationView {
            List(vm.posts) { post in
                NavigationLink(destination: PostDetailView(post: post)) {
                    PostRowView(post: post)
                }
            }
            .navigationTitle("Events")
            .onAppear {
                vm.fetchPosts()   // ✅ renamed from loadPosts
            }
        }
    }
}
