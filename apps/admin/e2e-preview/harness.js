// D356: records the preview's replies on window.__replies and offers window.__post(message) (JSON text, the panel's
// way). Only the iframe's own window and origin are listened to, as in the panel.
const frame = document.getElementById('preview');
window.__replies = [];
window.addEventListener('message', (e) => {
  if (e.source !== frame.contentWindow || e.origin !== location.origin) return;
  window.__replies.push(JSON.parse(e.data));
  document.getElementById('log').textContent = JSON.stringify(window.__replies);
});
window.__post = (message, origin = location.origin) => frame.contentWindow.postMessage(JSON.stringify(message), origin);
