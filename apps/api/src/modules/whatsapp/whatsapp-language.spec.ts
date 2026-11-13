import { describe, expect, it } from 'vitest';
import { parseWebhook } from './whatsapp-core.js';
import {
  effectiveLanguages,
  isWaLanguage,
  LANGUAGE_BUTTON_IDS,
  languageOfAnswer,
  languageQuestionPayload,
  sortLanguages,
  speaks,
  teamLanguagesOf,
  WA_LANGUAGES,
} from './whatsapp-language.js';

/** D388 (CONVENTIONS §10.177): «سؤال اللغة» — the question, the answers and the staff languages. */
describe('WhatsApp language question (D388)', () => {
  it('the question: two reply buttons inside Meta limits', () => {
    const p = languageQuestionPayload('966500000001') as {
      to: string;
      type: string;
      interactive: {
        type: string;
        body: { text: string };
        action: { buttons: { type: string; reply: { id: string; title: string } }[] };
      };
    };
    expect(p.to).toBe('966500000001');
    expect(p.type).toBe('interactive');
    expect(p.interactive.type).toBe('button');
    expect(p.interactive.body.text.length).toBeLessThanOrEqual(1024);
    expect(p.interactive.action.buttons.map((b) => b.reply.id)).toEqual(['kabso_lang_ar', 'kabso_lang_en']);
    for (const b of p.interactive.action.buttons) expect(b.reply.title.length).toBeLessThanOrEqual(20);
  });

  it('answers: the buttons by id, the typed words, nothing else', () => {
    expect(languageOfAnswer(LANGUAGE_BUTTON_IDS.AR, 'whatever')).toBe('AR');
    expect(languageOfAnswer('kabso_lang_en', null)).toBe('EN');
    for (const w of ['عربي', ' العربية ', 'العربيه', 'Arabic', 'ARABIC'])
      expect(languageOfAnswer(null, w)).toBe('AR');
    for (const w of ['English', 'english ', 'إنجليزي', 'انجليزي', 'الإنجليزية', 'انكليزي'])
      expect(languageOfAnswer(null, w)).toBe('EN');
    for (const w of ['مرحبا', 'I speak English', 'عربي من فضلك', '', 'x'.repeat(50)])
      expect(languageOfAnswer(null, w)).toBeNull();
    expect(languageOfAnswer('some_other_button', 'Yes')).toBeNull();
    expect(languageOfAnswer(null, null)).toBeNull();
  });

  it('staff languages: none set = both, catalogue order', () => {
    expect(WA_LANGUAGES).toEqual(['AR', 'EN']);
    expect(isWaLanguage('EN')).toBe(true);
    expect(isWaLanguage('FR')).toBe(false);
    expect(sortLanguages(['EN', 'AR', 'EN'])).toEqual(['AR', 'EN']);
    expect(effectiveLanguages(undefined)).toEqual(['AR', 'EN']);
    expect(effectiveLanguages([])).toEqual(['AR', 'EN']);
    expect(effectiveLanguages(['EN'])).toEqual(['EN']);
    expect(teamLanguagesOf(undefined)).toEqual({ languages: ['AR', 'EN'], isDefault: true });
    expect(teamLanguagesOf(['AR'])).toEqual({ languages: ['AR'], isDefault: false });
    expect(speaks(undefined, 'AR')).toBe(true);
    expect(speaks(['EN'], 'AR')).toBe(false);
    expect(speaks(['EN'], 'EN')).toBe(true);
  });

  it('the webhook keeps the tapped button id (reply buttons and quick-reply buttons)', () => {
    const now = new Date('2026-11-13T10:00:00Z');
    const ts = String(Math.floor(now.getTime() / 1000));
    const body = {
      object: 'whatsapp_business_account',
      entry: [
        {
          changes: [
            {
              field: 'messages',
              value: {
                metadata: { phone_number_id: '5550001' },
                contacts: [{ profile: { name: 'سارة' }, wa_id: '966512345678' }],
                messages: [
                  {
                    from: '966512345678',
                    id: 'wamid.B1',
                    timestamp: ts,
                    type: 'interactive',
                    interactive: {
                      type: 'button_reply',
                      button_reply: { id: 'kabso_lang_ar', title: 'العربية' },
                    },
                  },
                  {
                    from: '966512345678',
                    id: 'wamid.B2',
                    timestamp: ts,
                    type: 'button',
                    button: { text: 'English', payload: 'kabso_lang_en' },
                  },
                  { from: '966512345678', id: 'wamid.T1', timestamp: ts, type: 'text', text: { body: 'hi' } },
                ],
              },
            },
          ],
        },
      ],
    };
    const events = parseWebhook(body, now);
    expect(events.map((e) => (e.kind === 'message' ? [e.type, e.body, e.replyId] : e.kind))).toEqual([
      ['INTERACTIVE', 'العربية', 'kabso_lang_ar'],
      ['INTERACTIVE', 'English', 'kabso_lang_en'],
      ['TEXT', 'hi', null],
    ]);
  });
});
