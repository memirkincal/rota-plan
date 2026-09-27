export const demoMode = () => sessionStorage.getItem("rota-demo") === "true";
export const config = window.ROTA_CONFIG || {};
export const supabaseClient = config.supabaseUrl && config.supabaseAnonKey && window.supabase ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey) : null;
export async function requireSession() {
  if (demoMode()) return { session: null, user: { id: "demo-user", name: "Demo kullanıcı", role: "Demo planı" } };
  if (!supabaseClient) return redirect();
  const { data, error } = await supabaseClient.auth.getSession();
  if (error || !data.session) return redirect();
  const email = data.session.user.email || "kullanici@example.com";
  return { session: data.session, user: { id: data.session.user.id, name: email.split("@")[0], role: "Kişisel plan" } };
}
function redirect() { location.replace("/"); return new Promise(() => {}); }
export function setupShell(active, user) {
  document.querySelector(`[data-page="${active}"]`)?.classList.add("active");
  document.querySelector("#user-name").textContent = user.name; document.querySelector("#user-role").textContent = user.role; document.querySelector("#user-avatar").textContent = user.name[0].toUpperCase();
  document.querySelector("#mobile-menu")?.addEventListener("click", () => document.querySelector(".sidebar").classList.toggle("open"));
  document.querySelector("#logout-button")?.addEventListener("click", logout);
}
export async function logout() { sessionStorage.removeItem("rota-demo"); await supabaseClient?.auth.signOut(); location.replace("/"); }
export async function selectRows(table, configure = query => query) { if (demoMode()) return []; const { data, error } = await configure(supabaseClient.from(table).select("*")); if (error) throw error; return data; }
export async function insertRow(table, row) { if (demoMode()) return { ...row, id: crypto.randomUUID() }; const { data, error } = await supabaseClient.from(table).insert(row).select().single(); if (error) throw error; return data; }
export async function updateRows(table, values, configure = query => query) { if (demoMode()) return; const { error } = await configure(supabaseClient.from(table).update(values)); if (error) throw error; }
export async function upsertRow(table, row, conflict = "id") { if (demoMode()) return row; const { data, error } = await supabaseClient.from(table).upsert(row, { onConflict: conflict }).select().single(); if (error) throw error; return data; }
export function apiHeaders(session) { return { "Content-Type": "application/json", ...(session ? { Authorization: `Bearer ${session.access_token}` } : {}) }; }
export const mondayOf = (date = new Date()) => { const result = new Date(date); result.setDate(result.getDate() - ((result.getDay() + 6) % 7)); result.setHours(0, 0, 0, 0); return result; };
export const iso = date => `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,"0")}-${String(date.getDate()).padStart(2,"0")}`;
export const dateAt = (start, day) => { const result = new Date(start); result.setDate(result.getDate() + day); return result; };
export const minutes = time => { const [hour, minute] = time.slice(0, 5).split(":").map(Number); return hour * 60 + minute; };
export const clock = value => `${String(Math.floor(value / 60)).padStart(2,"0")}:${String(value % 60).padStart(2,"0")}`;
export const safe = text => String(text).replace(/[&<>\"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '\"': "&quot;" })[char]);
