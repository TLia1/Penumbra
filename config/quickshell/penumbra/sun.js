.pragma library

// Sunrise and sunset for night light's schedule, worked out here rather than looked up: NOAA's
// approximation, within a minute or two away from the poles.

// times(date, latitude, longitude) → { rise, set } in minutes after the local midnight of `date`
// (this computer's time zone), or { polar: "day" } / { polar: "night" } when the sun doesn't set
// or rise that day. Latitude and longitude are in degrees, north and east positive.
function times(date, latitude, longitude) {
    const rad = Math.PI / 180;
    const day = Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - new Date(date.getFullYear(), 0, 1)) / 86400000);
    const year = 2 * Math.PI / 365 * (day + 0.5); // the fractional year, at noon
    const equation = 229.18 * (0.000075 + 0.001868 * Math.cos(year) - 0.032077 * Math.sin(year)
        - 0.014615 * Math.cos(2 * year) - 0.040849 * Math.sin(2 * year));
    const declination = 0.006918 - 0.399912 * Math.cos(year) + 0.070257 * Math.sin(year)
        - 0.006758 * Math.cos(2 * year) + 0.000907 * Math.sin(2 * year)
        - 0.002697 * Math.cos(3 * year) + 0.00148 * Math.sin(3 * year);
    // The sun's centre 0.833° below the horizon: refraction and its radius.
    const cosHour = Math.cos(90.833 * rad) / (Math.cos(latitude * rad) * Math.cos(declination))
        - Math.tan(latitude * rad) * Math.tan(declination);
    if (cosHour > 1)
        return { polar: "night" };
    if (cosHour < -1)
        return { polar: "day" };
    const hour = Math.acos(cosHour) / rad;
    // Solar noon in UTC minutes, then in local time.
    const noon = 720 - 4 * longitude - equation - new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12).getTimezoneOffset();
    const wrap = m => (Math.round(m) % 1440 + 1440) % 1440;
    return { rise: wrap(noon - 4 * hour), set: wrap(noon + 4 * hour) };
}

// "21:30" → 1290, or -1 when it isn't a time.
function minutes(text) {
    const m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(text.trim());
    return m ? Number(m[1]) * 60 + Number(m[2]) : -1;
}

// 1290 → "21:30".
function clock(minutes) {
    const m = (Math.round(minutes) % 1440 + 1440) % 1440;
    return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
}

// Whether `now` (minutes) falls between `from` and `to`, across midnight when `to` comes first.
function between(now, from, to) {
    return from <= to ? now >= from && now < to : now >= from || now < to;
}

// zone1970.tab's coordinates, "+4852+00220" or "+404251-0740023" → { latitude, longitude }.
function coordinates(text) {
    const m = /^([+-]\d{2})(\d{2})(\d{2})?([+-]\d{3})(\d{2})(\d{2})?$/.exec(text);
    if (!m)
        return null;
    const part = (d, mm, ss) => (d.startsWith("-") ? -1 : 1) * (Math.abs(Number(d)) + Number(mm) / 60 + Number(ss ?? 0) / 3600);
    return { latitude: part(m[1], m[2], m[3]), longitude: part(m[4], m[5], m[6]) };
}
