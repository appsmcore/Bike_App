import 'leaflet/dist/leaflet.css';
import './style.css';
import L from 'leaflet';
import { calculateRoute } from './routing.js';

const map = L.map('map').setView([46.4983, 11.3548], 12);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '&copy; OpenStreetMap',
  maxZoom: 19,
}).addTo(map);

const waypoints = [];
const markers = [];
let routeLine = null;

const el = {
  bikeType: document.getElementById('bikeType'),
  flexible: document.getElementById('flexible'),
  distance: document.getElementById('distance'),
  climb: document.getElementById('climb'),
  engine: document.getElementById('engine'),
  status: document.getElementById('status'),
  error: document.getElementById('error'),
  undo: document.getElementById('undo'),
  clear: document.getElementById('clear'),
  route: document.getElementById('route'),
};

function setStatus(text) {
  el.status.textContent = text || '';
}

function setError(text) {
  el.error.textContent = text || '';
}

function redrawMarkers() {
  markers.forEach((m) => m.remove());
  markers.length = 0;
  waypoints.forEach((p, i) => {
    const m = L.circleMarker(p, {
      radius: 8,
      color: '#fff',
      weight: 2,
      fillColor: i === 0 ? '#1A7A4C' : i === waypoints.length - 1 ? '#C62828' : '#121816',
      fillOpacity: 1,
    }).bindTooltip(`${i + 1}`, { permanent: true, direction: 'top' });
    m.addTo(map);
    markers.push(m);
  });
}

function clearRouteLine() {
  if (routeLine) {
    routeLine.remove();
    routeLine = null;
  }
}

map.on('click', (e) => {
  waypoints.push([e.latlng.lat, e.latlng.lng]);
  redrawMarkers();
  setError('');
  if (waypoints.length >= 2) {
    void runRoute();
  }
});

el.undo.addEventListener('click', () => {
  waypoints.pop();
  redrawMarkers();
  clearRouteLine();
  el.distance.textContent = '—';
  el.climb.textContent = '—';
  el.engine.textContent = '—';
  if (waypoints.length >= 2) void runRoute();
});

el.clear.addEventListener('click', () => {
  waypoints.length = 0;
  redrawMarkers();
  clearRouteLine();
  el.distance.textContent = '—';
  el.climb.textContent = '—';
  el.engine.textContent = '—';
  setStatus('');
  setError('');
});

el.route.addEventListener('click', () => void runRoute());
el.bikeType.addEventListener('change', () => {
  if (waypoints.length >= 2) void runRoute();
});
el.flexible.addEventListener('change', () => {
  if (waypoints.length >= 2) void runRoute();
});

async function runRoute() {
  if (waypoints.length < 2) {
    setError('Add at least two waypoints');
    return;
  }
  setError('');
  setStatus('Calculating…');
  el.route.disabled = true;
  try {
    const result = await calculateRoute({
      waypoints,
      bikeType: el.bikeType.value,
      flexible: el.flexible.checked,
    });
    clearRouteLine();
    routeLine = L.polyline(result.geometry, {
      color: '#1A7A4C',
      weight: 5,
    }).addTo(map);
    map.fitBounds(routeLine.getBounds(), { padding: [40, 40] });
    el.distance.textContent = `${result.distanceKm.toFixed(1)} km`;
    el.climb.textContent = `${result.elevationM} m`;
    el.engine.textContent = result.profileUsed;
    setStatus(`OK · ${result.geometry.length} points`);
  } catch (err) {
    clearRouteLine();
    setStatus('');
    setError(err?.message || String(err));
  } finally {
    el.route.disabled = false;
  }
}
