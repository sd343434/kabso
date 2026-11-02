/**
 * D229 «PK أحكام»: the hand-written building blocks of Kabso's dare library (generated for Kabso, 2026-11; nothing
 * copied from other apps or sites). Each line is `Arabic|English|level` (level e / m / h, default e). Arabic is
 * written gender-neutral: verbal nouns («تقليد…», «غناء…») and unvocalized past or possessive forms, never «أنتَ /
 * أنتِ» or a gendered imperative. `generate.ts` composes three lists per template (see there).
 */

export type Tag = 'e' | 'm' | 'h';
export interface Item {
  readonly ar: string;
  readonly en: string;
  readonly tag: Tag;
}

function list(block: string): Item[] {
  return block
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .map((l) => {
      const [ar, en, tag] = l.split('|').map((p) => p.trim());
      if (!ar || !en) throw new Error(`Bad content line: ${l}`);
      return { ar, en, tag: (tag ?? 'e') as Tag };
    });
}

/** Manner, after the action (an Arabic adverbial phrase; the English after a comma). */
export const STYLE = list(`
بصوت هامس|in a whisper|e
بالحركة البطيئة|in slow motion|e
بصوت روبوت|in a robot voice|e
بنعاس شديد|very sleepily|e
بحماس شديد|with huge excitement|e
بابتسامة لا تختفي|with a smile that never fades|e
بصوت عميق جداً|in a very deep voice|e
بصوت رفيع جداً|in a very high voice|e
بسرعة كبيرة|really fast|e
بهدوء تام|completely calmly|e
بوجه جاد جداً|with a very serious face|e
بنبرة رسمية جداً|in a very formal tone|e
مع التصفيق بين الجمل|clapping between sentences|e
بصوت مذيع راديو|like a radio presenter|e
بأسلوب معلق رياضي|like a sports commentator|e
بصوت متعب|in a tired voice|e
بأسلوب أفلام الكرتون|in cartoon style|e
بصوت فرح جداً|in a very cheerful voice|e
بعيون متفاجئة طوال الوقت|with surprised eyes the whole time|e
مع رفع الحاجبين طوال الوقت|with raised eyebrows the whole time|e
بأسلوب برنامج وثائقي|like a nature documentary|e
بصوت فيه صدى|with an echoing voice|e
بحركات يدين كثيرة|with lots of hand movements|e
بأسلوب إعلان تلفزيوني|like a TV advert|e
بصوت راوٍ حكيم|like a wise storyteller|e
بأسلوب مذيع طقس|like a weather presenter|e
بدقة روبوت|with robot precision|e
بأسلوب مقدم مسابقات|like a quiz show host|m
بصوت أوبرالي|in an opera voice|m
بحزن مسرحي مبالغ فيه|with over-the-top theatrical sadness|m
بغضب كوميدي مصطنع|with fake comic anger|m
بخوف مضحك من كل شيء|comically scared of everything|m
بثقة مبالغ فيها|with over-the-top confidence|m
مع الضحك بعد كل جملة|laughing after every sentence|m
بصوت عالٍ ومتحمس|loudly and excitedly|m
مع صوت طبول بالفم بين الجمل|with mouth drums between sentences|m
بأسلوب بطل خارق|like a superhero|m
بأسلوب شرير كرتوني|like a cartoon villain|m
بأسلوب إعلان حماسي جداً|like an over-excited advert|m
مع رقصة صغيرة في النهاية|ending with a little dance|m
مع إنهاء كل جملة بكلمة «تمام»|ending every sentence with «okay»|m
بالقافية قدر الإمكان|rhyming as much as possible|m
مع تمثيل المشهد كاملاً|acting out the whole scene|m
مع تحريك الكتفين طوال الوقت|moving your shoulders the whole time|m
بأسلوب نشرة أخبار عاجلة|like breaking news|m
مع نظارة شمسية طوال الوقت|wearing sunglasses the whole time|m
بأسلوب مدرب لياقة متحمس|like an excited fitness coach|m
مع ثلاث ثوانٍ من الصمت الدرامي|with three seconds of dramatic silence|m
بأسلوب مسرحية قديمة|like an old stage play|m
بصوت عالٍ جداً مع تمثيل مبالغ فيه|very loudly with over-the-top acting|h
بالفصحى الكاملة وبصوت مذيع|in full classical Arabic like a news anchor|h
مع الوقوف وتمثيل كل كلمة|standing up and acting out every word|h
بأسلوب عرض مسرحي كامل|as a full stage show|h
مع بكاء كوميدي في النهاية|ending with comic crying|h
بصوت أوبرالي عالٍ حتى النهاية|in a loud opera voice to the very end|h
مع تعابير وجه مبالغ فيها جداً|with extremely exaggerated facial expressions|h
مع شيء مضحك على الرأس|with something funny on your head|h
قريباً جداً من الكاميرا|very close to the camera|h
بأسلوب إعلان فيلم درامي|like a dramatic film trailer|h
مع التجمد كتمثال عند كل تصفيقة|freezing like a statue at every clap|h
بنبرة شاعر في أمسية شعرية|like a poet at a poetry evening|h
بصوت كرتوني لا يتوقف عن الضحك|in a cartoon voice that keeps laughing|h
مع إعادة كل جملة بصوتين مختلفين|repeating every line in two different voices|h
مع موسيقى تصويرية بالفم|with a soundtrack made by mouth|h
`);

export const ANIMALS = list(`
بطريق|a penguin
قطة|a cat
جرو صغير|a puppy
بومة|an owl
ديناصور|a dinosaur
زرافة|a giraffe
أرنب|a rabbit
دجاجة|a hen
ديك|a rooster
بطة|a duck
فيل|an elephant
قرد|a monkey
أسد كسول|a lazy lion
نمر|a tiger
دب|a bear
باندا|a panda
كنغر|a kangaroo
جمل|a camel
حصان|a horse
ضفدع|a frog
سلحفاة|a tortoise
حلزون|a snail
نحلة|a bee
فراشة|a butterfly
سمكة ذهبية|a goldfish
دلفين|a dolphin
حوت|a whale
أخطبوط|an octopus
ببغاء|a parrot
طاووس|a peacock
نعامة|an ostrich
خروف|a sheep
ماعز|a goat
بقرة|a cow
فأر|a mouse
سنجاب|a squirrel
قنفذ|a hedgehog
ثعلب|a fox
ذئب|a wolf
كوالا|a koala
فقمة|a seal
سلطعون|a crab
حمار وحشي|a zebra
فرس النهر|a hippo
تمساح نعسان|a sleepy crocodile
نملة|an ant
غراب|a crow
حمامة|a pigeon
لاما|a llama
وحيد القرن|a rhino
`);

