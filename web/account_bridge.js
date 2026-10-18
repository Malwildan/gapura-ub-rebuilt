/* The extension returns account records only; the official tab keeps its token. */
(() => {
  'use strict';
  const actions = new Set(['connection', 'identity', 'profile', 'schedule', 'krs', 'grades', 'transcript', 'finance', 'announcements', 'materials', 'history', 'surveyStatus', 'surveyQuestions', 'attendanceMeetings']);
  const pending = new Map();
  const officialWindow = window.opener || (window.parent !== window ? window.parent : null);
  window.addEventListener('message', event => {
    const extensionReply = event.source === window && event.origin === location.origin;
    const officialReply = officialWindow && event.source === officialWindow && event.origin === 'https://akun.ub.ac.id';
    if ((!extensionReply && !officialReply) || event.data?.type !== 'GAPURA_ACCOUNT_RESPONSE') return;
    const entry = pending.get(event.data.id);
    if (!entry) return;
    clearTimeout(entry.timer);
    pending.delete(event.data.id);
    entry.resolve(JSON.stringify(event.data.result));
  });
  window.gapuraAccountRequest = (action, parametersJson = '{}') => {
    if ((!actions.has(action) && action !== 'attendanceSubmit' && action !== 'surveySubmit')) return Promise.resolve(JSON.stringify({ok:false,error:'Pembaca akun tidak tersedia.'}));
    let parameters;
    try { parameters = JSON.parse(parametersJson); } catch { return Promise.resolve(JSON.stringify({ok:false,error:'Parameter akun tidak valid.'})); }
    const id = crypto.randomUUID();
    return new Promise(resolve => {
      const timer = setTimeout(() => {
        pending.delete(id);
        resolve(JSON.stringify({ok:false,error:action === 'surveySubmit' ? 'Hasil pengiriman survey belum diketahui. Muat ulang status sebelum mengirim kembali.' : action === 'attendanceSubmit' ? 'Hasil pengiriman presensi belum diketahui. Muat ulang status dan daftar sebelum memilih kembali.' : 'Jembatan akun tidak merespons. Muat ekstensi account-extension di Edge/Chrome, masuk pada akun.ub.ac.id/dashboard, lalu hubungkan kembali.'}));
      }, 26000);
      pending.set(id, {resolve, timer});
      const message = {type:'GAPURA_ACCOUNT_REQUEST',id,action,parameters};
      if (officialWindow) officialWindow.postMessage(message, 'https://akun.ub.ac.id');
      else window.postMessage(message, location.origin);
    });
  };
})();
