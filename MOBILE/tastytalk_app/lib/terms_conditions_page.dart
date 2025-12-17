import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  final String language;
  const TermsConditionsPage({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          language == 'en-US' ? 'Terms and Conditions' : 'Mga Tuntunin at Kondisyon',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFF3642B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language == 'en-US' 
                ? 'Terms and Conditions for TastyTalk'
                : 'Mga Tuntunin at Kondisyon para sa TastyTalk',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF3642B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              language == 'en-US' 
                ? 'Effective Date: January 2025'
                : 'Petsa ng Pagkakapatupad: Enero 2025',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 15),
            Text(
              language == 'en-US'
                ? 'Welcome to TastyTalk! These Terms and Conditions govern your use of the TastyTalk mobile application and its related services. By accessing or using the App, you agree to comply with these Terms and all applicable laws. If you do not agree with any part of these Terms, do not use the App.'
                : 'Maligayang pagdating sa TastyTalk! Ang mga Tuntunin at Kondisyon na ito ay namamahala sa inyong paggamit ng TastyTalk mobile application at mga kaugnay na serbisyo. Sa pag-access o paggamit ng App, sumasang-ayon kayo na sumunod sa mga Tuntuning ito at lahat ng naaangkop na batas.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),

            _buildSection(
              language == 'en-US' ? '1. User Eligibility' : '1. Karapat-dapat na User',
              language == 'en-US'
                ? 'To use the TastyTalk app, you must be at least 13 years old, or you must have the consent of a parent or guardian if you are under that age. By using this App, you represent and warrant that you are eligible to use it.'
                : 'Upang magamit ang TastyTalk app, dapat kayong hindi bababa sa 13 taong gulang, o dapat kayong may pahintulot ng magulang o tagapag-alaga kung nasa ilalim kayo ng edad na iyon.',
            ),

            _buildSection(
              language == 'en-US' ? '2. Account Registration' : '2. Pagpaparehistro ng Account',
              language == 'en-US'
                ? 'In order to use certain features of the App, you may be required to create an account. You agree to provide accurate and complete information during registration and to update your information if it changes.'
                : 'Upang magamit ang ilang features ng App, maaaring kailanganin ninyong gumawa ng account. Sumasang-ayon kayong magbigay ng tumpak at kumpletong impormasyon sa panahon ng pagpaparehistro.',
            ),

            _buildSection(
              language == 'en-US' ? '3. Intellectual Property' : '3. Intellectual Property',
              language == 'en-US'
                ? 'TastyTalk and all its content, including text, images, logos, and software, are the property of TastyTalk or its licensors and are protected by intellectual property laws.'
                : 'Ang TastyTalk at lahat ng nilalaman nito, kasama ang teksto, larawan, logo, at software, ay pag-aari ng TastyTalk o ng mga lisensyado nito at protektado ng mga batas sa intellectual property.',
            ),

            _buildSection(
              '4. Recipe Sources',
              'The recipes available in TastyTalk are sourced from publicly available content on the internet, including Panlasang Pinoy, a well-known platform for authentic Filipino cuisine. While we strive to provide accurate and reliable information, we do not own the rights to these recipes.\n\nCredit:\nAll recipes provided in this app are derived from various internet sources, including Panlasang Pinoy. We credit Panlasang Pinoy and other sources where applicable, and all rights to the original recipes are retained by their respective creators.',
            ),

            _buildSection(
              '5. Acceptable Use',
              'You agree not to:\n• Use the App for any illegal or unauthorized purpose.\n• Post, transmit, or otherwise make available content that violates the rights of others or is offensive, harmful, or inappropriate.\n• Attempt to disrupt or interfere with the operation of the App, its services, or its servers.',
            ),

            _buildSection(
              '6. Privacy Policy',
              'Your use of TastyTalk is also governed by our Privacy Policy, which explains how we collect, use, and protect your personal information. By using the App, you consent to the practices described in our Privacy Policy.',
            ),

            _buildSection(
              '7. Third-Party Content',
              'The App may include links to third-party websites or content. These links are provided for your convenience, but we are not responsible for the content, accuracy, or practices of these third-party websites. You access them at your own risk. We encourage users to review the terms and conditions and privacy policies of any third-party sites before using them.',
            ),

            _buildSection(
              '8. Disclaimers and Limitations of Liability',
              'The App is provided "as is," and we make no representations or warranties of any kind, express or implied, regarding the availability, accuracy, or reliability of the App. To the fullest extent permitted by law, we disclaim all warranties, including implied warranties of merchantability and fitness for a particular purpose.\n\nWe are not liable for any indirect, incidental, special, or consequential damages arising out of your use of the App.',
            ),

            _buildSection(
              '9. Termination of Account',
              'We reserve the right to suspend or terminate your account at our discretion, without notice, if you violate these Terms or engage in any conduct that we deem inappropriate.',
            ),

            _buildSection(
              '10. Changes to the Terms and Conditions',
              'We may update or modify these Terms at any time. Any changes will be posted in this document with an updated effective date. By continuing to use the App after such changes, you agree to the revised Terms.',
            ),

            _buildSection(
              '11. Governing Law',
              'These Terms are governed by and construed in accordance with the laws of the Philippines, without regard to its conflict of law principles.',
            ),

            _buildSection(
              language == 'en-US' ? '12. Contact Us' : '12. Makipag-ugnayan sa Amin',
              language == 'en-US'
                ? 'If you have any questions or concerns about these Terms, please contact us at:\nEmail: mytastytalkapp@gmail.com'
                : 'Kung mayroon kayong mga tanong o alalahanin tungkol sa mga Tuntuning ito, mangyaring makipag-ugnayan sa amin sa:\nEmail: mytastytalkapp@gmail.com',
            ),

            _buildSection(
              '13. Acknowledgement',
              'By using the TastyTalk App, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF3642B),
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 16),
      ],
    );
  }
}
