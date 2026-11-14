import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useT } from './context';
import type { ChatState, GiftLine } from './feed';

/** Line breaks are refused in chat text (CONVENTIONS §10.11): typed or pasted ones become spaces. */
const LINE_BREAKS = new RegExp('[\\r\\n\\u2028\\u2029]', 'g');

/** The live side panel: the chat (read + send) and the incoming gifts (D247). */
export function SidePanel({
  chat,
  gifts,
  giftNames,
  onSend,
}: {
  chat: ChatState;
  gifts: readonly GiftLine[];
  giftNames: ReadonlyMap<string, { name: string; imageUrl: string | null }>;
  onSend: (text: string) => void;
}) {
  const { t } = useT();
  const [tab, setTab] = useState<'chat' | 'gifts'>('chat');
  const [text, setText] = useState('');
  const list = useRef<HTMLOListElement>(null);
  const [seenGifts, setSeenGifts] = useState(0);
  const unseen = tab === 'gifts' ? 0 : Math.max(0, gifts.length - seenGifts);

  useEffect(() => {
    if (tab === 'gifts') setSeenGifts(gifts.length);
  }, [tab, gifts.length]);
  useEffect(() => {
    const el = list.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [chat.lines.length, tab]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const v = text.trim();
    if (!v) return;
    onSend(v);
    setText('');
  };

  return (
    <aside className="side card" aria-label={t('chatTitle')}>
      <div className="tabs" role="tablist">
        <button role="tab" aria-selected={tab === 'chat'} className={tab === 'chat' ? 'on' : ''} onClick={() => setTab('chat')}>
          {t('tabChat')}
        </button>
        <button role="tab" aria-selected={tab === 'gifts'} className={tab === 'gifts' ? 'on' : ''} onClick={() => setTab('gifts')} data-testid="tab-gifts">
          {t('tabGifts')}
          {unseen > 0 && <span className="count">{unseen}</span>}
        </button>
      </div>
      {tab === 'chat' ? (
        <>
          {!chat.enabled && <div className="alert info small">{t('chatClosed')}</div>}
          <ol className="chat" ref={list} data-testid="chat" aria-live="polite">
            {chat.lines.length === 0 && <li className="muted empty">{t('chatEmpty')}</li>}
            {chat.lines.map((l) =>
              l.kind === 'join' ? (
                <li key={l.id} className="join">
                  <bdi>{l.user.displayName}</bdi> {t(l.gender === 'MALE' ? 'joinedM' : l.gender === 'FEMALE' ? 'joinedF' : 'joinedN')}
                </li>
              ) : (
                <li key={l.id} className={`msg ${l.pending ? 'pending' : ''} ${l.failed ? 'failed' : ''}`}>
                  <span className="who">
                    <bdi>{l.message.author.displayName}</bdi>
                    {l.message.authorRole === 'HOST' && <span className="tag">{t('chatHost')}</span>}
                  </span>
                  <span className="text">
                    <bdi>{l.message.kind === 'VOICE' ? t('chatVoice') : l.message.kind === 'IMAGE' ? t('chatImage') : l.message.text}</bdi>
                  </span>
                  {l.failed && <span className="failed-note">{t('chatFailed')}</span>}
                </li>
              ),
            )}
          </ol>
          <form className="chat-send" onSubmit={submit}>
            <input
              value={text}
              maxLength={200}
              placeholder={t('chatPlaceholder')}
              aria-label={t('chatPlaceholder')}
              onChange={(e) => setText(e.target.value.replace(LINE_BREAKS, ' '))}
              data-testid="chat-input"
            />
            <button className="btn primary" disabled={!text.trim()}>
              {t('chatSend')}
            </button>
          </form>
        </>
      ) : (
        <ol className="gifts" data-testid="gifts">
          {gifts.length === 0 && <li className="muted empty">{t('giftsEmpty')}</li>}
          {gifts.map(({ id, gift }) => {
            const info = giftNames.get(gift.giftCode);
            const image = gift.imageUrl ?? info?.imageUrl ?? null;
            const count = gift.combo && gift.combo.count > 1 ? gift.combo.quantity : gift.quantity;
            return (
              <li key={id} className="gift">
                {image ? <img src={image} alt="" width={36} height={36} /> : <span className="gift-ph" aria-hidden="true">🎁</span>}
                <span className="gift-body">
                  <bdi className="who">{gift.sender.displayName}</bdi> {t('giftSent')} <bdi className="gift-name">{info?.name ?? gift.giftCode}</bdi>
                  <span className="gift-qty"> ×{count}</span>
                </span>
                <span className="gift-coins">{t('giftCoins', { n: gift.totalCoins.toLocaleString() })}</span>
              </li>
            );
          })}
        </ol>
      )}
    </aside>
  );
}
