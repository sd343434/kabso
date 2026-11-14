import constellationIcon from '../../mobile/assets/ambassadors/constellation.webp';
import galaxyIcon from '../../mobile/assets/ambassadors/galaxy.webp';
import sparkIcon from '../../mobile/assets/ambassadors/spark.webp';
import starIcon from '../../mobile/assets/ambassadors/star.webp';
import { useApp } from './context';
import { isKey } from './i18n';

/**
 * D390 follow-up (owner 2026-11-14, «سفراء النجوم»): the ambassador levels as the panel shows them — the app's icons
 * (`apps/mobile/assets/ambassadors/`, PROVENANCE.md there; imported from the app, no copy, like the panel's fonts) and
 * the names شرارة / نجم / كوكبة / مجرّة of the four default codes SPARK / STAR / CONSTELLATION / GALAXY. An old default
 * code (BRONZE / SILVER / GOLD / DIAMOND, renamed by migration `20270520090000_ambassador_level_names`) reads as its
 * new level; any other code (a level the OWNER added) shows as it is, without an icon (CONVENTIONS §10.179.6).
 */
export const LEGACY_LEVEL_CODES: Readonly<Record<string, string>> = {
  BRONZE: 'SPARK',
  SILVER: 'STAR',
  GOLD: 'CONSTELLATION',
  DIAMOND: 'GALAXY',
};

const ICONS: Readonly<Record<string, string>> = {
  SPARK: sparkIcon,
  STAR: starIcon,
  CONSTELLATION: constellationIcon,
  GALAXY: galaxyIcon,
};

/** The level's known code: an old default code reads as its new one; any other code as itself. */
export function ambassadorLevelCode(code: string): string {
  return LEGACY_LEVEL_CODES[code] ?? code;
}

/** The icon of a default level (null for a level the OWNER added). */
export function ambassadorLevelIcon(code: string): string | null {
  return ICONS[ambassadorLevelCode(code)] ?? null;
}

/** The level's name in the panel's language (the code itself for a level the OWNER added). */
export function useAmbassadorLevelName(): (code: string) => string {
  const { t } = useApp();
  return (code) => {
    const key = `ambLevel${ambassadorLevelCode(code)}`;
    return isKey(key) ? t(key) : code;
  };
}

/** A level as a chip: the icon and the name in the level's colours (the code as a tooltip). */
export function AmbassadorLevelChip({ code }: { code: string }) {
  const nameOf = useAmbassadorLevelName();
  const known = ambassadorLevelCode(code);
  const icon = ambassadorLevelIcon(code);
  return (
    <span className={`amb-level amb-${known.toLowerCase()}`} title={code} data-amb-level-chip={known}>
      {icon && <img className="amb-level-icon" src={icon} alt="" />}
      {nameOf(code)}
    </span>
  );
}
