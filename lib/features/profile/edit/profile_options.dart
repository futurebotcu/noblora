// ---------------------------------------------------------------------------
// Master data — all selection options for Edit Profile sections
// ---------------------------------------------------------------------------

class LangOption {
  final String code;
  final String label;
  const LangOption(this.code, this.label);
}

class ProfileOptions {
  ProfileOptions._();

  // ── Zodiac ──
  static const zodiac = [
    'Aries','Taurus','Gemini','Cancer','Leo','Virgo',
    'Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces',
  ];

  // ── Education ──
  static const education = [
    'High school','Associate','Bachelors','Masters','PhD','Self-taught','Other',
  ];

  // ── Languages ──
  static const languages = [
    LangOption('tr', 'Türkçe'), LangOption('en', 'English'),
    LangOption('fr', 'Français'), LangOption('de', 'Deutsch'),
    LangOption('es', 'Español'), LangOption('it', 'Italiano'),
    LangOption('pt', 'Português'), LangOption('ar', 'العربية'),
    LangOption('ru', 'Русский'), LangOption('ja', '日本語'),
    LangOption('zh', '中文'), LangOption('ko', '한국어'),
    LangOption('nl', 'Nederlands'), LangOption('sv', 'Svenska'),
    LangOption('pl', 'Polski'), LangOption('hi', 'हिन्दी'),
    LangOption('th', 'ภาษาไทย'), LangOption('vi', 'Tiếng Việt'),
    LangOption('el', 'Ελληνικά'), LangOption('cs', 'Čeština'),
    LangOption('da', 'Dansk'), LangOption('fi', 'Suomi'),
    LangOption('he', 'עברית'), LangOption('hu', 'Magyar'),
    LangOption('id', 'Bahasa'), LangOption('ro', 'Română'),
    LangOption('uk', 'Українська'), LangOption('fa', 'فارسی'),
  ];

  static const langLevels = ['Native','Fluent','Good','Intermediate','Learning'];

  // ── Countries (subset — expandable) ──
  static const countries = [
    'Afghanistan','Albania','Algeria','Argentina','Armenia','Australia','Austria',
    'Azerbaijan','Bahrain','Bangladesh','Belarus','Belgium','Bolivia','Bosnia',
    'Brazil','Bulgaria','Cambodia','Canada','Chile','China','Colombia','Croatia',
    'Cuba','Cyprus','Czech Republic','Denmark','Ecuador','Egypt','Estonia',
    'Ethiopia','Finland','France','Georgia','Germany','Ghana','Greece','Hungary',
    'Iceland','India','Indonesia','Iran','Iraq','Ireland','Israel','Italy',
    'Jamaica','Japan','Jordan','Kazakhstan','Kenya','Kuwait','Kyrgyzstan',
    'Latvia','Lebanon','Libya','Lithuania','Luxembourg','Malaysia','Maldives',
    'Malta','Mexico','Moldova','Mongolia','Montenegro','Morocco','Myanmar',
    'Nepal','Netherlands','New Zealand','Nigeria','North Macedonia','Norway',
    'Oman','Pakistan','Palestine','Panama','Paraguay','Peru','Philippines',
    'Poland','Portugal','Qatar','Romania','Russia','Saudi Arabia','Senegal',
    'Serbia','Singapore','Slovakia','Slovenia','Somalia','South Africa',
    'South Korea','Spain','Sri Lanka','Sudan','Sweden','Switzerland','Syria',
    'Taiwan','Tanzania','Thailand','Tunisia','Turkey','Turkmenistan','UAE',
    'Uganda','Ukraine','United Kingdom','United States','Uruguay','Uzbekistan',
    'Venezuela','Vietnam','Yemen',
  ];

  // ── Gender ──
  static const genders = ['Male','Female','Non-binary','Other','Prefer not to say'];
  static const interestedIn = ['Men','Women','Everyone','Prefer not to say'];
  static const pronouns = ['He/Him','She/Her','They/Them','Other','Prefer not to say'];