/** Everyday actions, mimed (Arabic verbal nouns after «أثناء»; English -ing). */
export const ACTIVITIES = list(`
غسل الصحون|washing the dishes
طي الملابس|folding the laundry
ترتيب السرير|making the bed
البحث عن المفاتيح|looking for the keys
انتظار الحافلة|waiting for the bus
قيادة سيارة|driving a car
الاستيقاظ صباحاً|waking up in the morning
تنظيف الأسنان|brushing its teeth
ممارسة اليوغا|doing yoga
قراءة الجريدة|reading the newspaper
تصفيف الشعر|doing its hair
كي قميص|ironing a shirt
سقي النباتات|watering the plants
التقاط صورة سيلفي|taking a selfie
مشاهدة فيلم رعب|watching a horror film
لعب كرة القدم|playing football
العزف على الجيتار|playing the guitar
تعلم السباحة|learning to swim
الطبخ لأول مرة|cooking for the first time
ترتيب الخزانة|tidying the wardrobe
كتابة الواجب المدرسي|doing homework
التدرب على مقابلة عمل|practising for a job interview
حزم حقيبة السفر|packing a suitcase
انتظار المصعد|waiting for the lift
البحث عن الريموت|looking for the remote
فتح علبة صعبة|opening a stubborn jar
تعلم ركوب الدراجة|learning to ride a bike
تجربة نظارة جديدة|trying on new glasses
الاستماع لموسيقى حماسية|listening to upbeat music
التقاط شيء من الأرض|picking something up from the floor
الحديث في اجتماع مهم|speaking in an important meeting
تقديم نشرة الطقس|presenting the weather
ترتيب الكتب|arranging books
تجربة حذاء ضيق|trying on tight shoes
الهرب من ذبابة|escaping from a fly
رسم لوحة|painting a picture
تنظيف المرآة|cleaning a mirror
كنس الأرض|sweeping the floor
لعب الشطرنج|playing chess
تحية الجمهور|greeting an audience
الوقوف في طابور طويل|standing in a long queue
نسيان سبب دخول الغرفة|forgetting why it came into the room
البحث عن شاحن|looking for a charger
محاولة النوم في ضجيج|trying to sleep through noise
تعلم لغة جديدة|learning a new language
تحضير القهوة|making coffee
ارتداء معطف ثقيل|putting on a heavy coat
الفوز بسباق|winning a race
التدرب على خطاب|rehearsing a speech
عد النجوم|counting the stars
`);

export const CHARACTERS = list(`
روبوت جديد|a brand-new robot
رائد فضاء|an astronaut
طاهٍ مشهور|a famous chef
مرشد سياحي|a tour guide
معلق رياضي|a sports commentator
مذيع طقس|a weather presenter
ساحر مبتدئ|a beginner magician
مخترع|an inventor
محقق|a detective
قرصان|a pirate
فارس من العصور الوسطى|a medieval knight
كائن فضائي|an alien
مصفف شعر|a hairdresser
مدرب لياقة|a fitness coach
نادل مطعم|a restaurant waiter
طيار|a pilot
عالم آثار|an archaeologist
مصور أزياء|a fashion photographer
ممثل مسرح|a stage actor
مغني أوبرا|an opera singer
حارس متحف|a museum guard
سائق تاكسي|a taxi driver
مذيع نشرة|a newsreader
ميكانيكي|a mechanic
رسام|a painter
بطل خارق|a superhero
شرير كرتوني|a cartoon villain
دمية متحركة|a puppet
تمثال يتحرك|a statue that comes alive
ساعة منبه|an alarm clock
مدرب كرة قدم|a football coach
عالم فلك|an astronomer
حارس غابة|a forest ranger
حكم مباراة|a match referee
مقدم مسابقات|a quiz show host
راوي قصص|a storyteller
زائر من المستقبل|a visitor from the future
ديناصور يتكلم|a talking dinosaur
مهرج سيرك|a circus clown
ملاح سفينة|a ship's navigator
بستاني|a gardener
عازف طبول|a drummer
نجم سينما|a film star
مدير مكتب|an office manager
طبيب أسنان|a dentist
`);

export const SITUATIONS = list(`
في أول يوم عمل|on the first day at work
عند ضياع المفاتيح|who has lost the keys
في يوم شديد الحر|on a very hot day
في مقابلة تلفزيونية|in a TV interview
عند الفوز بجائزة|winning an award
عند نسيان الكلام|who forgot the lines
في مصعد بطيء جداً|in a very slow lift
في طابور طويل|in a long queue
أثناء عاصفة رملية|during a sandstorm
عند رؤية فأر|seeing a mouse
في رحلة إلى القمر|on a trip to the moon
عند استلام طرد غامض|receiving a mystery parcel
في أول درس سباحة|at the first swimming lesson
عند تأخر الحافلة|when the bus is late
في مسابقة طبخ|in a cooking contest
في متحف هادئ|in a quiet museum
عند نفاد شحن الجهاز|when the battery dies
في يوم ممطر|on a rainy day
عند سماع نكتة قديمة|hearing an old joke
في حفل افتتاح|at an opening ceremony
عند فقدان الصوت|who has lost its voice
في أول يوم إجازة|on the first day of the holidays
أثناء البحث عن الطريق|looking for the way
في درس رسم|in a painting class
عند اكتشاف كنز|discovering treasure
في مدينة ألعاب|at a fun fair
عند الاستيقاظ متأخراً|waking up late
في سباق حلزونات|at a snail race
أثناء تصوير إعلان|filming an advert
في غابة مظلمة|in a dark forest
في مطار مزدحم|in a busy airport
عند ربح مباراة شطرنج|winning a chess match
في اختبار قيادة|in a driving test
عند تذكر موعد مهم|remembering an important appointment
في محطة قطار|at a train station
عند رؤية البحر أول مرة|seeing the sea for the first time
في مكتبة صامتة|in a silent library
في نهائي بطولة|at a cup final
عند خسارة الريموت|having lost the remote
في عرض أزياء|at a fashion show
أثناء انتظار نتيجة اختبار|waiting for exam results
عند تلقي خبر سار|getting good news
في سفينة فضاء|on a spaceship
على شاطئ مزدحم|on a crowded beach
في معرض اختراعات|at an inventions fair
`);

export const MIME_ACTIONS = list(`
انتظار مصعد لا يصل|waiting for a lift that never comes
محاولة فتح باب عالق|trying to open a stuck door
حمل صندوق ثقيل جداً|carrying a very heavy box
البحث عن مقعد فارغ|looking for an empty seat
التقاط فراشة|catching a butterfly
صعود درج متحرك معطل|walking up a broken escalator
إخفاء ضحكة|hiding a laugh
المشي ضد ريح قوية|walking against a strong wind
تجربة مظلة لا تفتح|trying an umbrella that will not open
جر عربة ثقيلة|pulling a heavy trolley
محاولة إمساك صابونة زلقة|trying to hold slippery soap
الدخول إلى غرفة مظلمة|entering a dark room
تركيب قطعة أثاث|assembling a piece of furniture
البحث في حقيبة لا قاع لها|searching a bottomless bag
فك عقدة طويلة|untangling a long knot
إطعام سمكة صغيرة|feeding a little fish
إيقاف منبه لا يتوقف|stopping an alarm that will not stop
كتابة قائمة طويلة|writing a very long list
ارتداء قفازات صغيرة|putting on tiny gloves
اللحاق بحافلة|catching a bus
فتح صندوق مفاجآت|opening a surprise box
المشي على رمل حار|walking on hot sand
تجديف قارب|rowing a boat
حمل كعكة كبيرة|carrying a big cake
مطاردة ذبابة|chasing a fly
تطيير طائرة ورقية|flying a kite
طلاء جدار كبير|painting a big wall
تجربة تمرين صعب|trying a hard workout
إخراج شيء من علبة ضيقة|getting something out of a narrow tin
الاختباء من المطر|hiding from the rain
`);

export const PLACES = list(`
في المطار|at the airport
في المطبخ|in the kitchen
في الحديقة|in the park
على الشاطئ|on the beach
في المكتبة|in the library
في السوق|at the market
في محطة القطار|at the train station
في الصحراء|in the desert
في الفضاء|in space
تحت الماء|underwater
في الغابة|in the forest
في الملعب|at the stadium
في المتحف|in the museum
في المصعد|in the lift
في المدرسة|at school
في قاعة سينما|in a cinema
في مخيم|at a campsite
في واد أخضر|in a green valley
في مدينة ملاهٍ|at a theme park
في حديقة الحيوانات|at the zoo
في مطعم|in a restaurant
في قطار سريع|on a fast train
على سفينة|on a ship
في مختبر علمي|in a science lab
في استوديو تصوير|in a photo studio
في غرفة مظلمة|in a dark room
على مسرح كبير|on a big stage
في مرسم|in an art studio
في مسبح|at a swimming pool
في محطة فضاء|on a space station
`);

