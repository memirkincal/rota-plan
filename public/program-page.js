import { requireSession, setupShell, selectRows, insertRow, upsertRow, demoMode, safe } from "./shared.js";

const { user } = await requireSession();
setupShell("program", user);
const days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
let blocks = [];
const dialog = document.querySelector("#block-dialog");

function render() {
  document.querySelector("#program-list").innerHTML = blocks.length
    ? blocks.map(block => `<div class="program-row"><div><b>${safe(block.title)}</b><small>${days[block.weekday]} · ${block.start_time.slice(0, 5)}–${block.end_time.slice(0, 5)}</small></div><span class="tag">${safe(block.block_type)}</span></div>`).join("")
    : '<div class="empty-state">Henüz blok yok.</div>';
}

document.querySelector("#new-block").addEventListener("click", () => dialog.showModal());
document.querySelector("#close-dialog").addEventListener("click", () => dialog.close());
document.querySelector("#block-form").addEventListener("submit", async event => {
  event.preventDefault();
  const values = Object.fromEntries(new FormData(event.currentTarget));
  if (values.end_time <= values.start_time) {
    document.querySelector("#page-message").textContent = "Bitiş saati başlangıçtan sonra olmalı.";
    return;
  }
  try {
    const row = { ...values, user_id: user.id, weekday: Number(values.weekday), repeats_weekly: true };
    blocks.push(await insertRow("weekly_blocks", row));
    dialog.close(); event.currentTarget.reset(); render();
  } catch (error) { document.querySelector("#page-message").textContent = error.message; }
});
document.querySelector("#availability-form").addEventListener("submit", async event => {
  event.preventDefault();
  const values = new FormData(event.currentTarget);
  if (values.get("day_end") <= values.get("day_start")) {
    document.querySelector("#page-message").textContent = "Bitiş saati başlangıçtan sonra olmalı.";
    return;
  }
  try {
    await upsertRow("profiles", { id: user.id, display_name: user.name, day_start: values.get("day_start"), day_end: values.get("day_end") });
    document.querySelector("#page-message").textContent = "Planlama aralığı kaydedildi.";
  } catch (error) { document.querySelector("#page-message").textContent = error.message; }
});

async function loadBlocks() {
  try {
    blocks = demoMode() ? [{ title: "Yazılım Mühendisliği", block_type: "lesson", weekday: 0, start_time: "09:00", end_time: "11:00" }]
      : await selectRows("weekly_blocks", query => query.order("weekday").order("start_time"));
    render();
  } catch (error) { document.querySelector("#page-message").textContent = error.message; }
}

await loadBlocks();