  // ── Religious / Spiritual ──
  static const religiousApproach = [
    'Religious','Spirituality matters','Culturally connected',
    'Exploring','Secular','Agnostic','Atheist','Prefer not to say',
  ];

  // ── Children ──
  static const wantsChildren = [
    'Definitely','With the right person','Not sure','No','Already have kids','Prefer not to say',
  ];

  // ── Pets ──
  static const petsStatus = ['Have pets','No pets','Want pets','Allergic'];
  static const petsPreference = ['Dogs','Cats','Birds','Fish','Reptiles','Other'];

  // ── Smoking / Alcohol / Nightlife ──
  static const smoking = ['Never','Sometimes','Often'];
  static const alcohol = ['Never','Rarely','Socially','Often'];
  static const nightlife = ['Never','Sometimes','Often','Weekends','Varies'];

  // ── Social energy ──
  static const socialEnergy = [
    'Very social','Balanced','Small circles','One-on-one','Introverted','Depends on mood',
  ];

  // ── Personality ──
  static const personalityStyle = ['Introvert','Ambivert','Extrovert'];
  static const organizationStyle = ['Very organized','Organized','Relaxed','Creative chaos','Varies'];

  // ── Relationship: Looking for ──
  static const lookingFor = [
    'Long-term relationship','Serious relationship','Right person, serious',
    'Meet first, see later','Short-term','Friendship','BFF','Expand social circle',
  ];

  // ── Relationship type ──
  static const relationshipType = [
    'Monogamy','Long-term partnership','Slow burn','Life partner focused',
    'Living apart together','Modern but committed','Traditional',
    'Open to non-traditional','Prefer not to say',
  ];

  // ── Dating style ──
  static const datingStyle = [
    'Slow to open up','Direct','Flirtatious','Deep conversations',
    'Fun and playful','Trust first','Friends first',
  ];

  // ── Communication style ──
  static const communicationStyle = [
    'Quick replies','Occasional replies','Long messages','Short and clear',
    'Voice notes','Calls are better','Video calls',
  ];

  // ── First meet ──
  static const firstMeetPreference = [
    'Short video call','Voice call','Coffee','Walk','Dinner',
    'Activity','Gallery / museum','Chat first',
  ];

  // ── Love languages ──
  static const loveLanguages = [
    'Quality time','Physical touch','Words of affirmation',
    'Thoughtful gestures','Acts of service',
  ];

  // ── Interests — categorized ──
  static const interestCategories = {
    'Sports': [
      'Fitness','Running','Yoga','Pilates','Swimming','Tennis','Padel',
      'Boxing','Martial arts','Football','Basketball','Cycling','Hiking',
      'Trekking','Climbing','Dance',
    ],
    'Creative': [
      'Photography','Video','Writing','Journaling','Poetry','Drawing',
      'Painting','Ceramics','Music production','Guitar','Piano','Singing',
      'DJ','Fashion / Styling',
    ],
    'Tech': [
      'AI','Startups','Coding','No-code','Product dev','Design','UX/UI',
      'Robotics','Gadgets','Crypto','Data science',
    ],
    'Intellectual': [
      'Psychology','Philosophy','History','Neuroscience','Economics',
      'Sociology','Personal development','Literature','Mindfulness',
    ],
    'Entertainment': [
      'Cinema','TV series','Anime','Stand-up','Gaming','Board games',
      'Karaoke','Festivals','Concerts','Nightlife',
    ],
    'Wellness': [
      'Meditation','Breathwork','Biohacking','Longevity','Therapy',
      'Self-care',
    ],
    'Food & Drink': [
      'Coffee','Specialty coffee','Tea culture','Cooking','Restaurants',
      'Brunch','Wine','Cocktails','Street food',
    ],
    'Outdoor': [
      'Camping','Road trips','Beach','Island getaway','Nature walks',
      'Digital nomad travel','Workation',
    ],
    'Building': [
      'Side projects','Content creation','Personal brand','Entrepreneurship',
      'E-commerce','Community building','Freelance',
    ],
  };

