import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_model.dart';
import 'menu_content.dart';
import 'user_menupage.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<RecipeModel> allRecipes = [];
  List<RecipeModel> filteredRecipes = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchRecipes();
  }

  Future<void> fetchRecipes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('dishes').get();

    final recipes =
        snapshot.docs
            .where((doc) {
              final data = doc.data();
              // Include dish if 'isArchive' is false or does not exist
              return data['archived'] != true;
            })
            .map((doc) => RecipeModel.fromMap(doc.data()))
            .toList();

    setState(() {
      allRecipes = recipes;
      filteredRecipes = recipes;
    });
  }

  void filterRecipes(String query) {
    final results =
        allRecipes.where((recipe) {
          final title = recipe.title.toLowerCase();
          final input = query.toLowerCase();
          return title.contains(input);
        }).toList();

    setState(() => filteredRecipes = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top AppBar section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserMenuPage(),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: filterRecipes,
                          decoration: InputDecoration(
                            hintText: 'Search here',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.search),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    // const Text(
                    //   "Categories",
                    //   style: TextStyle(
                    //     fontSize: 18,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    // const SizedBox(height: 10),
                    // SizedBox(
                    //   height: 50,
                    //   child: ListView(
                    //     scrollDirection: Axis.horizontal,
                    //     children: const [
                    //       CategoryPill(label: "Beef", imageUrl: 'beef.jpg'),
                    //       CategoryPill(label: "Pork", imageUrl: 'pork.jpg'),
                    //       CategoryPill(
                    //         label: "Chicken",
                    //         imageUrl: 'chicken.jpg',
                    //       ),
                    //       CategoryPill(label: "Fish", imageUrl: 'fish.jpg'),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 20),
                    const Text(
                      "Popular Recipes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Recipe list based on search
                    if (filteredRecipes.isEmpty)
                      const Text('No recipes available.')
                    else
                      Column(
                        children:
                            filteredRecipes.map((dish) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => MenuContentPage(
                                            title: dish.title,
                                            imageUrl: dish.image,
                                            ingredients: dish.ingredients,
                                            procedures: dish.procedures,
                                            duration: dish.duration,
                                          ),
                                    ),
                                  );
                                },
                                child: RecipeCard(
                                  image: dish.image,
                                  title: dish.title,
                                  duration: dish.duration,
                                  rating: dish.rating,
                                ),
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  final String label;
  final String imageUrl;

  const CategoryPill({super.key, required this.label, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: AssetImage(
            'assets/$imageUrl',
          ), // Make sure to include in pubspec.yaml
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  final String image;
  final String title;
  final String duration;
  final double rating;

  const RecipeCard({
    super.key,
    required this.image,
    required this.title,
    required this.duration,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              image,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 5),
                    Text(rating.toStringAsFixed(1)),
                  ],
                ),

                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 5),
                    Text(duration),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
