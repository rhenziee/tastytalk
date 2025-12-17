import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _markAsRead(String docId) async {
    if (currentUserId == null) return;

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({
          'readBy.$currentUserId': true,
          'readAt.$currentUserId': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    if (currentUserId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final readBy = data['readBy'] as Map<String, dynamic>? ?? {};
      
      if (readBy[currentUserId] != true) {
        batch.update(doc.reference, {
          'readBy.$currentUserId': true,
          'readAt.$currentUserId': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
  }

  List<QueryDocumentSnapshot> _removeDuplicates(List<QueryDocumentSnapshot> docs) {
    final seen = <String>{};
    final uniqueDocs = <QueryDocumentSnapshot>[];
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final key = '${data['title']}_${data['message']}_${data['timestamp']}';
      
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueDocs.add(doc);
      }
    }
    
    return uniqueDocs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            currentUserId == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Error loading notifications');
          }
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final allDocs = snapshot.data!.docs;
          final docs = _removeDuplicates(allDocs);

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          // Count read and unread notifications for current user
          int unreadCount =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final readBy = data['readBy'] as Map<String, dynamic>? ?? {};
                return readBy[currentUserId] != true;
              }).length;
          int readCount = docs.length - unreadCount;

          return Column(
            children: [
              // Counter and Mark All section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$unreadCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Text('Unread'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '$readCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text('Read'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${docs.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text('Total'),
                          ],
                        ),
                      ],
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _markAllAsRead(docs),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Mark All as Read ($unreadCount)'),
                      ),
                    ],
                  ],
                ),
              ),
              // Notifications list
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final readBy =
                        data['readBy'] as Map<String, dynamic>? ?? {};
                    final isRead = readBy[currentUserId] == true;

                    return ListTile(
                      leading: Icon(
                        isRead
                            ? Icons.notifications
                            : Icons.notifications_active,
                        color: isRead ? Colors.grey : Colors.orange,
                      ),
                      title: Text(
                        data['title'] ?? 'No Title',
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(data['message'] ?? ''),
                      trailing: Text(
                        (data['timestamp'] as Timestamp)
                            .toDate()
                            .toLocal()
                            .toString()
                            .split('.')[0],
                        style: const TextStyle(fontSize: 12),
                      ),
                      tileColor:
                          isRead ? null : Colors.blue.withValues(alpha: 0.1),
                      onTap: isRead ? null : () => _markAsRead(doc.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
