/* Fixed readers and explicit guarded student submissions execute in the official dashboard.
 * No token, credentials, browser storage or arbitrary URL is exposed locally.
 */
const ACCOUNT_ACTIONS = new Set(['connection', 'identity', 'profile', 'schedule', 'krs', 'grades', 'transcript', 'finance', 'announcements', 'materials', 'history', 'surveyStatus', 'surveyQuestions', 'attendanceMeetings']);
const LOCAL_ORIGINS = new Set(['http://127.0.0.1:8790', 'http://localhost:8790']);

importScripts('session-reader.js');
let surveyInFlight = false, surveyUnknown = false;

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  let senderOrigin;
  try { senderOrigin = new URL(sender.url || '').origin; } catch { return false; }
  if (!LOCAL_ORIGINS.has(senderOrigin) || message?.type !== 'GAPURA_ACCOUNT_REQUEST' || (!ACCOUNT_ACTIONS.has(message.action) && message.action !== 'attendanceSubmit' && message.action !== 'surveySubmit')) return false;
  const parameters = message.parameters;
  if (!parameters || typeof parameters !== 'object' || Array.isArray(parameters) || JSON.stringify(parameters).length > 12000) {
    respond({ok:false,error:'Parameter akun tidak valid.'});
    return false;
  }
  const surveySubmit = message.action === 'surveySubmit';
  const surveyReload = message.action === 'surveyStatus' && surveyUnknown && !surveyInFlight;
  if (surveySubmit && (surveyInFlight || surveyUnknown)) {
    respond({ok:false,error:'Hasil pengiriman survey belum diketahui. Muat ulang status sebelum mengirim kembali.'});
    return false;
  }
  if (surveySubmit) surveyInFlight = true;
  (async () => {
    try {
      const tabs = await chrome.tabs.query({url:'https://akun.ub.ac.id/dashboard*'});
      const candidates = tabs.filter(tab => {
        try { const url = new URL(tab.url); return url.origin === 'https://akun.ub.ac.id' && url.pathname.startsWith('/dashboard'); } catch { return false; }
      }).sort((a,b) => Number(b.active) - Number(a.active) || (b.lastAccessed || 0) - (a.lastAccessed || 0));
      if (!candidates.length) throw Error('Buka akun.ub.ac.id/dashboard dan masuk dengan akun UB di browser yang sama, lalu hubungkan kembali.');
      const result = await chrome.scripting.executeScript({target:{tabId:candidates[0].id},world:'MAIN',func:readOfficialAccount,args:[message.action,parameters]});
      const value = result[0]?.result;
      if (surveySubmit && (!value || value.error?.includes('belum diketahui'))) surveyUnknown = true;
      if (surveyReload && !surveyInFlight && value?.ok && Array.isArray(value.data?.output?.data) && typeof value.data.output.data[0]?.STAT_ISI === 'string') surveyUnknown = false;
      respond(value || {ok:false,error:'Dashboard UB belum siap. Muat ulang dashboard resmi.'});
    } catch {
      if (surveySubmit) surveyUnknown = true;
      respond({ok:false,error:message.action === 'surveySubmit' ? 'Hasil pengiriman survey belum diketahui. Muat ulang status sebelum mengirim kembali.' : message.action === 'attendanceSubmit' ? 'Hasil pengiriman presensi belum diketahui. Muat ulang status dan daftar sebelum memilih kembali.' : 'Dashboard UB belum tersambung. Buka akun.ub.ac.id/dashboard di browser ini, masuk, lalu hubungkan kembali.'});
    } finally {
      if (surveySubmit) surveyInFlight = false;
    }
  })();
  return true;
});
