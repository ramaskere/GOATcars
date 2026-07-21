// Copiá este archivo como config.js (Supabase → Project Settings → API).

window.APP_SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
window.APP_SUPABASE_ANON_KEY = "TU-ANON-KEY";

// Login: la app muestra un formulario si no hay sesión guardada. Opcional:
// - APP_SUPABASE_LOGIN_EMAIL: solo prellenar el email en el formulario.
// - APP_SUPABASE_EMAIL + APP_SUPABASE_PASSWORD: entrar solo al cargar (sin escribir en el formulario).
// No subas contraseña a repos públicos.
window.APP_SUPABASE_LOGIN_EMAIL = "";
window.APP_SUPABASE_EMAIL = "";
// Nombre exacto: PASSWORD con la letra O, no PASSW0RD con el número 0.
window.APP_SUPABASE_PASSWORD = "";

// La app se conecta al cargar y escucha cambios en vivo (Realtime): en Supabase activá Realtime para
// sales, cash_movements, services, crm_settings, pending_receivables, invoices, pipeline_leads y salespeople (Database → Publications).

// ManyChat (opcional) — abrir chat desde Pipeline.
window.APP_MANYCHAT_FB_PREFIX = "";