export const EMOTIONS = list(`
بفرح كبير|with great joy|e
بملل شديد|very bored|e
بفخر كبير|very proudly|e
بدهشة|in amazement|e
بعجلة شديدة|in a great hurry|e
بكسل|lazily|e
بارتباك|in a muddle|e
بحذر شديد|very carefully|e
بنعاس|sleepily|e
بفضول|curiously|e
بسعادة غامرة|overjoyed|e
بهدوء غريب|strangely calm|e
بخوف مضحك|comically frightened|m
بتوتر كوميدي|with comic nerves|m
بحزن مسرحي|with stage sadness|m
بثقة زائدة|over-confidently|m
بغضب مضحك|with funny anger|m
بإصرار عنيد|stubbornly|m
بحماس بطل منتصر|like a triumphant champion|m
كمشهد بطيء في فيلم|like a slow-motion film scene|m
بارتعاش من البرد|shivering with cold|m
مع ضحكة مكتومة|holding back a laugh|m
بحماس مرح|with playful excitement|m
بانزعاج مبالغ فيه|with over-the-top annoyance|h
بدراما كاملة|with full drama|h
بتعابير وجه مبالغ فيها|with exaggerated faces|h
مع تصفيق للنفس في النهاية|applauding yourself at the end|h
مع صوت عالٍ لكل حركة|with a loud sound for every move|h
مع تعليق صوتي على كل حركة|with a voice-over for every move|h
مع موسيقى تصويرية بالفم|with a mouth-made soundtrack|h
`);

export const SONG_TYPES = list(`
أغنية قصيرة|a short song
راب قصير|a short rap
موال قصير|a short mawwal
أهزوجة حماسية|a rousing chant
تهويدة|a lullaby
أغنية إعلان|an advert jingle
أغنية كرتون|a cartoon theme song
أوبرا قصيرة|a mini opera
أغنية بوب|a pop song
أغنية شعبية|a folk-style song
أغنية روك|a rock song
أغنية جاز|a jazz song
أغنية حزينة جداً|a very sad ballad
أغنية فرح|a happy song
أغنية صباحية|a good-morning song
أهزوجة رياضية|a sports chant
أغنية من ثلاث كلمات فقط|a song of only three words
أغنية بالهمهمة|a hummed song
ثنائي بصوتين مختلفين|a duet in two different voices
أغنية روبوتية|a robot song
أغنية بحارة|a sea shanty
أغنية مسرحية|a musical-theatre song
أغنية سريعة الإيقاع|an upbeat song
أغنية على إيقاع الدبكة|a dabke-rhythm song
أغنية وداع|a farewell song
أغنية اعتذار|an apology song
أغنية شكر|a thank-you song
أغنية ترحيب|a welcome song
لحن إعلان قديم|an old-style jingle
أغنية بطيئة جداً|a very slow song
`);

export const TOPICS = list(`
الجوارب الضائعة|lost socks
الطقس اليوم|today's weather
الواجبات المنزلية|homework
زحمة الطريق|traffic jams
الريموت المفقود|the missing remote
القطط|cats
يوم الإثنين|Mondays
السهر|staying up late
المنبه|the alarm clock
البيتزا|pizza
المطر|rain
الصيف الحار|hot summers
الشتاء|winter
قهوة الصباح|morning coffee
الكسل|laziness
التمارين الرياضية|exercise
كرة القدم|football
البحر|the sea
الفضاء|outer space
الديناصورات|dinosaurs
الروبوتات|robots
المستقبل|the future
السفر|travel
الحقائب الثقيلة|heavy suitcases
المطبخ|the kitchen
الغسالة|the washing machine
الشاحن المفقود|the lost charger
الإنترنت البطيء|slow internet
ألعاب الفيديو|video games
الكتب|books
الرسم|drawing
الحدائق|gardens
الزهور|flowers
الأشجار|trees
النجوم|the stars
القمر|the moon
الشمس|the sun
الغيوم|clouds
البطاريق|penguins
الموز|bananas
البطاطا|potatoes
الشوكولاتة|chocolate
الدراجات|bicycles
الحافلات|buses
القطارات|trains
الطائرات|aeroplanes
الأحذية|shoes
القبعات|hats
النظارات|glasses
المظلات|umbrellas
الوسائد|pillows
الألوان|colours
الموسيقى|music
الضحك|laughter
النظافة|keeping things clean
ترتيب الغرفة|tidying the room
المواعيد|being on time
الصباح الباكر|early mornings
العطلة|the holidays
الصحراء|the desert
`);

export const SPEECH_KINDS = list(`
خطاب حماسي|an inspiring speech
تقرير إخباري|a news report
إعلان تجاري|an advert
نشرة طقس|a weather forecast
تعليق رياضي|a sports commentary
محاضرة علمية|a science lecture
درس قصير|a short lesson
حكاية خيالية|a fairy tale
مراجعة نقدية|a critic's review
مقابلة مع النفس|an interview with yourself
فيلم وثائقي عن الطبيعة|a nature documentary
كلمة شكر|a thank-you speech
كلمة وداع|a farewell speech
إعلان فيلم|a film trailer
حكاية قبل النوم|a bedtime story
شرح علمي مبسط|a simple science explanation
نصيحة حكيمة|some wise advice
مرافعة محامٍ|a lawyer's closing speech
قصيدة مرتجلة|an improvised poem
جولة مرشد سياحي|a tour-guide talk
تقرير من الفضاء|a report from space
وصفة طبخ|a recipe talk
برنامج صباحي|a morning show
حوار بصوتين|a dialogue in two voices
عرض اختراع|an invention pitch
`);

export const TASKS = list(`
ربط الحذاء|tying shoelaces
استخدام الريموت|using a remote
فتح مظلة|opening an umbrella
طي منشفة|folding a towel
ارتداء الجوارب|putting on socks
تنظيف الأسنان|brushing teeth
ترتيب السرير|making the bed
غسل اليدين|washing hands
لعب الغميضة|playing hide and seek
رسم قطة|drawing a cat
التصفيق|clapping
الصفير|whistling
الضحك بشكل مقنع|laughing convincingly
التثاؤب|yawning
الجلوس على كرسي|sitting on a chair
ارتداء قبعة|wearing a hat
المشي|walking
القراءة|reading
النوم مبكراً|going to bed early
سقي نبتة|watering a plant
إغلاق الباب بهدوء|closing a door quietly
استخدام الملعقة|using a spoon
الابتسام للصور|smiling for photos
تشغيل أغنية|playing a song
التقاط صورة|taking a photo
العطس بأدب|sneezing politely
ترتيب الكتب|arranging books
لف وشاح|wrapping a scarf
صنع فقاعات الصابون|making soap bubbles
لعب الشطرنج|playing chess
كتابة الاسم|writing a name
الرد على «مرحباً»|answering a «hello»
لبس النظارة|putting on glasses
حمل كوب بحذر|carrying a cup carefully
تقشير موزة|peeling a banana
شم وردة|smelling a flower
العد إلى عشرة|counting to ten
التصفيق على الإيقاع|clapping to a beat
الوقوف في طابور|queuing
الاستيقاظ على المنبه|waking up to an alarm
`);

