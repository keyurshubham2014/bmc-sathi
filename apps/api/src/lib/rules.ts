// Rules used when nothing has read a complaint's text: by the pipeline's rules-only mode and by intake.
/** Default severity (1 to 5) when nothing has read the description. */
export const SEVERITY: Record<string, number> = {
  "Road cave-in": 5, "Open or broken manhole": 5, "Waterlogging": 4,
  "Choked drain / nullah overflow": 3, "Pothole": 3, "Broken paver blocks": 2,
};
/** Vague categories are treated as the most common road issue. */
export const cleanCategory = (reported: string) => (reported in SEVERITY ? reported : "Pothole");

/** The longest known road name that appears in the text. */
export function mentionedRoad(text: string, roadNames: string[]): string | null {
  const t = text.toLowerCase();
  return roadNames.find((n) => t.includes(n.toLowerCase())) ?? null;
}
