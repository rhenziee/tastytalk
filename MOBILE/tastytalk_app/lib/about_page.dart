import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  final String language;
  const AboutPage({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          language == 'en-US' ? 'About TastyTalk' : 'Tungkol sa TastyTalk'
        ),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Sources Section
            Text(
              language == 'en-US' ? 'Recipe Sources' : 'Mga Pinagkunan ng Resipe',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US'
                ? 'The recipes featured in TastyTalk are sourced from Panlasang Pinoy, a trusted platform for authentic Filipino cuisine. We extend our sincerest appreciation for their valuable contribution to the Filipino culinary community.'
                : 'Ang mga resipeng tampok sa TastyTalk ay nagmula sa Panlasang Pinoy, isang pinagkakatiwalaang platform para sa tunay na lutong Pilipino. Nagpapasalamat kami sa kanilang mahalagang kontribusyon sa komunidad ng lutong Pilipino.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US' ? 'Credit:' : 'Kredito:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              language == 'en-US'
                ? 'All recipes provided in this app are derived from Panlasang Pinoy. We do not claim ownership of these recipes and credit all rights to Panlasang Pinoy.'
                : 'Lahat ng resipeng ibinigay sa app na ito ay nagmula sa Panlasang Pinoy. Hindi namin inangkin ang pagmamay-ari ng mga resipeng ito at kinikilala namin ang lahat ng karapatan ng Panlasang Pinoy.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Copyright Information Section
            const Text(
              'Copyright Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '© 2025 TastyTalk. All rights reserved.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'The recipes in this app are provided for personal, non-commercial use only. Any unauthorized reproduction, distribution, or use of these recipes outside of this app is prohibited without the explicit permission of Panlasang Pinoy.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Contact Information Section
            Text(
              language == 'en-US' ? 'Contact Information' : 'Impormasyon sa Pakikipag-ugnayan',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US'
                ? 'For any inquiries, feedback, or support, feel free to reach out to us:'
                : 'Para sa anumang katanungan, feedback, o suporta, huwag mag-atubiling makipag-ugnayan sa amin:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 5),
            const Text(
              'Email: mytastytalkapp@gmail.com',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Follow Panlasang Pinoy Section
            Text(
              language == 'en-US' ? 'Follow Panlasang Pinoy' : 'Sundan ang Panlasang Pinoy',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US'
                ? 'To explore more amazing Filipino recipes and culinary tips, visit Panlasang Pinoy or connect with them on social media:'
                : 'Upang tuklasin ang higit pang kahanga-hangang mga resipeng Pilipino at mga tip sa pagluluto, bisitahin ang Panlasang Pinoy o makipag-ugnayan sa kanila sa social media:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            
            // Social Media Links
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• Facebook: https://www.facebook.com/PanlasangPinoy',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• Instagram: https://www.instagram.com/panlasangpinoy/',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• Twitter: https://twitter.com/PanlasangPinoy',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Disclaimer Section
            Text(
              language == 'en-US' ? 'Disclaimer' : 'Disclaimer',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US'
                ? 'While we strive to provide accurate and up-to-date recipes, please note that the instructions and ingredients are for informational purposes only. The recipes are sourced from Panlasang Pinoy, and we do not claim ownership of the content.'
                : 'Habang nagsusumikap kaming magbigay ng tumpak at napapanahong mga resipe, pakitandaan na ang mga tagubilin at sangkap ay para lamang sa layuning pang-impormasyon. Ang mga resipe ay nagmula sa Panlasang Pinoy, at hindi namin inangkin ang pagmamay-ari ng nilalaman.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}