export const AUDIENCES = list(`
كائن فضائي|an alien
ديناصور|a dinosaur
روبوت جديد|a new robot
سمكة ذهبية|a goldfish
زائر من القرن الماضي|a visitor from the last century
قطة متكبرة|a snobby cat
ساحر|a wizard
فارس قديم|an old knight
نملة|an ant
بطريق|a penguin
شجرة|a tree
تمثال|a statue
قرصان|a pirate
مخلوق بحري|a sea creature
غيمة|a cloud
وسادة|a pillow
ساعة حائط|a wall clock
مكنسة|a broom
ببغاء|a parrot
زرافة|a giraffe
سلحفاة مستعجلة|a tortoise in a hurry
دمية|a puppet
نجم سينما|a film star
مخترع قديم|an old inventor
حلزون|a snail
`);

export const SPEECH_RULES = list(`
بالفصحى فقط|only in classical Arabic
بصيغة أسئلة فقط|only in questions
بصوت مذيع أخبار فقط|only in a news-anchor voice
بجمل من ثلاث كلمات فقط|only in three-word sentences
مع إنهاء كل جملة بـ«يا سلام»|ending every sentence with «wow»
بصوت روبوت فقط|only in a robot voice
بالقافية فقط|only in rhyme
بنبرة رسمية جداً فقط|only in a very formal tone
مع بدء كل جملة بـ«سيداتي سادتي»|starting every sentence with «ladies and gentlemen»
بصوت هامس فقط|only in a whisper
`);

export const SPEECH_EXTRAS = list(`
حتى نهاية البث|until the end of the live
حتى نهاية البث مع ابتسامة|until the end of the live, smiling
حتى نهاية البث مهما حدث|until the end of the live, whatever happens
حتى نهاية البث ومع كل التحيات|until the end of the live, greetings included
حتى نهاية البث وحتى في الضحك|until the end of the live, even when laughing
حتى نهاية البث وبالتمثيل|until the end of the live, with acting
حتى نهاية البث مع لقب «سعادة المذيع»|until the end of the live, called «Your Excellency»
حتى نهاية البث وبحماس دائم|until the end of the live, always excited
حتى نهاية البث مع وقفة بعد كل جملة|until the end of the live, pausing after every line
حتى نهاية البث وبهدوء تام|until the end of the live, completely calm
`);

/** Truth questions (Arabic unvocalized past forms: gender-neutral). */
export const STEMS = list(`
ما أطرف موقف حصل معك|What is the funniest thing that happened to you
ما أغرب شيء فعلته|What is the strangest thing you did
ما أجمل شيء تعلمته|What is the best thing you learned
ما أصعب شيء جربته|What is the hardest thing you tried
ما أكثر شيء أضحكك|What made you laugh the most
ما أول فكرة جاءت في بالك|What was the first idea that came to mind
ما أطرف خطأ ارتكبته|What is the funniest mistake you made
ما أغرب حلم رأيته|What is the strangest dream you had
ما أطرف كلمة قلتها بالخطأ|What is the funniest word you said by mistake
ما أكثر شيء أحرجك|What embarrassed you the most
ما أسرع قرار اتخذته|What is the quickest decision you made
ما أكثر شيء فاجأك|What surprised you the most
ما أطرف شيء قيل لك|What is the funniest thing anyone said to you
ما أكثر شيء أخافك|What scared you the most
ما أغرب شيء وجدته|What is the strangest thing you found
ما أطرف لقب حصلت عليه|What is the funniest nickname you got
ما أفضل فكرة خطرت لك|What is the best idea you had
ما أسوأ نكتة سمعتها|What is the worst joke you heard
ما أهم شيء نسيته|What is the most important thing you forgot
ما أغرب سؤال سئلته|What is the strangest question you were asked
ما أطرف مقلب تعرضت له|What is the funniest prank played on you
ما أصعب سؤال واجهته|What is the hardest question you faced
ما أذكى شيء فعلته|What is the cleverest thing you did
ما أكثر شيء أتعبك|What tired you out the most
ما أجمل مفاجأة حصلت عليها|What is the nicest surprise you got
ما أغرب صوت سمعته|What is the strangest sound you heard
ما أطرف شيء رأيته|What is the funniest thing you saw
ما أكثر شيء أزعجك بشكل مضحك|What annoyed you the most, in a funny way
ما أسرع شيء تعلمته|What did you learn the fastest
ما أطرف عادة لديك|What is your funniest habit
ما أغرب شيء صدقته|What is the strangest thing you believed
ما أكثر شيء تحمست له|What were you most excited about
ما أكبر إنجاز صغير حققته|What is your biggest small achievement
ما أطرف سوء فهم حصل معك|What is the funniest misunderstanding you had
ما أسوأ قرار مضحك اتخذته|What is the worst funny decision you made
ما أطرف حركة رقص قمت بها|What is the funniest dance move you did
ما أكثر شيء أبهرك|What amazed you the most
ما أغرب رائحة لاحظتها|What is the strangest smell you noticed
ما أطرف خطأ كتابي ارتكبته|What is your funniest typo
ما أجمل صوت سمعته|What is the loveliest sound you heard
`);

export const DOMAINS = list(`
في المدرسة|at school
في السفر|while travelling
في المطبخ|in the kitchen
في الإجازة|on holiday
في الصباح الباكر|early in the morning
في يوم ممطر|on a rainy day
هذا الأسبوع|this week
هذا العام|this year
في الصغر|when you were little
في أول يوم دراسة|on your first school day
أثناء الطبخ|while cooking
أثناء التمارين|while exercising
في المطار|at the airport
في الحديقة|in the park
على الشاطئ|at the beach
في مدينة الملاهي|at a theme park
في الامتحانات|during exams
في بث مباشر|on a live stream
أمام الكاميرا|in front of the camera
في المكتبة|in the library
في الملعب|at a stadium
في السينما|at the cinema
في الشتاء|in winter
في الصيف|in summer
أثناء النوم|while sleeping
في الحافلة|on a bus
في القطار|on a train
في المصعد|in a lift
في مطعم|in a restaurant
في درس الرياضيات|in a maths lesson
في درس الرسم|in an art lesson
في رحلة مدرسية|on a school trip
أثناء ألعاب الفيديو|while gaming
في يوم حار|on a hot day
في منتصف الليل|at midnight
في أول يوم عمل|on your first day at work
في دورة تدريبية|on a training course
أثناء التصوير|while taking photos
أثناء الرسم|while drawing
في مسابقة|in a competition
`);

