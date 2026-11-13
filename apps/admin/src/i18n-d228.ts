/** D228 «محرك مؤثرات الكاميرا»: the app's camera effects engine (DeepAR or the free one), merged into i18n.ts. */
export const AR_D228 = {
  fxTitle: 'محرك مؤثرات الكاميرا (التطبيق، أندرويد)',
  fxIntro:
    'يحدد المحرك الذي يشغّل مؤثرات «السحر» على كاميرا المضيف المنشورة. يصل التغيير إلى كل مضيف عند فتح شاشة البث التالية. يُسجَّل في سجل التدقيق.',
  fxDeepar: 'DeepAR (الحالي): تمويه الخلفية — يحتاج ترخيصاً ويُحسب بعدد المستخدمين الشهري',
  fxFree: 'المجاني على الجهاز (ML Kit + MediaPipe): تمويه الخلفية وتجميل الوجه — بلا ترخيص',
  fxFreeNote:
    'تجريبي للمقارنة: لم يُختبر أداؤه ولا جودته على هاتف حقيقي بعد. يُنزَّل نموذج الوجه (3.6 ميغابايت) على الهاتف عند أول استخدام للتجميل.',
  fxSave: 'حفظ المحرك',
};

export const EN_D228: Record<keyof typeof AR_D228, string> = {
  fxTitle: 'Camera effects engine (app, Android)',
  fxIntro:
    "Picks the engine that runs Magic's effects on the host's published camera. Every host gets the change the next time they open the go-live screen. Kept in the audit log.",
  fxDeepar: 'DeepAR (current): background blur — needs a licence, billed per monthly active user',
  fxFree: 'Free, on the device (ML Kit + MediaPipe): background blur and face beauty — no licence',
  fxFreeNote:
    'Beta, for comparison: its speed and quality have not been tested on a real phone yet. The face model (3.6 MB) downloads to the phone the first time beauty is used.',
  fxSave: 'Save engine',
};
