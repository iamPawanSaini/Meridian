// T06 placeholder for meridian-web. Replaced by the Next.js dev server in T21.
// Answers every path with HTTP 200 text/plain and a fixed sentence; serves no data.
import http from 'node:http';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('meridian-web placeholder; the dashboard arrives in T21\n');
});

server.listen(3000, '0.0.0.0');