/** How a truth is answered (after «الإجابة» / «Answer»). */
export const ANSWER_MANNERS = list(`
خلال 10 ثوانٍ|within 10 seconds|e
بثلاث كلمات فقط|in just three words|e
مع شرح السبب|and explain why|e
بصوت هامس|in a whisper|e
بوجه جاد|with a straight face|e
على شكل قصة قصيرة|as a short story|e
في جملة واحدة|in one sentence|e
بصوت روبوت|in a robot voice|e
مع تصفيقة بعدها|with a clap afterwards|e
مع تقييم الموقف من 10|and rate it out of 10|e
مع ثلاث كلمات تصف الشعور|with three words for the feeling|e
بأسرع ما يمكن|as fast as possible|e
ببطء شديد|very slowly|e
بثقة كاملة|with total confidence|e
مع ابتسامة|with a smile|e
ثم تمثيل الموقف|and then act it out|m
بالفصحى|in classical Arabic|m
دون ضحك|without laughing|m
بأسلوب نشرة أخبار|like a news bulletin|m
بالإشارة أولاً ثم بالكلام|in gestures first, then in words|m
مع مؤثرات صوتية بالفم|with mouth sound effects|m
بأسلوب شاعر|like a poet|m
بأسلوب معلق رياضي|like a sports commentator|m
بأسلوب برنامج وثائقي|like a documentary|m
وقوفاً|standing up|m
كأنها مشهد في فيلم|as if it were a film scene|m
بصوت عالٍ وواضح|loudly and clearly|m
ثم سؤال الفائز عن رأيه|then ask the winner what they think|m
بلا توقف لمدة 30 ثانية|non-stop for 30 seconds|m
مع إعادة تمثيل كاملة بصوت عالٍ|with a full, loud re-enactment|h
قريباً جداً من الكاميرا|very close to the camera|h
مع كل التفاصيل المحرجة الممكنة|with every embarrassing detail you can share|h
ثم إعادة الموقف بالحركة البطيئة|then replay it in slow motion|h
بأسلوب درامي جداً|very dramatically|h
ثم غناء جملة عنه|then sing a line about it|h
ثم رسم الموقف وعرضه|then draw it and show it|h
بالقافية|in rhyme|h
مع تقليد النفس في ذلك الوقت|imitating yourself back then|h
بصوت مذيع وبالفصحى|like an anchor, in classical Arabic|h
ثم تمثيله بلا كلام|then mime it with no words|h
`);

export const CONFESS_STEMS = list(`
اعتراف بأكثر موقف محرج حصل معك|Confess your most embarrassing moment
اعتراف بأغرب عادة لديك|Confess your strangest habit
اعتراف بأطرف كذبة بيضاء قلتها|Confess the funniest white lie you told
اعتراف بأغرب شيء يخيفك|Confess the strangest thing that scares you
اعتراف بأسوأ مهارة لديك|Confess your worst skill
اعتراف بأطرف شيء بكيت بسببه|Confess the funniest thing that made you cry
اعتراف بأغرب شيء احتفظت به|Confess the strangest thing you kept
اعتراف بلحظة تمنيت فيها الاختفاء|Confess a moment you wished you could vanish
اعتراف بأطرف موقف أحرجك أمام الناس|Confess the funniest time you were embarrassed in public
اعتراف بأغرب عادة نوم لديك|Confess your strangest sleeping habit
اعتراف بأسوأ طبخة صنعتها|Confess the worst dish you ever made
اعتراف بأكثر شيء تكاسلت عنه|Confess the thing you were laziest about
اعتراف بأطرف خطأ أمام الكاميرا|Confess your funniest mistake on camera
اعتراف بأطرف سوء فهم سببته|Confess the funniest misunderstanding you caused
اعتراف بأكثر موعد تأخرت عنه|Confess the appointment you were latest for
`);

export const DANCES = list(`
رقصة الروبوت|the robot dance
رقصة البطريق|the penguin dance
رقصة بالكتفين فقط|a shoulders-only dance
رقصة بالأصابع فقط|a fingers-only dance
رقصة الحاجبين|an eyebrow dance
رقصة الموجة باليدين|a hand-wave dance
رقصة التمثال|the statue dance
رقصة بالحركة البطيئة|a slow-motion dance
رقصة الكرسي جلوساً|a seated chair dance
رقصة هز الرأس|a head-nod dance
رقصة الديسكو القديمة|an old disco dance
رقصة الدجاجة|the chicken dance
رقصة المكنسة|a broom dance
رقصة الفراشة|a butterfly dance
رقصة الأمواج|a wave dance
رقصة الساعة|the clock dance
رقصة الكرتون|a cartoon dance
رقصة الدب|a bear dance
رقصة المهرج|a clown dance
رقصة الكاوبوي|a cowboy dance
رقصة الريح|a wind dance
رقصة قائد الأوركسترا|a conductor dance
رقصة الدمية المتحركة|a puppet dance
رقصة الطاهي|a chef dance
رقصة البحار|a sailor dance
رقصة الديناصور|a dinosaur dance
رقصة الأخطبوط|an octopus dance
رقصة الفرح الصغيرة|a little happy dance
رقصة الانتصار|a victory dance
رقصة الموسيقى الهادئة|a calm-music dance
`);

export const RHYTHMS = list(`
التصفيق|clapping
الطرق على الطاولة|tapping on the table
صوت الساعة|a ticking clock
الدندنة|humming
الصفير|whistling
العد حتى ثمانية|counting to eight
صوت قطرات الماء|dripping water
لحن كرتون مدندن|a hummed cartoon tune
طبول بالفم|mouth drums
طرق ملعقة على كوب|a spoon tapping a cup
فرقعة الأصابع|finger snaps
موسيقى هادئة|calm music
موسيقى سريعة|fast music
صوت قطار بالفم|a train sound by mouth
صوت المطر|the sound of rain
النقر بالقدمين|foot tapping
همهمة عميقة|deep humming
بيت بوكس بسيط|simple beatbox
تصفيق نبضات القلب|a heartbeat clap
صوت أجراس بالفم|bells made by mouth
لحن المنبه|an alarm-clock tune
إيقاع بطيء جداً|a very slow beat
إيقاع سريع جداً|a very fast beat
صوت البط|duck quacks
نقيق الضفادع|frog croaks
العد بالعربية والإنجليزية|counting in Arabic and English
صوت الخطوات|footsteps
صوت المكنسة|a broom sweeping
صوت الريح|the wind
لحن إعلان|an advert jingle
`);

export const DANCE_MODS = list(`
لمدة 20 ثانية|for 20 seconds|e
لمدة 30 ثانية|for 30 seconds|e
بوجه جاد جداً|with a very serious face|e
مع ابتسامة عريضة|with a big grin|e
مع النظر إلى السقف|looking at the ceiling|e
جلوساً على الكرسي|while seated|e
بالحركة البطيئة|in slow motion|e
مع قبعة على الرأس|with a hat on|e
مع الهمس بالكلمات|whispering the words|e
مع التصفيق في النهاية|clapping at the end|e
بحركات صغيرة جداً|with tiny moves|e
مع ابتسامة لا تختفي|with a smile that never fades|e
بدقة روبوت|with robot precision|e
لمدة 45 ثانية|for 45 seconds|e
لمدة دقيقة|for one minute|m
مع العد بصوت عالٍ|counting out loud|e
مع التجمد كل خمس ثوانٍ|freezing every five seconds|m
مع تعليق صوتي حماسي|with an excited voice-over|m
ثم تعليم الحركة للمشاهدين|then teach the move to the viewers|m
مع نظارة شمسية|wearing sunglasses|e
مع تقليد صوت آلة موسيقية|imitating a musical instrument|m
مع تسمية كل حركة باسم مضحك|giving every move a funny name|m
بثلاث سرعات مختلفة|at three different speeds|e
مع رفع اليدين طوال الوقت|with hands up the whole time|e
مع الختام بوقفة بطولية|ending with a heroic pose|m
مع تكرار الحركة عشر مرات|repeating the move ten times|m
بأقصى حماس ممكن|with maximum enthusiasm|h
مع تعابير وجه مبالغ فيها|with exaggerated faces|h
قريباً من الكاميرا|close to the camera|h
مع الغناء في الوقت نفسه|singing at the same time|h
كأنها عرض عالمي|as if it were a world show|h
بأسلوب فرقة استعراضية|like a show troupe|h
بحركات كبيرة جداً|with enormous moves|h
مع تعليق كمعلق رياضي|with sports-style commentary|h
بحماس بطل منتصر|like a triumphant champion|h
مع موسيقى تصويرية بالفم|with a mouth-made soundtrack|h
`);

