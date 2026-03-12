class RestTipQuote{
  final String description;
  final String? author;

  RestTipQuote({
    required this.description,
    this.author,
  });
}
//Scotti, A. and Cori Ritchey, C.S.C.S. (2015) 35 fitness quotes to push you through your toughest workouts, Men’s Health. Available at: https://www.menshealth.com/fitness/a19547200/best-fitness-quotes-of-all-time/ (Accessed: March 12, 2026).
//Page, S. (2022) “57 quotes on wellness and health to inspire healthy living,” Totalwellnesshealth.com. TotalWellness, 13 January. Available at: https://info.totalwellnesshealth.com/blog/quotes-on-wellness-and-health (Accessed: March 12, 2026).
final List<RestTipQuote> restTipsQuotes = [
  RestTipQuote(description: '“If you want something you’ve never had, you must be willing to do something you’ve never done.”',
  author: 'Thomas Jefferson'),
  RestTipQuote(description: '“You shall gain, but you shall pay with sweat, blood, and vomit.”', author: 'Pavel Tsatsouline'),
  RestTipQuote(description: '"There is no magic pill"',author: 'Arnold  Schwarzenegger'),
  RestTipQuote(description: '“The last three or four reps is what makes the muscle grow. This area of pain divides the champion from someone else who is not a champion.”'),
  RestTipQuote(description: '“Motivation is what gets you started. Habit is what keeps you going.”',author:'Jim Ryun'),
  RestTipQuote(description: '“Keep working even when no one is watching.”',author: 'Alex Morgan'),
  RestTipQuote(description: '“Don’t be afraid of failure. This is the way to succeed.”', author: 'LeBron James'),
  RestTipQuote(description: '"You have to push past your perceived limits, push past that point you thought was as far as you can go.',author: 'Drew Brees'),
  RestTipQuote(description: '"To keep winning, I have to keep improving."',author: 'Craig Alexander'),
  RestTipQuote(description: '“Some people want it to happen, some wish it would happen, others make it happen.”',author: 'Michael Jordan'),
  RestTipQuote(description: '“No matter how old you are, no matter how much you weigh, you can still control the health of your body.”', author: 'Dr. Harvey Cushing'),
  RestTipQuote(description: '“A calm mind brings inner strength and self-confidence, so that’s very important for good health.”', author: 'Dalai Lama'),
  RestTipQuote(description: '“Early to bed and early to rise makes a man healthy, wealthy, and wise.”',author: 'Benjamin Franklin'),
  RestTipQuote(description: '“Make eating fruits and vegetables a priority. This is so simple and beneficial, yet most people don’t do it.”',author: 'Joan Welsh'),
  RestTipQuote(description: '“Our bodies are our gardens – our wills are our gardeners.”',author: 'William Shakespeare'),
  RestTipQuote(description: '“So many people spend their health gaining wealth, and then have to spend their wealth to regain their health.”',author: 'A.J Reb Materi'),
  RestTipQuote(description: '“It’s not until you get tired that you see how strong you really are.”', author: 'Shaun T'),
  RestTipQuote(description: 'Target ~0.8–1.0g protein per pound of bodyweight/day to help recovery and muscle growth.'),

];