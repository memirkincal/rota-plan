import { requireSession, setupShell, selectRows, demoMode, safe, apiHeaders, clock, iso } from "./shared.js";

const { session, user } = await requireSession();
setupShell("team", user);
let teams = [];
let memberRows = [];
let profiles = new Map();

document.querySelector("#meeting-form").addEventListener("submit", async event => {
  event.preventDefault();
  const output = document.querySelector("#meeting-slots");
  output.textContent = "Hesaplanıyor…";
  try {
    const duration = Number(new FormData(event.currentTarget).get("duration_minutes"));
    if (demoMode()) {
      output.innerHTML = `<div class="suggestion"><b>${nextMonday(0)} · 10:00–${clock(600 + duration)}</b></div>`;
      return;
    }
    const ids = [...new Set(memberRows.map(member => member.user_id))];
    const rows = ids.length ? await selectRows("weekly_blocks", query => query.in("user_id", ids)) : [];
    const calendars = ids.map(id => ({
      blocks: rows.filter(block => block.user_id === id).flatMap(block =>
        Array.from({ length: 7 }, (_, day) => Number(block.weekday) === day
          ? [{ date: nextMonday(day), start_time: block.start_time, end_time: block.end_time }]
          : [])
      )
    }));
    const response = await fetch("/api/meeting.rb", {
      method: "POST",
      headers: apiHeaders(session),
      body: JSON.stringify({ week_start: nextMonday(0), duration_minutes: duration, calendars, day_start: 480, day_end: 1320 })
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error);
    output.innerHTML = result.slots.slice(0, 4).map(slot =>
      `<div class="suggestion"><b>${safe(slot.date)} · ${clock(slot.start)}–${clock(slot.end)}</b></div>`
    ).join("") || '<div class="empty-state">Uygun boşluk bulunamadı.</div>';
  } catch (error) {
    output.innerHTML = `<div class="empty-state">${safe(error.message)}</div>`;
  }
});

function nextMonday(offset) {
  const date = new Date();
  date.setDate(date.getDate() - ((date.getDay() + 6) % 7) + offset);
  return iso(date);
}

async function loadTeams() {
  try {
    teams = demoMode() ? [{ id: "demo", name: "Medya Ofisi Demo" }] : await selectRows("teams", query => query.order("created_at"));
    memberRows = demoMode() ? [{ team_id: "demo", user_id: user.id, role: "lead" }]
      : teams.length ? await selectRows("team_members", query => query.in("team_id", teams.map(team => team.id))) : [];
    const ids = [...new Set(memberRows.map(member => member.user_id))];
    const rows = ids.length ? await selectRows("profiles", query => query.in("id", ids)) : [];
    profiles = new Map(rows.map(profile => [profile.id, profile]));
    document.querySelector("#team-list").innerHTML = teams.length ? teams.map(team =>
      `<section><h4>${safe(team.name)}</h4>${memberRows.filter(member => member.team_id === team.id).map(member => {
        const name = profiles.get(member.user_id)?.display_name || "Ekip üyesi";
        return `<div class="member-row"><span>${safe(name[0])}</span><div class="member-info"><b>${safe(name)}</b><small>Takvim ekip üyelerine görünür</small></div><span class="role">${safe(member.role)}</span></div>`;
      }).join("")}</section>`
    ).join("") : '<div class="empty-state">Henüz bir ekibe üye değilsin.</div>';
  } catch (error) {
    document.querySelector("#page-message").textContent = error.message;
  }
}

await loadTeams();
