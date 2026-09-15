import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-root',
  template: `
    <div class="container">
      <h1>DefectDojo PoC Application</h1>
      <div class="vuln-demo">
        <h2>SQL Injection Demo</h2>
        <input #userInput placeholder="Enter user ID" />
        <button (click)="sqlInjection(userInput.value)">Search</button>
        <p>{{ sqlResult }}</p>
      </div>

      <div class="vuln-demo">
        <h2>XSS Demo (Reflected)</h2>
        <input #xssInput placeholder="Enter your name" />
        <button (click)="reflectedXss(xssInput.value)">Greet</button>
        <div [innerHTML]="xssResult"></div>
      </div>

      <div class="vuln-demo">
        <h2>Path Traversal Demo</h2>
        <input #fileInput placeholder="Enter filename" />
        <button (click)="pathTraversal(fileInput.value)">Read File</button>
        <p>{{ fileContent }}</p>
      </div>

      <div class="vuln-demo">
        <h2>Hardcoded Secret Demo</h2>
        <button (click)="showSecret()">Show API Key</button>
        <p>{{ secret }}</p>
      </div>

      <div class="vuln-demo">
        <h2>Insecure JWT Verification</h2>
        <input #tokenInput placeholder="Enter JWT token" />
        <button (click)="verifyJwt(tokenInput.value)">Verify</button>
        <p>{{ jwtResult }}</p>
      </div>

      <div class="vuln-demo">
        <h2>Command Injection Demo</h2>
        <input #cmdInput placeholder="Enter hostname to ping" />
        <button (click)="commandInjection(cmdInput.value)">Ping</button>
        <p>{{ cmdResult }}</p>
      </div>

      <div class="vuln-demo">
        <h2>Prototype Pollution</h2>
        <input #protoInput placeholder="Enter JSON payload" />
        <button (click)="prototypePollution(protoInput.value)">Pollute</button>
        <p>{{ protoResult }}</p>
      </div>

      <div class="vuln-demo">
        <h2>Insecure Randomness</h2>
        <button (click)="weakRandom()">Generate Token</button>
        <p>{{ randomResult }}</p>
      </div>
    </div>
  `,
  styles: [`
    .container { padding: 20px; max-width: 800px; margin: 0 auto; }
    .vuln-demo { border: 1px solid #ccc; margin: 20px 0; padding: 15px; border-radius: 4px; }
    .vuln-demo h2 { color: #d32f2f; margin-top: 0; }
    input, textarea { padding: 8px; margin-right: 10px; width: 300px; }
    button { padding: 8px 16px; background: #1976d2; color: white; border: none; border-radius: 4px; cursor: pointer; }
    button:hover { background: #1565c0; }
  `]
})
export class AppComponent implements OnInit {
  sqlResult = '';
  xssResult = '';
  fileContent = '';
  secret = '';
  jwtResult = '';
  protoResult = '';
  randomResult = '';
  cmdResult = '';

  private readonly API_KEY = 'sk_live_51H7XKJ2eZvKYlo2Cx9v8J7kL9mN3pQ4rS6tU8vW9xY0zA1b2C3d4E5f6G7h8J9kL0';
  private readonly DB_PASSWORD = 'SuperSecretDBPassword123!';
  private readonly JWT_SECRET = 'my-super-secret-jwt-key-change-in-production';

  constructor(private http: HttpClient) {}

  ngOnInit() {}

  sqlInjection(userId: string) {
    const query = `SELECT * FROM users WHERE id = '${userId}'`;
    this.sqlResult = `Executing: ${query}`;
    this.http.get(`/api/users/${userId}`).subscribe({
      next: (data) => this.sqlResult = JSON.stringify(data),
      error: (err) => this.sqlResult = `Error: ${err.message}`
    });
  }

  reflectedXss(name: string) {
    this.xssResult = `<h2>Hello, ${name}!</h2>`;
  }

  pathTraversal(filename: string) {
    const path = `/var/www/uploads/${filename}`;
    this.fileContent = `Reading file: ${path}`;
    this.http.get(`/api/files/${filename}`).subscribe({
      next: (data) => this.fileContent = data as string,
      error: (err) => this.fileContent = `Error: ${err.message}`
    });
  }

  showSecret() {
    this.secret = `API Key: ${this.API_KEY}, DB Password: ${this.DB_PASSWORD}`;
  }

  verifyJwt(token: string) {
    // Simulated JWT verification with weak secret (detected by semgrep)
    const header = token.split('.')[0];
    const payload = token.split('.')[1];
    if (header && payload) {
      try {
        const decoded = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
        // Weak secret check - hardcoded secret
        if (this.JWT_SECRET.length < 32) {
          this.jwtResult = `WEAK SECRET DETECTED: ${this.JWT_SECRET}. Token payload: ${JSON.stringify(decoded)}`;
        } else {
          this.jwtResult = `Token payload: ${JSON.stringify(decoded)}`;
        }
      } catch (err) {
        this.jwtResult = `Invalid token format: ${err}`;
      }
    } else {
      this.jwtResult = 'Invalid JWT format';
    }
  }

  prototypePollution(payload: string) {
    try {
      const obj = JSON.parse(payload);
      // Unsafe merge - prototype pollution (detected by semgrep)
      Object.assign(Object.prototype, obj);
      this.protoResult = `Prototype polluted with: ${JSON.stringify(obj)}. Check Object.prototype.`;
    } catch (err) {
      this.protoResult = `Invalid JSON: ${err}`;
    }
  }

  weakRandom() {
    // Weak randomness - Math.random() for security tokens (detected by semgrep)
    const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    this.randomResult = `Weak token (Math.random): ${token}`;
  }

  commandInjection(host: string) {
    const command = `ping -c 4 ${host}`;
    this.cmdResult = `Executing: ${command}`;
    this.http.post('/api/ping', { host }).subscribe({
      next: (data) => this.cmdResult = data as string,
      error: (err) => this.cmdResult = `Error: ${err.message}`
    });
  }
}