export const DANCE_NAMES = list(`
«الحلزون المستعجل»|«The Hurried Snail»
«الريموت الضائع»|«The Lost Remote»
«القهوة الباردة»|«Cold Coffee»
«البطريق السعيد»|«The Happy Penguin»
«الغيمة الكسولة»|«The Lazy Cloud»
«الجوارب المتطايرة»|«The Flying Socks»
«المنبه الغاضب»|«The Grumpy Alarm»
«الزرافة الخجولة»|«The Shy Giraffe»
«الموجة الصغيرة»|«The Little Wave»
«الديناصور المهذب»|«The Polite Dinosaur»
«الكرسي الراقص»|«The Dancing Chair»
«الشمس النائمة»|«The Sleepy Sun»
«القطة المتكبرة»|«The Snobby Cat»
«البطاطا المقرمشة»|«The Crunchy Potato»
«النملة المجتهدة»|«The Busy Ant»
«الروبوت الحزين»|«The Sad Robot»
«الوسادة الطائرة»|«The Flying Pillow»
«الضفدع الأنيق»|«The Smart Frog»
«الساعة المتأخرة»|«The Late Clock»
«القمر المبتسم»|«The Smiling Moon»
«الريح الهادئة»|«The Gentle Breeze»
«البالون العنيد»|«The Stubborn Balloon»
«الشاحن المفقود»|«The Missing Charger»
«الحافلة المتأخرة»|«The Late Bus»
«النجمة اللامعة»|«The Shining Star»
«الكعكة السعيدة»|«The Happy Cake»
«المظلة المقلوبة»|«The Upside-down Umbrella»
«السلحفاة السريعة»|«The Speedy Tortoise»
«الفراشة المرتبكة»|«The Muddled Butterfly»
«الموزة الراقصة»|«The Dancing Banana»
«الطاهي المستعجل»|«The Hasty Chef»
«الأخطبوط المنظم»|«The Tidy Octopus»
«البومة الساهرة»|«The Night Owl»
«الكنغر الهادئ»|«The Calm Kangaroo»
«الحذاء الضيق»|«The Tight Shoe»
«الدب النعسان»|«The Drowsy Bear»
«الغسالة الدوارة»|«The Whirling Washer»
«القرصان الطيب»|«The Kind Pirate»
«الزهرة العطشانة»|«The Thirsty Flower»
«الثعلب المبتسم»|«The Smiling Fox»
`);

export const BODY_PARTS = list(`
الكتفين|shoulders
اليدين|hands
الرأس|head
الأصابع|fingers
الحاجبين|eyebrows
القدمين|feet
المرفقين|elbows
العينين|eyes
الوجه|face
الذراعين|arms
المعصمين|wrists
الأنف|nose
الكتف اليمنى|right shoulder
اليد اليسرى|left hand
الأصابع والكتفين|fingers and shoulders
الرأس واليدين|head and hands
`);

export const OBJECTS = list(`
وسادة|a pillow
ملعقة|a spoon
كوب فارغ|an empty cup
جورب|a sock
مشط|a comb
قبعة|a hat
نظارة|a pair of glasses
كتاب|a book
قلم|a pen
ريموت|a remote
مظلة|an umbrella
منشفة|a towel
حذاء|a shoe
وشاح|a scarf
ساعة يد|a wristwatch
دفتر|a notebook
علبة مناديل|a tissue box
فرشاة شعر|a hairbrush
كرسي|a chair
لعبة صغيرة|a small toy
بطانية|a blanket
مخدة صغيرة|a cushion
صحن بلاستيكي|a plastic plate
ممحاة|an eraser
مسطرة|a ruler
شاحن|a charger
سماعات|a pair of headphones
حقيبة|a bag
قارورة ماء فارغة|an empty water bottle
كيس ورقي|a paper bag
صندوق كرتون|a cardboard box
وردة|a flower
تفاحة|an apple
موزة|a banana
ليمونة|a lemon
مكعب ألوان|a puzzle cube
دمية|a doll
كرة صغيرة|a small ball
مغناطيس ثلاجة|a fridge magnet
ملقط غسيل|a clothes peg
`);

export const IMAGINARY = list(`
آلة زمن|a time machine
اختراع القرن|the invention of the century
جائزة عالمية|a world award
كنز نادر|a rare treasure
جهاز من المستقبل|a device from the future
حيوان أليف|a pet
ميكروفون سحري|a magic microphone
تحفة فنية|a masterpiece
بوصلة سحرية|a magic compass
مركبة فضائية|a spaceship
ريموت للكون|a remote for the universe
كأس البطولة|the championship trophy
عصا سحرية|a magic wand
خريطة كنز|a treasure map
روبوت ذكي|a smart robot
نجم سينما|a film star
مذيع أخبار|a newsreader
كتاب أسرار|a book of secrets
آلة ترجمة|a translation machine
جهاز قراءة أفكار|a mind-reading device
مضرب الأبطال|a champion's racket
طائرة خاصة|a private jet
مفتاح المدينة|the key to the city
قطعة من القمر|a piece of the moon
بيضة ديناصور|a dinosaur egg
ساعة سحرية|a magic watch
زر الضحك|a laughter button
مكبر صوت عملاق|a giant loudspeaker
شخصية كرتونية|a cartoon character
مدرب شخصي|a personal coach
جهاز تحكم بالطقس|a weather controller
سفينة قراصنة|a pirate ship
بطل خارق|a superhero
كاميرا سحرية|a magic camera
آلة السعادة|a happiness machine
لوحة نادرة|a rare painting
آلة موسيقية جديدة|a brand-new instrument
رفيق مغامرات|an adventure companion
مخلوق فضائي صغير|a tiny alien
تذكار من المريخ|a souvenir from Mars
`);

export const FORBIDDEN = list(`
«نعم»|«yes»
«لا»|«no»
«أنا»|«I»
«جداً»|«very»
«يعني»|«like»
«هذا»|«this»
«في»|«in»
«كان»|«was»
«شيء»|«thing»
«الآن»|«now»
«لكن»|«but»
«كثير»|«lots»
«حلو»|«nice»
«طيب»|«okay»
«ممكن»|«maybe»
«أيضاً»|«also»
«دائماً»|«always»
«اليوم»|«today»
«كل»|«every»
«عندي»|«have»
«من»|«from»
«على»|«on»
«هو»|«he»
«هي»|«she»
«نحن»|«we»
«لماذا»|«why»
«كيف»|«how»
«أين»|«where»
«متى»|«when»
«مرة»|«once»
`);

