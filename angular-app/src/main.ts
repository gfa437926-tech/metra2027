import { bootstrapApplication } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [provideRouter(routes), provideHttpClient()]
}).then(() => {
  if ('serviceWorker' in navigator && window.isSecureContext) {
    window.addEventListener('load', () => {
      void navigator.serviceWorker.register('./metra-sw.js').catch(error => {
        console.error('METRA offline shell registration failed', error);
      });
    }, { once: true });
  }
}).catch((error: unknown) => console.error(error));