  // ── Music genres ──
  static const musicGenres = [
    'Techno','House','Jazz','Lo-fi','Hip hop','Pop','Rock','Indie',
    'Classical','Electronic','World music','R&B','Soul','Metal',
    'Turkish rock','Latin','Reggaeton','K-pop',
  ];

  // ── Movie / Series genres ──
  static const movieGenres = [
    'Independent cinema','Mainstream','Documentary','Crime','Sci-fi',
    'Romance','Art house','Anime','Reality','Sitcom','Thriller',
    'Horror','Fantasy','Drama',
  ];

  // ── Weekend style ──
  static const weekendStyle = [
    'Quiet at home','Coffee + walk','Out with friends','Party',
    'Cultural events','Short trip','Productive','Spontaneous',
  ];

  // ── Humor ──
  static const humorStyle = [
    'Dry humor','Absurd','Witty','Sarcastic','Wholesome','Meme culture',
  ];

  // ── Travel style ──
  static const travelStyle = [
    'Backpack','Boutique','Luxury','Local immersion','Spontaneous',
    'Planned','Digital nomad','Workation',
  ];

  // ── Relocation ──
  static const relocationOpenness = [
    'Open to relocate','For the right person','My city only',
    'Could change countries','Not sure',
  ];

  // ── Work style ──
  static const workStyle = [
    'Remote','Hybrid','Office','Freelance','Entrepreneur','Student','Varies',
  ];

  // ── Entrepreneurship ──
  static const entrepreneurshipStatus = [
    'Have my own business','Building a startup','Developing side projects',
    'Thinking about it','No','Exploring',
  ];

  // ── Building now ──
  static const buildingNow = [
    'Startup','App','Content channel','Personal brand','Investment system',
    'Art / project','Community','Book / writing','E-commerce','Still exploring',
  ];

  // ── Work intensity ──
  static const workIntensity = ['Calm','Balanced','Intense','Very intense','Varies by season'];

  // ── AI tools ──
  static const aiTools = [
    'ChatGPT','Claude','Gemini','Perplexity','Copilot','Midjourney',
    'Cursor','Notion AI','Grok','Runway','Suno','ElevenLabs',
    'Replit AI','Leonardo','Stable Diffusion','None',
  ];

  // ── Social media usage ──
  static const socialMediaUsage = [
    'Active creator','Post sometimes','Just watch','Rarely use','Almost none',
  ];

  // ── Online style ──
  static const onlineStyle = [
    'Memes','Reels / TikTok','Voice notes','Long writer','Short & clear',
    'Instant replies','Disappear then return','Selective',
  ];

  // ── Tech relation ──
  static const techRelation = [
    'Early adopter','Balanced user','Work necessity','Love tech','Low-tech life',
  ];

  // ── Sleep style ──
  static const sleepStyle = ['Morning person','Night owl','Both','Varies'];

  // ── Diet ──
  static const dietStyle = [
    'Omnivore','High protein','Vegetarian','Vegan','Pescatarian',
    'Flexible','Health-focused','Foodie',
  ];

  // ── Fitness ──
  static const fitnessRoutine = ['Daily','Regular','Sometimes','Rarely','None'];

  // ── Planning ──
  static const planningStyle = ['Planned','Mostly planned','Spontaneous','Mix of both'];

  // ── Spending ──
  static const spendingStyle = [
    'Planned','Spend on experiences','Simple living','Premium taste','Varies',
  ];

  // ── Fashion ──
  static const fashionStyle = [
    'Minimal','Casual','Streetwear','Elegant','Sporty','Creative','Classic',
  ];

  // ── Prompt questions ──
  static const promptQuestions = [
    'We would get along if...',
    'My free day usually looks like...',
    'Recently I have been obsessed with...',
    'My surprising talent is...',
    'What makes a first date ideal...',
    'The best thing about dating me...',
    'What people get wrong about me...',
    'I use AI mostly for...',
    'What I am building right now...',
    'My guilty pleasure is...',
    'My green flag is...',
    'My red flag is...',
    'My life motto is...',
    'The last thing that made me laugh...',
  ];

  // ── Visibility ──
  static const visibilityOptions = ['Public','Matches only','Private'];
}