export const PENALTIES = list(`
وكل خطأ بتصفيقة|each slip costs a clap|e
وكل خطأ بتحية للكاميرا|each slip costs a bow to the camera|e
وكل خطأ بثانيتين من الصمت|each slip costs two seconds of silence|e
وكل خطأ بوقفة تمثال|each slip costs a statue pose|e
وكل خطأ بصوت روبوت|each slip costs a robot beep|e
وكل خطأ بابتسامة عريضة|each slip costs a big grin|e
وكل خطأ بتصفيقتين|each slip costs two claps|e
وكل خطأ بمواء قطة|each slip costs a meow|e
وكل خطأ بعطسة مزيفة|each slip costs a fake sneeze|e
وكل خطأ بتصفيقة فوق الرأس|each slip costs a clap over your head|e
وكل خطأ بضحكة شريرة|each slip costs an evil laugh|m
وكل خطأ بصوت دجاجة|each slip costs a chicken sound|m
وكل خطأ بالبدء من جديد|each slip means starting again|m
وكل خطأ بغناء كلمة|each slip costs a sung word|m
وكل خطأ برقصة صغيرة|each slip costs a little dance|m
وكل خطأ بصيحة «يا للهول»|each slip costs a cry of «oh no»|m
وكل خطأ برسم وجه مضحك على ورقة|each slip costs a funny face on paper|m
وكل خطأ بنظرة درامية للكاميرا|each slip costs a dramatic look at the camera|m
وكل خطأ بنكتة|each slip costs a joke|m
وكل خطأ بجملة بصوت مذيع|each slip costs a line in an anchor voice|m
وكل خطأ بصيحة نصر|each slip costs a victory shout|m
وكل خطأ بالوقوف لحظة|each slip means standing up for a moment|m
وكل خطأ بتعليق من الفائز|each slip earns a comment from the winner|h
وكل خطأ بأغنية قصيرة|each slip costs a short song|h
وكل خطأ بتقليد حيوان يختاره الفائز|each slip costs an animal impression the winner picks|h
وكل خطأ بقول «آسف» بثلاث لغات|each slip costs «sorry» in three languages|h
وكل خطأ بتمثيل البكاء|each slip costs fake crying|h
وكل خطأ بحركة رقص يختارها الفائز|each slip costs a dance move the winner picks|h
وكل خطأ يحول الكلام إلى الفصحى|each slip switches the talk to classical Arabic|h
وكل خطأ بمشهد تمثيلي قصير|each slip costs a short acted scene|h
`);

export const QUIZ_CATS = list(`
أسماء فواكه|fruits
أسماء خضار|vegetables
ألوان|colours
حيوانات|animals
طيور|birds
أشياء في المطبخ|things in a kitchen
أشياء في الحقيبة|things in a bag
رياضات|sports
مهن|jobs
وسائل نقل|kinds of transport
أشياء لونها أحمر|red things
أشياء لونها أزرق|blue things
أشياء مستديرة|round things
أشياء أكبر من الكرسي|things bigger than a chair
أشياء تطير|things that fly
أشياء تستخدم في المطر|things used in the rain
أنواع حلويات|desserts
أدوات مكتبية|stationery items
أجزاء السيارة|parts of a car
ملابس شتوية|winter clothes
ألعاب|games
آلات موسيقية|musical instruments
أشكال هندسية|shapes
أشياء في الحديقة|things in a garden
أشياء في البحر|things in the sea
أشياء في الفضاء|things in space
أنواع الطقس|kinds of weather
أشياء ناعمة|soft things
أشياء تصدر ضجيجاً|noisy things
أنواع الأحذية|kinds of shoes
أشياء لها عجلات|things with wheels
أشياء نستخدمها صباحاً|things we use in the morning
حيوانات المزرعة|farm animals
حيوانات الغابة|forest animals
أشياء باردة|cold things
أشياء صفراء|yellow things
أنواع الزهور|flowers
أسماء كواكب|planets
أدوات رسم|art supplies
أشياء في الحمام|things in a bathroom
أشياء تفتح وتغلق|things that open and close
أجهزة منزلية|home appliances
أشياء من الخشب|wooden things
ألعاب الحدائق|playground things
أنواع الخبز|kinds of bread
`);

export const QUIZ_MANNERS = list(`
مع التصفيق بعد كل اسم|clapping after each one|e
بصوت هامس|in a whisper|e
بصوت روبوت|in a robot voice|e
دون تكرار|with no repeats|e
مع رفع إصبع لكل اسم|raising a finger for each|e
مع إغماض العينين|with eyes closed|e
دون استخدام اليدين|without using your hands|e
بوجه جاد جداً|with a very serious face|e
مع العد بصوت عالٍ|counting out loud|e
بحماس بطل|like a champion|e
بصوت متعب|in a tired voice|e
بصوت متحمس|in an excited voice|e
مع ابتسامة دائمة|smiling throughout|e
مع لمس الأنف بعد كل اسم|touching your nose after each|e
بصوت كرتوني|in a cartoon voice|e
مع رسم دائرة في الهواء لكل اسم|drawing a circle in the air for each|e
ببطء شديد|very slowly|e
بأسلوب معلق رياضي|like a sports commentator|m
مع تمثيل كل اسم بحركة|acting out each one|m
مع غناء الأسماء|singing them|m
بصوت أوبرالي|in an opera voice|m
مع ضحكة بعد كل اسم|laughing after each one|m
بنبرة مذيع أخبار|like a newsreader|m
بنبرة مسرحية|in a theatrical voice|m
مع صفة لكل اسم|with an adjective for each|e
بأسلوب إعلان|like an advert|m
مع صوت مختلف لكل اسم|with a different sound for each|m
بسرعة متزايدة|getting faster each time|e
مع تقييم كل اسم من 10|rating each out of 10|e
مع إشارة قبل كل اسم|with a gesture before each|e
مع تمثيل الندم عند كل خطأ|acting regret at every mistake|m
بثلاث نبرات مختلفة|in three different tones|e
بالهمس ثم بصوت عالٍ|whispering, then loudly|m
بأسلوب شاعر|like a poet|m
ثم شرح أغرب اسم منها|then explaining the oddest one|m
بصوت عالٍ جداً|very loudly|m
ثم تمثيل آخر اسم|then acting out the last one|m
مع نطق كل اسم بالمقلوب|saying each one backwards|h
بالترتيب الأبجدي|in alphabetical order|h
مع رسم كل اسم بسرعة|quickly drawing each one|h
بالفصحى فقط|only in classical Arabic|h
بقافية لكل اسم|with a rhyme for each|h
مع جملة مضحكة عن كل اسم|with a funny line about each|h
ثم إعادة القائمة بالعكس|then repeating the list backwards|h
مع حركة رقص لكل اسم|with a dance move for each|h
`);

export const DRAW_SUBJECTS = list(`
قطة ترتدي نظارة|a cat wearing glasses
بيت على شكل حذاء|a house shaped like a shoe
روبوت يطبخ|a robot cooking
ديناصور يلعب الكرة|a dinosaur playing ball
سمكة طائرة|a flying fish
شمس مبتسمة|a smiling sun
قلعة من الحلوى|a castle made of sweets
سيارة لها أرجل|a car with legs
زرافة قصيرة|a short giraffe
فيل صغير جداً|a tiny elephant
مركبة فضائية|a spaceship
وحش لطيف|a cute monster
شجرة تتكلم|a talking tree
بطريق في الصحراء|a penguin in the desert
حلزون سريع|a speedy snail
كوب قهوة سعيد|a happy coffee cup
غيمة نائمة|a sleeping cloud
سلحفاة بطلة|a champion tortoise
قطار من الفواكه|a train made of fruit
ساعة ترقص|a dancing clock
قمر يرتدي قبعة|a moon wearing a hat
ضفدع أنيق|a smart frog
أخطبوط يعزف|an octopus playing music
كنغر يحمل حقيبة|a kangaroo carrying a bag
بومة تقرأ|an owl reading a book
دب يرسم|a bear painting
جزيرة كنز|a treasure island
بالون على شكل قطة|a cat-shaped balloon
كعكة عملاقة|a giant cake
جمل في الفضاء|a camel in space
سحابة مطر غاضبة|a grumpy rain cloud
نملة تحمل تفاحة|an ant carrying an apple
زهرة بنظارة|a flower with glasses
حذاء طائر|a flying shoe
بطاطا مبتسمة|a smiling potato
قرد على دراجة|a monkey on a bike
نجمة نعسانة|a sleepy star
روبوت حزين|a sad robot
حديقة على القمر|a garden on the moon
وحيد قرن يرقص|a dancing rhino
`);

