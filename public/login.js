const config = window.ROTA_CONFIG || {};
const client = config.supabaseUrl && config.supabaseAnonKey && window.supabase ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey) : null;
const form = document.querySelector("#auth-form");
const message = document.querySelector("#auth-message");
const button = document.querySelector("#login-button");

async function authenticate(signup = false) {
  const values = new FormData(form);
  const email = String(values.get("email") || "").trim().toLowerCase();
  const password = String(values.get("password") || "");
  if (!client) throw new Error("Supabase yapılandırması yüklenemedi.");
  if (password.length < 6) throw new Error("Şifre en az 6 karakter olmalı.");
  const result = signup ? await client.auth.signUp({ email, password, options: { emailRedirectTo: `${location.origin}/plan` } }) : await client.auth.signInWithPassword({ email, password });
  if (result.error) throw result.error;
  if (!result.data.session) return false;
  location.replace("/plan");
  return true;
}

form.addEventListener("submit", async event => { event.preventDefault(); button.disabled = true; button.textContent = "Giriş yapılıyor…"; message.textContent = ""; try { await authenticate(); } catch (error) { message.textContent = error.message || "Giriş yapılamadı."; } finally { button.disabled = false; button.textContent = "Giriş yap"; } });
document.querySelector("#signup-button").addEventListener("click", async () => { message.textContent = ""; try { if (!await authenticate(true)) message.textContent = "Hesap oluşturuldu. E-postanı doğrulayıp giriş yap."; } catch (error) { message.textContent = error.message; } });
document.querySelector("#demo-button").addEventListener("click", () => { sessionStorage.setItem("rota-demo", "true"); location.href = "/plan"; });
if (client) { const { data } = await client.auth.getSession(); if (data.session) location.replace("/plan"); }
