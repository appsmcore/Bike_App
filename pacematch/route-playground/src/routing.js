const GH_KEY = import.meta.env.VITE_GH_API_KEY?.trim() || '';
const ORS_KEY = import.meta.env.VITE_ORS_API_KEY?.trim() || '';

function customModel(bikeType, flexible) {
  if (flexible) {
    return {
      distance_influence: 90,
      priority: [{ if: 'road_class == STEPS', multiply_by: '0' }],
    };
  }
  if (bikeType === 'road') {
    return {
      distance_influence: 70,
      priority: [
        { if: 'road_class == CYCLEWAY', multiply_by: '6' },
        {
          if: 'road_class == RESIDENTIAL || road_class == LIVING_STREET || road_class == SERVICE',
          multiply_by: '1.4',
        },
        {
          if: 'road_class == PRIMARY || road_class == TRUNK || road_class == MOTORWAY',
          multiply_by: '0.05',
        },
        { if: 'road_class == SECONDARY', multiply_by: '0.15' },
        { if: 'road_class == TERTIARY', multiply_by: '0.35' },
        {
          if: 'surface == UNPAVED || surface == GRAVEL || surface == DIRT || surface == GROUND || surface == COMPACTED || surface == FINE_GRAVEL || surface == SAND || surface == GRASS',
          multiply_by: '0.08',
        },
        { if: 'road_class == STEPS', multiply_by: '0' },
      ],
    };
  }
  return {
    distance_influence: 60,
    priority: [
      {
        if: 'surface == GRAVEL || surface == DIRT || surface == GROUND || surface == UNPAVED || surface == COMPACTED || surface == FINE_GRAVEL || surface == SAND || surface == GRASS',
        multiply_by: '5',
      },
      { if: 'road_class == TRACK || road_class == PATH', multiply_by: '4' },
      { if: 'road_class == CYCLEWAY', multiply_by: '1.2' },
      {
        if: 'surface == ASPHALT || surface == CONCRETE || surface == PAVED',
        multiply_by: '0.12',
      },
      {
        if: 'road_class == PRIMARY || road_class == SECONDARY || road_class == TRUNK || road_class == MOTORWAY',
        multiply_by: '0.05',
      },
      { if: 'road_class == STEPS', multiply_by: '0' },
    ],
  };
}

function sanitizeAscent(ascentM, distanceKm, elevations = []) {
  const api = Math.round(ascentM || 0);
  const fromSamples = ascentFromSamples(elevations);
  let chosen;
  if (api > 0 && fromSamples > 0) {
    chosen =
      api > 8000 && api > fromSamples * 2.5
        ? fromSamples
        : Math.max(api, fromSamples);
  } else {
    chosen = api > 0 ? api : fromSamples;
  }
  const byDistance =
    distanceKm <= 0
      ? 8000
      : Math.min(12000, Math.max(300, Math.round(distanceKm * 250)));
  return Math.min(chosen, byDistance);
}

function smoothElev(raw, window = 5) {
  if (raw.length < 3) return [...raw];
  const w = window % 2 === 1 ? window : window + 1;
  const half = Math.floor(w / 2);
  return raw.map((_, i) => {
    let sum = 0;
    let n = 0;
    for (let j = i - half; j <= i + half; j++) {
      if (j < 0 || j >= raw.length) continue;
      sum += raw[j];
      n++;
    }
    return sum / n;
  });
}

function ascentFromSamples(elevations) {
  if (!elevations || elevations.length < 2) return 0;
  const s = smoothElev(elevations);
  let gain = 0;
  for (let i = 1; i < s.length; i++) {
    const d = s[i] - s[i - 1];
    if (d > 0) gain += d;
  }
  return Math.round(gain);
}

function elevFromCoords(coords) {
  return coords.filter((c) => c.length > 2).map((c) => Number(c[2]));
}

function orsProfile(bikeType, flexible) {
  if (flexible) return 'cycling-regular';
  if (bikeType === 'road') return 'cycling-road';
  return 'cycling-mountain';
}