export const DRAW_RULES = list(`
خلال دقيقة|within one minute|e
خلال 30 ثانية|in 30 seconds|e
بثلاثة ألوان فقط|with only three colours|e
بدوائر فقط|using only circles|e
بمربعات فقط|using only squares|e
بأصغر حجم ممكن|as small as possible|e
على صفحة كاملة|across a whole page|e
بأسلوب الكرتون|in cartoon style|e
بالنقاط فقط|using only dots|e
بخطوط متعرجة|with wiggly lines|e
خلال دقيقتين|within two minutes|e
مع اسم مضحك له|and give it a funny name|e
بأكبر حجم ممكن|as big as possible|e
بوجه جاد طوال الوقت|with a straight face throughout|e
بأشكال هندسية فقط|using only shapes|e
بعينين مغمضتين|with eyes closed|m
باليد غير المعتادة|with your other hand|m
بخط واحد دون رفع القلم|in one line without lifting the pen|m
مع شرح كل خط أثناء الرسم|explaining every line while drawing|m
بأسلوب لوحة شهيرة|in the style of a famous painting|m
والقلم بين إصبعين فقط|holding the pen with two fingers|m
مع تعليق صوتي حماسي|with an excited voice-over|m
مع فقاعة كلام فيها جملة|with a speech bubble|e
مع العد التنازلي بصوت عالٍ|counting down out loud|e
كأنها لمتحف كبير|as if for a big museum|m
والورقة فوق الرأس|with the paper on top of your head|h
مع الغناء أثناء الرسم|singing while drawing|h
دون النظر إلى الورقة|without looking at the paper|h
بثلاث خطوط فقط|in just three strokes|h
مع تبديل اليد كل عشر ثوانٍ|switching hands every ten seconds|h
`);

export const SHOW_MANNERS = list(`
ثم عرضه بفخر|then show it proudly|e
ثم إعطاؤه اسماً|then give it a name|e
ثم تقييمه من 10|then rate it out of 10|e
ثم وضعه بجانب الوجه|then hold it next to your face|e
ثم تعليقه أمام الكاميرا|then hang it up in front of the camera|e
ثم وصف ألوانه|then describe its colours|e
ثم التصفيق له|then applaud it|e
ثم عرضه دون كلام|then show it without a word|e
ثم الحديث عنه همساً|then whisper about it|e
ثم عرضه بابتسامة|then show it with a smile|e
ثم كتابة اسم له فوقه|then write a name on it|e
ثم إعطاؤه درجة|then give it a grade|e
ثم عرضه من زاوية جديدة|then show it from a new angle|e
ثم تعريفه للمشاهدين|then introduce it to the viewers|e
ثم وصفه بثلاث كلمات|then describe it in three words|e
ثم شرحه كتحفة عالمية|then present it as a masterpiece|m
ثم سؤال الفائز عن رأيه|then ask the winner what they think|m
ثم عرضه بالحركة البطيئة|then reveal it in slow motion|m
ثم تأليف قصة عنه|then make up a story about it|e
ثم شرحه بصوت مذيع|then explain it like an anchor|m
ثم إعطاء الرسمة صوتاً|then give the drawing a voice|m
ثم تسميته بالفصحى|then name it in classical Arabic|m
ثم تقديمه كاختراع|then pitch it as an invention|m
ثم شرح سبب كل خط|then explain every line|e
ثم عرضه كإعلان|then show it like an advert|m
ثم تقديمه ككأس بطولة|then present it like a trophy|m
ثم سؤال المشاهدين عن اسم له|then ask the viewers to name it|e
ثم عرضه كغلاف مجلة|then show it like a magazine cover|m
ثم كشفه مع صوت طبول|then reveal it with a drum roll|m
ثم وصفه كأنه حي|then describe it as if it were alive|m
ثم غناء جملة عنه|then sing a line about it|h
ثم الدفاع عنه كمحامٍ|then defend it like a lawyer|h
ثم إخفاؤه وكشفه بدراما|then hide it and reveal it dramatically|h
ثم الاحتفال به برقصة|then celebrate it with a dance|h
ثم مقارنته بالأصل بجدية|then compare it seriously to the real thing|h
ثم تحويله إلى شخصية تتكلم|then turn it into a talking character|h
ثم شرحه كعالم آثار|then explain it like an archaeologist|h
ثم إلقاء كلمة عنه|then give a speech about it|h
ثم تمثيل ما فيه|then act out what is in it|h
ثم عرضه بأسلوب مزاد خيالي|then show it off like a grand unveiling|h
`);

export const DRAW_AS = list(`
على شكل بطل خارق|as a superhero
على شكل قطة|as a cat
بقبعة قرصان|with a pirate hat
كرائد فضاء|as an astronaut
على شكل شمس|as a sun
كشخصية كرتونية|as a cartoon character
بنظارة كبيرة|with big glasses
كروبوت|as a robot
على شكل نجمة|as a star
كفارس|as a knight
بشعر من الزهور|with hair made of flowers
على شكل غيمة|as a cloud
كطاهٍ مشهور|as a famous chef
على شكل تفاحة|as an apple
كبطريق|as a penguin
بشارب طويل|with a long moustache
كساحر|as a wizard
على شكل كوكب|as a planet
كديناصور لطيف|as a cute dinosaur
كمحقق|as a detective
كبطل أفلام|as a film hero
بأذني أرنب|with bunny ears
كعالم|as a scientist
كنجم كرة قدم|as a football star
على شكل قمر|as a moon
كمغني أوبرا|as an opera singer
بقبعة طاهٍ|with a chef's hat
على شكل وردة|as a flower
كقبطان سفينة|as a ship's captain
على شكل حلزون|as a snail
كمذيع أخبار|as a newsreader
على شكل زرافة|as a giraffe
بابتسامة عملاقة|with a giant smile
كنجم سينما|as a film star
على شكل بومة|as an owl
كمستكشف|as an explorer
كمخترع|as an inventor
كمهرج سيرك|as a circus clown
على شكل سمكة|as a fish
كرسام مشهور|as a famous painter
`);

export const GESTURES = list(`
مع حركات يدين مبالغ فيها|with exaggerated hand gestures
مع رفع الحاجبين|with raised eyebrows
مع هز الرأس كثيراً|nodding a lot
مع ابتسامة واثقة|with a confident smile
مع الإشارة إلى الكاميرا|pointing at the camera
مع وقفات درامية|with dramatic pauses
مع ضحكة بعد كل جملة|laughing after each line
مع تصفيق خفيف|with light claps
مع النظر إلى الأعلى|looking upwards
مع اليد على الذقن|hand on chin
مع تكرار آخر كلمة|repeating the last word
بنبرة متحمسة|in an excited tone
مع الهمس أحياناً|whispering now and then
مع رفع الصوت فجأة|suddenly getting loud
مع رفع الإبهام|with thumbs up
مع ترتيب الشعر|fixing your hair
مع رفع الكتفين|with shrugs
مع العد على الأصابع|counting on your fingers
مع ابتسامة عريضة|grinning widely
بجدية تامة|totally seriously
مع حركة يد كالمايسترو|conducting like a maestro
مع النظر إلى الساعة|checking the time
مع اليدين على الخصر|hands on hips
مع إشارة «لحظة»|with a «one moment» gesture
مع رفع إصبع|with one finger raised
مع ابتسامة خجولة|with a shy smile
مع وجه متفاجئ|with a surprised face
مع التوقف للتفكير|stopping to think
مع حركات بطيئة|with slow movements
مع انحناءة في النهاية|with a bow at the end
`);
