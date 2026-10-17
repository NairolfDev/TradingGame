// Receives push messages (price alerts) while the web app is closed.
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDyLJRt_s14KXhpGhBcDU9i035BXJTorrU',
  appId: '1:974968386258:web:526752f83901959567f30b',
  messagingSenderId: '974968386258',
  projectId: 'tradinggame-austria-prod',
  authDomain: 'tradinggame-austria-prod.firebaseapp.com',
  storageBucket: 'tradinggame-austria-prod.firebasestorage.app',
});

// With a `notification` payload the browser shows the message itself.
firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.matchAll({type: 'window'}).then((list) => {
    for (const c of list) if ('focus' in c) return c.focus();
    return clients.openWindow('/');
  }));
});
