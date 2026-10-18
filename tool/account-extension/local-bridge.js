/* Isolated world: accept fixed readers and dedicated guarded submit actions. */
(() => {
  const allowed = new Set(['connection', 'identity', 'profile', 'schedule', 'krs', 'grades', 'transcript', 'finance', 'announcements', 'materials', 'history', 'surveyStatus', 'surveyQuestions', 'attendanceMeetings']);
  window.addEventListener('message', async event => {
    if (event.source !== window || event.origin !== location.origin) return;
    const message = event.data;
    if (message?.type !== 'GAPURA_ACCOUNT_REQUEST' || (!allowed.has(message.action) && message.action !== 'attendanceSubmit' && message.action !== 'surveySubmit') || typeof message.id !== 'string' || message.id.length > 100) return;
    let result;
    try {
      result = await chrome.runtime.sendMessage({type:message.type,action:message.action,parameters:message.parameters});
      if (!result || typeof result !== 'object') result = {ok:false,error:'Ekstensi akun belum siap. Muat ulang halaman Flutter.'};
    } catch {
      result = {ok:false,error:'Ekstensi akun perlu dimuat ulang. Muat ulang halaman Flutter.'};
    }
    window.postMessage({type:'GAPURA_ACCOUNT_RESPONSE',id:message.id,result}, location.origin);
  });
})();
