class OnboardingData {
  final String title;
  final String description;
  final String icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

final onboardingList = [
  OnboardingData(
    title: 'Welcome to Sincerelysea',
    description: 'A calm space to connect and grow together.',
    icon: 'assets/splash/logo-dark.png',
  ),
  OnboardingData(
    title: 'Discover Benefits',
    description: 'Comunity, stories, and meaningful connections.',
    icon: 'assets/splash/logo-dark.png',
  ),
  OnboardingData(
    title: 'Get Started',
    description: 'Login or register to continue.',
    icon: 'assets/splash/logo-dark.png',
  ),
];
