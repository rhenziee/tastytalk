import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Error loading notifications');
          }
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          // Count read and unread notifications
          int unreadCount = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isRead'] != true;
          }).length;
          int readCount = docs.length - unreadCount;

          return Column(
            children: [
              // Counter section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
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
              ),
              // Notifications list
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    
                    return ListTile(
                      leading: Icon(
                        isRead ? Icons.notifications : Icons.notifications_active,
                        color: isRead ? Colors.grey : Colors.orange,
                      ),
                      title: Text(
                        data['title'] ?? 'No Title',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
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
                      tileColor: isRead ? null : Colors.blue.withValues(alpha: 0.1),
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