async function routeGraphHopper(waypoints, bikeType, flexible, useCustom) {
  const body = {
    profile: 'bike',
    points: waypoints.map(([lat, lng]) => [lng, lat]),
    locale: 'en',
    instructions: false,
    elevation: true,
    points_encoded: false,
  };
  if (useCustom) {
    body['ch.disable'] = true;
    body.custom_model = customModel(bikeType, flexible);
  }

  const res = await fetch(
    `https://graphhopper.com/api/1/route?key=${encodeURIComponent(GH_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body),
    },
  );
  const json = await res.json();
  if (!res.ok) {
    throw new Error(json.message || `GraphHopper ${res.status}`);
  }
  const path = json.paths?.[0];
  if (!path) throw new Error('No route found');

  const coords = path.points?.coordinates || path.points || [];
  const geometry = coords.map((c) => [c[1], c[0]]);
  const distanceKm = (path.distance || 0) / 1000;
  const elev = elevFromCoords(coords);
  return {
    geometry,
    distanceKm,
    elevationM: sanitizeAscent(path.ascend || path.ascent || 0, distanceKm, elev),
    profileUsed: useCustom
      ? `graphhopper · ${flexible ? 'any-surface' : bikeType}`
      : 'graphhopper · bike (free tier — no custom rules)',
  };
}

async function routeOrs(waypoints, bikeType, flexible) {
  const profile = orsProfile(bikeType, flexible);
  const preference = flexible ? 'shortest' : 'recommended';
  const body = {
    coordinates: waypoints.map(([lat, lng]) => [lng, lat]),
    elevation: true,
    instructions: false,
    preference,
    units: 'm',
    geometry_simplify: false,
    extra_info: ['surface', 'waytype'],
    options:
      bikeType === 'road' && !flexible
        ? {
            avoid_features: ['steps', 'ferries', 'fords'],
            profile_params: { weightings: { steepness_difficulty: 0 } },
          }
        : { avoid_features: ['steps', 'ferries'] },
    alternative_routes: flexible
      ? undefined
      : { target_count: 3, share_factor: 0.4, weight_factor: 2.0 },
  };

  const res = await fetch(
    `https://api.openrouteservice.org/v2/directions/${profile}/geojson`,
    {
      method: 'POST',
      headers: {
        Authorization: ORS_KEY,
        'Content-Type': 'application/json',
        Accept: 'application/json, application/geo+json',
      },
      body: JSON.stringify(body),
    },
  );
  const json = await res.json();
  if (!res.ok) {
    const msg = json.error?.message || json.message || `ORS ${res.status}`;
    throw new Error(msg);
  }
  const feature = json.features?.[0];
  if (!feature) throw new Error('No route found');
  const coords = feature.geometry.coordinates;
  const geometry = coords.map((c) => [c[1], c[0]]);
  const summary = feature.properties?.summary || {};
  const distanceKm = (summary.distance || 0) / 1000;
  const elev = elevFromCoords(coords);
  return {
    geometry,
    distanceKm,
    elevationM: sanitizeAscent(summary.ascent || 0, distanceKm, elev),
    profileUsed: `ors · ${profile} · ${preference}`,
  };
}

export async function calculateRoute({ waypoints, bikeType, flexible }) {
  if (!GH_KEY && !ORS_KEY) {
    throw new Error(
      'Set VITE_GH_API_KEY and/or VITE_ORS_API_KEY in route-playground/.env',
    );
  }

  if (GH_KEY) {
    try {
      return await routeGraphHopper(waypoints, bikeType, flexible, true);
    } catch (e) {
      const msg = String(e.message || e).toLowerCase();
      const freeBlocked =
        msg.includes('flexible mode') ||
        msg.includes('custom_model') ||
        msg.includes('free package');
      if (freeBlocked) {
        try {
          return await routeGraphHopper(waypoints, bikeType, flexible, false);
        } catch (_) {
          /* fall through */
        }
      } else if (!ORS_KEY) {
        throw e;
      }
    }
  }

  if (!ORS_KEY) {
    throw new Error('GraphHopper failed and no ORS_API_KEY set');
  }
  return routeOrs(waypoints, bikeType, flexible);
}
