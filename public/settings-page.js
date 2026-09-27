import { requireSession, setupShell, demoMode } from "./shared.js";
const { user }=await requireSession(); setupShell("settings",user); document.querySelector("#account-info").textContent=demoMode()?"Demo modundasın; veriler kalıcı değildir.":`${user.name} hesabıyla Supabase oturumu açık.`;
