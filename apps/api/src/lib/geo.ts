// Distances in metres on a flat-earth approximation, accurate to well under 1% across Mumbai.
const M_PER_DEG_LAT = 111_320;

function toXY(lat: number, lon: number, lat0: number): [number, number] {
  return [lon * M_PER_DEG_LAT * Math.cos((lat0 * Math.PI) / 180), lat * M_PER_DEG_LAT];
}

/** Shortest distance from a point to the segment a-b. */
export function distanceToSegmentM(
  lat: number, lon: number,
  aLat: number, aLon: number, bLat: number, bLon: number,
): number {
  const [px, py] = toXY(lat, lon, lat);
  const [ax, ay] = toXY(aLat, aLon, lat);
  const [bx, by] = toXY(bLat, bLon, lat);
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

export type Segment = { road_id: string; start_lat: number; start_lon: number; end_lat: number; end_lon: number };

/** Nearest road segment to a point, with its distance. */
export function nearestRoad<T extends Segment>(lat: number, lon: number, roads: T[]): { road: T; metres: number } | null {
  let best: { road: T; metres: number } | null = null;
  for (const road of roads) {
    const metres = distanceToSegmentM(lat, lon, road.start_lat, road.start_lon, road.end_lat, road.end_lon);
    if (!best || metres < best.metres) best = { road, metres };
  }
  return best;
}
